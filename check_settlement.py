import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename.lower():
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:3]

if not latest_files:
    print("No hand history files found.")
    exit(0)

for f in latest_files:
    print(f"\n--- File: {os.path.basename(f)} ---")
    try:
        with open(f, 'r') as file:
            data = json.load(file)
            
            # Read initial chips
            players = data.get('players', [])
            initial_chips = {p['playerId']: p['initialChips'] for p in players}
            player_names = {p['playerId']: p['playerName'] for p in players}
            
            # Calculate total invested per player from actions
            invested = {pid: 0 for pid in initial_chips}
            for round_seq in data.get('actionSequence', []):
                for a in round_seq.get('actions', []):
                    pid = a['playerId']
                    # totalInvested is cumulative for the round or hand? It says totalInvested
                    # Let's just track the maximum totalInvested seen for each player across all actions
                    # Actually, if totalInvested is per hand, we just take the max.
                    if a['totalInvested'] > invested[pid]:
                        invested[pid] = a['totalInvested']
            
            total_invested_all = sum(invested.values())
            print(f"Total Chips Invested by All Players: {total_invested_all}")
            
            # Check pots
            pots = data.get('pots', {})
            total_pot_from_pots = 0
            if pots:
                main_pot = pots.get('mainPot')
                if main_pot:
                    total_pot_from_pots += main_pot.get('amount', 0)
                for sp in pots.get('sidePots', []):
                    total_pot_from_pots += sp.get('amount', 0)
            
            print(f"Total Pot Recorded in 'pots': {total_pot_from_pots}")
            
            # Check result
            result = data.get('result', {})
            chips_after = result.get('chipsAfter', {})
            total_win_recorded = result.get('totalWin', 0)
            winner_id = result.get('winnerId')
            
            print(f"Total Win Recorded in 'result': {total_win_recorded}")
            if winner_id:
                print(f"Recorded Winner: {player_names.get(winner_id, winner_id)}")
            else:
                print("Recorded Winner: Split Pot or Multiple Winners")
            
            # Validate chip math
            print("Chip Math Check:")
            total_payout_calculated = 0
            for pid, start_chips in initial_chips.items():
                end_chips = chips_after.get(pid, 0)
                inv = invested[pid]
                net = end_chips - start_chips
                # If they won something, end_chips = start_chips - inv + won
                won = end_chips - (start_chips - inv)
                total_payout_calculated += won
                name = player_names.get(pid, pid)
                print(f"  {name}: Start {start_chips} -> End {end_chips} (Invested {inv}, Won {won}, Net {net})")
                
            print(f"Sum of Calculated Won Chips: {total_payout_calculated}")
            
            if total_payout_calculated == total_invested_all and total_pot_from_pots == total_invested_all:
                print("  >> [OK] Settlement math is perfectly balanced.")
            else:
                print("  >> [WARNING] Math mismatch detected!")
                
    except Exception as e:
        print(f"Error reading {f}: {e}")
