# 文档入口

最后更新：2026-07-26

## 1. 当前阅读顺序

### 做 V0.1 bug fix、验收或平衡修正

1. [产品规格](product/01_v0.1_product_spec.md)
2. [核心循环与规则](rules/02_core_loop_and_rules.md)
3. [Godot 技术架构](architecture/03_godot_architecture.md)
4. [数据模型](architecture/04_data_model.md)
5. [V0.1 功能实现总结](product/23_v0.1_implementation_summary.md)
6. 对应任务或测试文件

### 做后续路线规划

1. [V0.1 功能实现总结](product/23_v0.1_implementation_summary.md)
2. [Post-V0.1 Agency Roadmap](product/24_post_v0.1_agency_roadmap.md)
3. 需要修改的 Accepted 规则文档

## 2. 目录结构

| 目录 | 内容 | 说明 |
|---|---|---|
| `product/` | 产品规格、里程碑、实现总结、后续路线 | 产品判断和阶段规划入口 |
| `architecture/` | Godot 架构、数据模型 | 技术边界和公共数据字段 |
| `rules/` | 核心循环、合同规则、战役规则 | Accepted 规则主要存放区 |
| `content/` | 合同内容目录、巨龙入侵剧本 | 手工内容与覆盖审计 |
| `process/` | Codex 工作流 | 协作与任务执行方法 |
| `adr/` | Architecture Decision Record | 已接受的架构决策 |
| `archive/` | 已完成、失效或被正式文档取代的跟踪材料 | 保留历史，不作为默认权威入口 |

完成任务归档在 [tasks/completed/v0_1](../tasks/completed/v0_1)。当前 V0.1 总路线仍保留在 [tasks/000_v0.1_execution_map.md](../tasks/000_v0.1_execution_map.md)。

## 3. 核心产品与技术边界

| 文档 | 职责 |
|---|---|
| [01_v0.1_product_spec.md](product/01_v0.1_product_spec.md) | V0.1 产品目标、范围、体验与验收标准 |
| [02_core_loop_and_rules.md](rules/02_core_loop_and_rules.md) | 周循环、英雄、合同结算、阵营和世界局势总规则 |
| [03_godot_architecture.md](architecture/03_godot_architecture.md) | Godot 目录、分层、服务职责、随机数、测试与存档边界 |
| [04_data_model.md](architecture/04_data_model.md) | Definition、State、结果对象、字段和验证规则 |

## 4. 合同与周循环规则

| 文档 | 职责 |
|---|---|
| [08_contract_clause_spec.md](rules/contracts/08_contract_clause_spec.md) | 条款类别、条件/效果白名单和求值顺序 |
| [10_baseline_contracts.md](rules/contracts/10_baseline_contracts.md) | 三份基准合同与 golden 手算 |
| [15_staged_contract_resolution_rules.md](rules/contracts/15_staged_contract_resolution_rules.md) | 四阶段结算、认可度、补给、疲劳、伤病和 final tier |
| [21_remaining_contract_numerical_rules.md](rules/contracts/21_remaining_contract_numerical_rules.md) | 其余九份合同的完整数值定义 |
| [11_contract_proposal_generation.md](rules/campaign/11_contract_proposal_generation.md) | 合同来源、资格、优先级和 fallback |
| [12_contract_instantiation_and_commitment.md](rules/campaign/12_contract_instantiation_and_commitment.md) | Offer 实例化、拒绝、关系加成和提出方承诺 |
| [13_unhandled_contract_and_npc_results.md](rules/campaign/13_unhandled_contract_and_npc_results.md) | 过期、NPC 完成、问题恶化与稳定结算 |
| [14_week_flow_faction_commitments_and_messages.md](rules/campaign/14_week_flow_faction_commitments_and_messages.md) | 周流程、阵营行动承诺、目标锁与消息 |
| [19_content_catalog_state_and_situation_rules.md](rules/campaign/19_content_catalog_state_and_situation_rules.md) | Catalog、状态事务、补给消费和 SituationResolver |
| [20_weekly_upkeep_and_history_rules.md](rules/campaign/20_weekly_upkeep_and_history_rules.md) | 工资、治疗、恢复、近期计数和历史查询 |
| [22_campaign_bootstrap_forecast_and_ui_shell.md](rules/campaign/22_campaign_bootstrap_forecast_and_ui_shell.md) | 新战役 setup、64 样本预测、会话阶段和 UI 外壳 |

## 5. 内容文档

| 文档 | 职责 |
|---|---|
| [09_contract_template_catalog.md](content/contracts/09_contract_template_catalog.md) | 12 份手工合同的身份、目标、阶段骨架和覆盖 |
| [16_dragon_invasion_scenario_content_plan.md](content/dragon_invasion/16_dragon_invasion_scenario_content_plan.md) | 巨龙入侵内容定案过程和完成记录 |
| [17_dragon_invasion_scenario_spec.md](content/dragon_invasion/17_dragon_invasion_scenario_spec.md) | 局势阶段、四结局、三阵营目标和五条进度钟 |
| [18_dragon_invasion_problem_and_action_catalog.md](content/dragon_invasion/18_dragon_invasion_problem_and_action_catalog.md) | 九个世界问题、阵营行动表、合同覆盖和结局路径 |

## 6. 归档说明

- [07_contract_generation_and_integration_todos.md](archive/07_contract_generation_and_integration_todos.md) 是早期跟踪文档，已经被 08 至 22 的 Accepted 文档取代。保留用于追溯，不作为默认实现依据。
- Task 001 至 Task 017 已移入 [tasks/completed/v0_1](../tasks/completed/v0_1)。后续新阶段应新建任务文件，不继续在完成任务里追加实现范围。
