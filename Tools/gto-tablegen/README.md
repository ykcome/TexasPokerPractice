# gto-tablegen

独立离线工具：调用 postflop-solver（AGPL）生成 6max SNG 常见翻牌面聚类的策略分布表，用于 TexasPoker App 运行时查表。

## 依赖

`Tools/gto-tablegen/Cargo.toml` 当前使用本机路径依赖：

- `Tools/third_party/postflop-solver-main`

如果你把 solver 放到别处，需要修改该路径；或替换成 git 依赖。

## 运行

```bash
cd Tools/gto-tablegen
~/.cargo/bin/cargo run --release -- --iters 600 --stacks-bb 10,15,20,30 --out output/gto_clusters_srp_btn_bb.json
```

输出 JSON：

- `output/gto_clusters_srp_btn_bb.json`
