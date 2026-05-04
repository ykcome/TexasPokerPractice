use clap::Parser;
use postflop_solver::*;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
struct Args {
    #[arg(long, default_value = "output/gto_clusters_srp_btn_bb.json")]
    out: String,

    #[arg(long, default_value_t = 600)]
    iters: u32,

    #[arg(long, default_value_t = 0.01)]
    target_expl: f32,

    #[arg(long, default_value = "10,15,20,30")]
    stacks_bb: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ActionProbs {
    check: f64,
    bet_33: f64,
    bet_66: f64,
    overbet_125: f64,
    allin: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ClusterEntry {
    stack_bb: i32,
    cluster: String,
    oop: ActionProbs,
    ip: ActionProbs,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct TableFile {
    schema_version: u32,
    scenario: String,
    entries: Vec<ClusterEntry>,
}

fn main() {
    let args = Args::parse();

    let stacks_bb: Vec<i32> = args
        .stacks_bb
        .split(',')
        .filter_map(|s| s.trim().parse().ok())
        .collect();

    let clusters = default_clusters();

    let mut entries: Vec<ClusterEntry> = vec![];

    let out_path = PathBuf::from(args.out);
    if let Some(parent) = out_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    for &stack_bb in &stacks_bb {
        for (cluster, flop) in &clusters {
            eprintln!("solve stack_bb={} cluster={} flop={}", stack_bb, cluster, flop);
            let (oop, ip) = solve_one(stack_bb, flop, args.iters, args.target_expl);
            entries.push(ClusterEntry {
                stack_bb,
                cluster: cluster.clone(),
                oop,
                ip,
            });

            let out_file = TableFile {
                schema_version: 1,
                scenario: "SRP_BTN_vs_BB_FlopRoot".to_string(),
                entries: entries.clone(),
            };
            fs::write(&out_path, serde_json::to_vec_pretty(&out_file).unwrap()).unwrap();
        }
    }
}

fn solve_one(stack_bb: i32, flop: &str, iters: u32, target_expl_pct_pot: f32) -> (ActionProbs, ActionProbs) {
    let oop_range = "66+,A8s+,A5s-A4s,AJo+,K9s+,KQo,QTs+,JTs,96s+,85s+,75s+,65s,54s";
    let ip_range = "QQ-22,AQs-A2s,ATo+,K5s+,KJo+,Q8s+,J8s+,T7s+,96s+,86s+,75s+,64s+,53s+";

    let card_config = CardConfig {
        range: [oop_range.parse().unwrap(), ip_range.parse().unwrap()],
        flop: flop_from_str(flop).unwrap(),
        turn: NOT_DEALT,
        river: NOT_DEALT,
    };

    let bb = 100;
    let sb = 50;
    let starting_pot = (sb + bb) + (250 + 250);
    let effective_stack = stack_bb * bb;

    let bet_sizes = BetSizeOptions::try_from(("33%, 66%, 125%, a", "2.5x")).unwrap();
    let tree_config = TreeConfig {
        initial_state: BoardState::Flop,
        starting_pot,
        effective_stack,
        rake_rate: 0.0,
        rake_cap: 0.0,
        flop_bet_sizes: [bet_sizes.clone(), bet_sizes.clone()],
        turn_bet_sizes: [bet_sizes.clone(), bet_sizes.clone()],
        river_bet_sizes: [bet_sizes.clone(), bet_sizes.clone()],
        turn_donk_sizes: None,
        river_donk_sizes: None,
        add_allin_threshold: 100.0,
        force_allin_threshold: 0.0,
        merging_threshold: 0.1,
    };

    let action_tree = ActionTree::new(tree_config).unwrap();
    let mut game = PostFlopGame::with_config(card_config, action_tree).unwrap();
    game.allocate_memory(false);

    let target_expl = game.tree_config().starting_pot as f32 * target_expl_pct_pot;
    solve(&mut game, iters, target_expl, false);
    game.cache_normalized_weights();

    let oop = aggregate_current_node_probs(&game);

    let actions = game.available_actions();
    if let Some(check_idx) = actions.iter().position(|a| *a == Action::Check) {
        game.play(check_idx);
    }
    game.cache_normalized_weights();
    let ip = aggregate_current_node_probs(&game);
    game.back_to_root();
    (oop, ip)
}

fn aggregate_current_node_probs(game: &PostFlopGame) -> ActionProbs {
    let actions = game.available_actions();
    let strategy = game.strategy();
    let num_actions = actions.len().max(1);
    let nhands = strategy.len() / num_actions;
    let player = game.current_player();
    let weights = game.normalized_weights(player);

    let mut totals: BTreeMap<ActionKey, f64> = BTreeMap::new();
    totals.insert(ActionKey::Check, 0.0);
    totals.insert(ActionKey::Bet33, 0.0);
    totals.insert(ActionKey::Bet66, 0.0);
    totals.insert(ActionKey::Overbet125, 0.0);
    totals.insert(ActionKey::AllIn, 0.0);

    for (action_index, action) in actions.iter().enumerate() {
        let key = map_action_key(game.tree_config().starting_pot, game.tree_config().effective_stack, *action);
        let mut acc = 0.0f64;
        let offset = action_index * nhands;
        for i in 0..nhands {
            acc += (strategy[offset + i] as f64) * (weights[i] as f64);
        }
        *totals.entry(key).or_insert(0.0) += acc;
    }

    let sum: f64 = totals.values().sum();
    let norm = if sum > 0.0 { sum } else { 1.0 };

    ActionProbs {
        check: totals[&ActionKey::Check] / norm,
        bet_33: totals[&ActionKey::Bet33] / norm,
        bet_66: totals[&ActionKey::Bet66] / norm,
        overbet_125: totals[&ActionKey::Overbet125] / norm,
        allin: totals[&ActionKey::AllIn] / norm,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum ActionKey {
    Check,
    Bet33,
    Bet66,
    Overbet125,
    AllIn,
}

fn map_action_key(starting_pot: i32, effective_stack: i32, action: Action) -> ActionKey {
    match action {
        Action::Check | Action::Call | Action::Fold => ActionKey::Check,
        Action::AllIn(_) => ActionKey::AllIn,
        Action::Bet(amount) | Action::Raise(amount) => {
            let pot = starting_pot.max(1) as f64;
            let ratio = (amount as f64) / pot;
            let stack_ratio = (amount as f64) / (effective_stack.max(1) as f64);

            if stack_ratio >= 0.95 {
                return ActionKey::AllIn;
            }
            if ratio <= 0.45 {
                ActionKey::Bet33
            } else if ratio <= 0.95 {
                ActionKey::Bet66
            } else {
                ActionKey::Overbet125
            }
        }
        Action::Chance(_) | Action::None => ActionKey::Check,
    }
}

fn default_clusters() -> Vec<(String, String)> {
    vec![
        ("high_dry".to_string(), "AsKd2c".to_string()),
        ("low_dry".to_string(), "9s5d2c".to_string()),
        ("two_tone".to_string(), "As7s2d".to_string()),
        ("mono_tone".to_string(), "As7s2s".to_string()),
        ("connected_wet".to_string(), "9s8d7c".to_string()),
        ("paired".to_string(), "KsKd5c".to_string()),
    ]
}
