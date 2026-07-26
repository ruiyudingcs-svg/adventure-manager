# 冒险团管理游戏

一款以合同、人员安排、准备、组织价值观和资源取舍为核心的奇幻冒险者公会管理游戏。

玩家不直接操作英雄战斗，而是通过选择合同、派遣四人小队、配置补给和决定行动倾向，间接塑造任务结果、阵营关系与长期世界局势。

## 当前状态

- V0.1 功能实现已完成，处于 Release Validation。
- 当前原型暴露出的主要问题是玩家可控性不足：选人缺少参考、失败链条过硬、结算因果不够清晰、合同选择空间偏窄。
- 下一步推荐路线已整理为 [Post-V0.1 Agency Roadmap](docs/product/24_post_v0.1_agency_roadmap.md)。
- V0.1 实现范围、验证证据和剩余发布验收见 [V0.1 功能实现总结](docs/product/23_v0.1_implementation_summary.md)。
- 完整文档入口见 [docs/README.md](docs/README.md)。

## 推荐下一步

1. V0.1.1：组队决策参考与结算可读性重做。
2. V0.1.2：合同组合扩展为每派系 2 个槽位，总计 6 选 1；6 选 2 作为后续容量实验，不先作为默认规则。
3. V0.2：招募、临时补员和英雄定位细分，让伤病与疲劳成为管理问题，而不是单点崩盘。
4. 更后续：基础战斗表现或战斗摘要强化。战斗不作为当前解决可控性问题的首要手段。

## 开发入口

每次交给 Codex 一个实现任务时，按以下顺序提供上下文：

```text
AGENTS.md
→ docs/README.md
→ tasks/000_v0.1_execution_map.md 或当前阶段路线文档
→ 当前 task 文件
→ task 的 Required reading
→ 现有代码与测试
```

当前完整测试命令为：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

当前开发机确认的 Godot 版本为 `4.7.stable.official.5b4e0cb0f`，安装目录为
`D:\software\Godot\Godot_v4.7-stable_win64`。Godot 未加入系统 `PATH` 时，应直接调用该目录中的 console 可执行文件。

在 `tests/run_all.gd` 不存在、测试未实际运行或环境中没有 Godot 4.7 可执行文件时，不得声称该命令已经通过。

## 文档权威规则

README 只负责导航，不重复保存完整游戏规则。出现冲突时按以下原则处理：

1. [V0.1 产品规格](docs/product/01_v0.1_product_spec.md) 规定当前已实现版本的产品范围上限。
2. Accepted ADR 可以覆盖更早的技术指导，但不能绕过产品范围。当前 ADR 见 [docs/adr](docs/adr)。
3. 状态为 Accepted 的专项规格，在其负责领域内优先于更早、更宽泛的描述。
4. [Godot 技术架构](docs/architecture/03_godot_architecture.md) 与 [数据模型](docs/architecture/04_data_model.md) 分别约束技术职责和数据边界。
5. Task 文件负责限定单次实现范围、允许文件和验收测试，但不能自行创造产品规则。
6. Roadmap、内容计划、TODO、审计和归档文档用于规划或验证，除非明确标记为 Accepted，否则不能覆盖 Accepted 规则。

根目录 [AGENTS.md](AGENTS.md) 是 Codex 的常驻仓库执行约束。若任务所需公式缺失，或两个 Accepted 文档仍然冲突，应停止实现并报告，不得用临时常数、零值 placeholder 或自行猜测补齐。
