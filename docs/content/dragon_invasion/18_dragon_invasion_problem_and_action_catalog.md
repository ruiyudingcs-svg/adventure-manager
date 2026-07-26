# 巨龙入侵世界问题、阵营行动与合同覆盖审计 V0.1

状态：Accepted（TODO 21E—21G）  
日期：2026-07-22

## 1. 文档职责

本文完成 `docs/content/dragon_invasion/16_dragon_invasion_scenario_content_plan.md` 的 TODO 21E、21F 与 21G，是九个世界问题、三个阵营 `weekly_action_table`、跨系统覆盖和结局路径校准的权威来源。

职责划分：

- 阶段、结局、阵营目标与五条钟：`docs/content/dragon_invasion/17_dragon_invasion_scenario_spec.md`。
- 十二份合同自身的提出方、类型、阶段、条款、生成参数和代表性结果：`docs/content/contracts/09_contract_template_catalog.md`。
- 三份完整数值基准合同：`docs/rules/contracts/10_baseline_contracts.md`。
- 其余九份完整数值合同：`docs/rules/contracts/21_remaining_contract_numerical_rules.md`。
- 九个问题、阵营行动、问题—合同—行动连接和结局路径审计：本文。

本文不增加动态任务生成、NPC 外交、行动冲突、目标树状态或问题重生规则。

## 2. 全局内容约定

### 2.1 问题生命周期

- 九个 WorldProblemState 在新战役中全部存在；三个开局问题为 `active`，其余为 `inactive`。
- 每个问题至多从 `inactive` 进入一次 `active`。`resolved`、`escalated` 或 `closed` 后不得重新激活。
- 任一 activation rule 成立即激活；任一 resolution rule 成立即解决。问题期限到达且仍为 `active` 时应用一次 `escalation_effects` 并进入 `escalated`。
- 合同和阵营行动只产生钟变化与世界事件，不直接写互斥的问题终态。`SituationResolver` 在合并效果后统一求值 resolution rules。
- 进入 `phase_ended` 时，所有剩余 active 问题无额外效果地进入 `closed`。
- escalation effect 中创建的事件键全局唯一；同一问题不能通过期限和合同未处理分支重复恶化。

### 2.2 阵营初始状态

三个阵营初始 `influence = 60`，V0.1 不提供自然恢复。合同提案不消耗 influence；直接行动承诺和未处理合同的 NPC 完成按行动表扣除。影响力耗尽后阵营仍能提出合同，但无法执行需要 influence 的行动。

### 2.3 问题标签

| problem ID | problem_tags |
|---|---|
| `problem_eastern_road_blocked` | `road_route`, `evacuation_access` |
| `problem_evacuating_civilians` | `civilian_evacuation`, `defensive_line` |
| `problem_field_medical_collapse` | `field_medical`, `civilian_evacuation` |
| `problem_mining_village_isolated` | `isolated_settlement`, `civilian_rescue` |
| `problem_dragon_location_unknown` | `dragon_tracking`, `capture_research` |
| `problem_dragon_capture_window` | `dragon_capture`, `capture_research` |
| `problem_necrotic_spread` | `necrotic_spread`, `forbidden_ritual` |
| `problem_battlefield_corpses` | `battlefield_corpses`, `necrotic_material` |
| `problem_dragon_assault_pressure` | `dragon_assault`, `settlement_defense` |

合同 `target_problem_tags` 必须是其锚点问题标签的子集；行动只从含有其 `target_problem_tags` 的 active 问题中选择目标。

## 3. 九个世界问题

紧迫度继续使用现有统一公式：基础值、年龄增量、期限压力，再加本节列出的互斥内容修正。所有修正 reason 均为 `visibility = player`；同一问题同一进度钟不配置重叠区间。

### 3.1 `problem_eastern_road_blocked`

- 开局状态：`active`，`opened_week = 1`。
- tags：`road_route`、`evacuation_access`。
- 紧迫度：base 55；age +8/周，cap 24；response window 3 周。
- 内容修正：`settlement_destruction >= 18` 时 +15，reason `urgency_road_fire_spreading`。
- 合同白名单：`contract_scout_eastern_road`。
- 玩家解决：成功取得 `event_eastern_route_secured`。
- NPC/状态解决：其他行动产生同一安全路线事件。
- 恶化：创建 `event_eastern_road_lost`；`settlement_destruction +12`；`necrotic_corruption +3`。
- 后续：安全路线事件激活平民撤离问题并解锁 `contract_north_road_evacuation`；道路失守只关闭该问题，fallback 侦察合同仍可用 Agenda 来源更新其他路线。

### 3.2 `problem_evacuating_civilians`

- 开局状态：`inactive`。
- 激活：发生 `event_eastern_route_secured`，或 `villagers_evacuated >= 15`。
- tags：`civilian_evacuation`、`defensive_line`。
- 紧迫度：base 45；age +6/周，cap 18；response window 4 周。
- 内容修正：`settlement_destruction >= 30` 时 +20，reason `urgency_evacuation_infrastructure_failing`；`phase_final_window` 时 +10，reason `urgency_evacuation_final_window`。
- 合同白名单：`contract_north_road_evacuation`、`contract_hold_stone_bridge`。
- 玩家解决：发生 `event_stone_bridge_secured`，或 `villagers_evacuated >= 70`。
- NPC/状态解决：自由联盟加固石桥产生相同安全事件；撤离达到 70 时自然解决。
- 恶化：创建 `event_evacuation_line_collapsed`；`settlement_destruction +15`；`necrotic_corruption +5`。
- 后续：解决后不再生成问题来源撤离合同，但仍允许 Agenda 来源的医疗支援；恶化不会扣减已经撤离的人口。

### 3.3 `problem_field_medical_collapse`

- 开局状态：`inactive`。
- 激活：`settlement_destruction >= 30`。
- tags：`field_medical`、`civilian_evacuation`。
- 紧迫度：base 50；age +8/周，cap 24；response window 3 周。
- 内容修正：`settlement_destruction >= 50` 时 +20，reason `urgency_field_hospitals_overwhelmed`；`phase_final_window` 时 +10，reason `urgency_medical_last_chance`。
- 合同白名单：`contract_escort_field_healers`。
- 玩家解决：发生 `event_field_healers_delivered`。
- NPC/状态解决：自由联盟稳定营地，产生 `event_field_camp_stabilized`。
- 恶化：创建 `event_field_medical_system_failed`；`settlement_destruction +8`；`necrotic_corruption +5`。
- 后续：解决时不降低累计毁坏，只改善后续撤离内容；恶化会增加污染问题的形成速度。

### 3.4 `problem_mining_village_isolated`

- 开局状态：`inactive`。
- 激活：`settlement_destruction >= 18`。
- tags：`isolated_settlement`、`civilian_rescue`。
- 紧迫度：base 55；age +10/周，cap 20；response window 3 周。
- 内容修正：`settlement_destruction >= 30` 时 +15，reason `urgency_mining_route_collapsing`；`necrotic_corruption >= 25` 时 +10，reason `urgency_mining_dead_at_risk`。
- 合同白名单：`contract_rescue_mining_village`。
- 玩家解决：发生 `event_mining_village_rescued`。
- NPC/状态解决：自由联盟搜索行动产生 `event_mining_survivors_recovered`。
- 恶化：创建 `event_mining_village_destroyed`；`settlement_destruction +10`；`necrotic_corruption +8`。
- 后续：解决增加撤离人口；恶化通过钟阈值推动尸体与污染问题，不直接创建额外问题实例。

### 3.5 `problem_dragon_location_unknown`

- 开局状态：`active`，`opened_week = 1`。
- tags：`dragon_tracking`、`capture_research`。
- 紧迫度：base 35；age +5/周，cap 15；response window 4 周。
- 内容修正：`settlement_destruction >= 30` 时 +10，reason `urgency_dragon_tracks_lost_in_ruins`；`phase_open_conflict` 时 +15，reason `urgency_capture_research_delayed`。
- 合同白名单：`contract_locate_dragon_lair`。
- 玩家解决：发生 `event_dragon_lair_located`。
- NPC/状态解决：魔法工会定位行动产生同一事件。
- 恶化：创建 `event_dragon_relocated`；`settlement_destruction +8`；`capture_preparation -4`。
- 后续：巢穴定位事件解锁鳞片采集；它与 `dragon_exhaustion >= 25` 共同激活捕获窗口。问题恶化后 Agenda 定位合同仍可继续追踪，但不重新开启本问题。

### 3.6 `problem_dragon_capture_window`

- 开局状态：`inactive`。
- 激活：已发生 `event_dragon_lair_located`，且 `dragon_exhaustion >= 25`。
- tags：`dragon_capture`、`capture_research`。
- 紧迫度：base 50；age +8/周，cap 24；response window 4 周。
- 内容修正：`dragon_exhaustion >= 60` 时 +20，reason `urgency_dragon_binding_window_open`；`phase_final_window` 时 +15，reason `urgency_capture_final_window`；`necrotic_corruption >= 60` 时 +15，reason `urgency_capture_corruption_blocking`。
- 合同白名单：`contract_collect_dragon_scales`、`contract_deploy_binding_towers`。
- 玩家解决：发生 `event_binding_towers_operational`。
- NPC/状态解决：魔法工会部署行动产生 `event_binding_towers_partially_operational`；只有玩家合同事件或 `capture_preparation >= 80` 才完全解决问题。
- 恶化：创建 `event_capture_window_closed`；`settlement_destruction +8`；`capture_preparation -6`；`dragon_exhaustion -5`。
- 后续：准备达到 60 解锁束缚塔合同；问题解决不直接设置结局，仍由准备、疲劳和污染三个条件统一判断。

### 3.7 `problem_necrotic_spread`

- 开局状态：`inactive`。
- 激活：`necrotic_corruption >= 25`。
- tags：`necrotic_spread`、`forbidden_ritual`。
- 紧迫度：base 60；age +10/周，cap 20；response window 3 周。
- 内容修正：`necrotic_corruption >= 60` 时 +20，reason `urgency_necrotic_conversion_near`；`phase_final_window` 时 +10，reason `urgency_necrotic_final_window`。
- 合同白名单：`contract_investigate_necrotic_source`、`contract_disrupt_necrotic_ritual`。
- 玩家解决：发生 `event_necrotic_ritual_disrupted`，或发生 `event_necrotic_source_secured`。后者只表示失控扩散被死灵集团收束，不表示污染下降。
- NPC/状态解决：魔法工会结界产生 `event_necrotic_spread_warded`；死灵集团控制污染源也可关闭当前问题。
- 恶化：创建 `event_necrotic_spread_surged`；`necrotic_corruption +15`；`settlement_destruction +4`。
- 后续：解决后现有污染钟仍保留；死灵集团可继续通过 Agenda 与行动推进污染，问题不得循环重建。

### 3.8 `problem_battlefield_corpses`

- 开局状态：`inactive`。
- 激活：`settlement_destruction >= 20`。
- tags：`battlefield_corpses`、`necrotic_material`。
- 紧迫度：base 50；age +12/周，cap 24；response window 2 周。
- 内容修正：`necrotic_corruption >= 25` 时 +20，reason `urgency_corpses_begin_turning`；`settlement_destruction >= 30` 时 +10，reason `urgency_more_battlefield_dead`。
- 合同白名单：`contract_recover_intact_corpses`。
- 玩家解决：发生 `event_corpses_delivered`。这是对眼前尸体问题的处理，但会提高污染。
- NPC/状态解决：死灵集团回收行动产生 `event_corpses_recovered_by_collective`。
- 恶化：创建 `event_battlefield_dead_rose`；`necrotic_corruption +15`；`settlement_destruction +5`。
- 后续：恶化不创建“游荡亡者”第十个问题，只以事件、钟和消息表达。

### 3.9 `problem_dragon_assault_pressure`

- 开局状态：`active`，`opened_week = 1`。
- tags：`dragon_assault`、`settlement_defense`。
- 紧迫度：base 60；age +8/周，cap 24；response window 3 周。
- 内容修正：`settlement_destruction >= 30` 时 +20，reason `urgency_dragon_assault_breaking_settlements`；`phase_final_window` 时 +10，reason `urgency_dragon_assault_final_window`。
- 合同白名单：`contract_prepare_dragon_bait`。
- 玩家解决：发生 `event_dragon_diverted`，或 `dragon_exhaustion >= 40`。
- NPC/状态解决：死灵集团粗放诱饵产生相同转移事件；其他阵营压制行动只能提高疲劳，不直接关闭问题。
- 恶化：创建 `event_village_burned`；`settlement_destruction +15`；`necrotic_corruption +3`。
- 后续：问题恶化后仍可通过 Agenda 诱饵合同影响巨龙，但不会重建同一压力问题。

## 4. 问题依赖图

```text
开局：东部道路被阻断 ──安全路线──→ 平民撤离线承压
                    └─恶化毁坏──→ 矿村失联 / 战地医疗崩溃

开局：巨龙位置未知 ──巢穴定位 + 巨龙疲劳25──→ 巨龙捕获窗口

开局：巨龙袭击压力 ──毁坏20──→ 战场尸体无人处理
                    └─毁坏/尸体/时间──→ 死灵污染扩散

任意问题恶化只改变钟与事件
→ 钟阈值可以激活尚未出现的问题
→ 已结束的问题不重生
```

## 5. 阵营 Agenda 权重

| 阵营 | 正权重 tags | 负权重 tags |
|---|---|---|
| 自由冒险者联盟 | `evacuation +10`、`rescue +8`、`protection +7`、`reduce_collateral +5` | `necrotic_exploitation -10`、`sacrifice_civilians -8` |
| 魔法工会 | `capture +10`、`research +8`、`target_alive +8`、`contain_necrotic +6` | `lethal_force -10`、`destroy_samples -6` |
| 死灵集团 | `corruption +10`、`corpse_use +8`、`dragon_bait +7`、`secrecy +6` | `purification -10`、`public_rescue -5` |

单一候选的匹配权重继续裁剪到 `-30..30`。这些标签同时用于合同和行动意图，不创建新的目标状态。

## 6. 自由冒险者联盟行动表

| action ID | target lock / problem tags | base / urgency / cooldown / cost | 条件 | effects | event key | NPC复用 |
|---|---|---:|---|---|---|---|
| `action_free_alliance_evacuate_north_road` | `north_road.evacuate_civilians` / `civilian_evacuation` | 16 / 30 / 2 / 8 | 已有安全路线；撤离未达70 | 撤离+10，毁坏+8 | `event_free_alliance_evacuated_north_road` | 北路撤离合同 |
| `action_free_alliance_reinforce_stone_bridge` | `stone_bridge.hold_evacuation_line` / `defensive_line` | 15 / 30 / 2 / 6 | 撤离问题 active | 撤离+6，疲劳钟+4，毁坏+4 | `event_stone_bridge_secured` | 否 |
| `action_free_alliance_stabilize_field_camp` | `field_hospital.escort_healers` / `field_medical` | 14 / 30 / 2 / 5 | 医疗问题 active | 撤离+4，污染-3，毁坏+2 | `event_field_camp_stabilized` | 否 |
| `action_free_alliance_search_mining_village` | `mining_village.rescue_survivors` / `isolated_settlement` | 15 / 35 / 2 / 7 | 矿村问题 active | 撤离+6，毁坏+5 | `event_mining_survivors_recovered` | 否 |
| `action_free_alliance_patrol_refugee_route` | `refugee_route.patrol` / `road_route` | 8 / 20 / 1 / 4 | 道路问题 active | 撤离+3，疲劳钟+2，毁坏+2 | `event_eastern_route_secured` | 否 |

## 7. 魔法工会行动表

| action ID | target lock / problem tags | base / urgency / cooldown / cost | 条件 | effects | event key | NPC复用 |
|---|---|---:|---|---|---|---|
| `action_arcane_guild_locate_dragon_lair` | `dragon_lair.locate_without_alert` / `dragon_tracking` | 16 / 25 / 2 / 6 | 巨龙未死亡、未被捕获 | 捕获准备+8，疲劳钟+2，毁坏+1 | `event_dragon_lair_located` | 定位巢穴合同 |
| `action_arcane_guild_collect_dragon_scales` | `dragon_capture.collect_scales` / `capture_research` | 16 / 30 / 2 / 8 | 已定位巢穴 | 捕获准备+10，疲劳钟+6，毁坏+3 | `event_low_quality_scales_collected` | 鳞片合同 |
| `action_arcane_guild_deploy_binding_towers` | `dragon_capture.deploy_binding_towers` / `dragon_capture` | 18 / 35 / 2 / 10 | 捕获准备>=60 | 捕获准备+8，毁坏+4 | `event_binding_towers_partially_operational` | 束缚塔合同 |
| `action_arcane_guild_ward_necrotic_spread` | `necrotic_ward.contain_spread` / `necrotic_spread` | 17 / 35 / 1 / 6 | 污染问题 active | 污染-8，捕获准备+2，毁坏+1 | `event_necrotic_spread_warded` | 否 |
| `action_arcane_guild_analyze_flight_pattern` | `dragon_flight.analyze` / `dragon_assault` | 8 / 20 / 1 / 4 | 龙袭问题 active | 捕获准备+4，疲劳钟+2，毁坏+1 | `event_dragon_flight_pattern_analyzed` | 否 |

## 8. 死灵集团行动表

| action ID | target lock / problem tags | base / urgency / cooldown / cost | 条件 | effects | event key | NPC复用 |
|---|---|---:|---|---|---|---|
| `action_necrotic_collective_recover_corpses` | `battlefield.recover_intact_corpses` / `battlefield_corpses` | 16 / 30 / 1 / 6 | 巨龙灾变未结束 | 污染+12 | `event_corpses_recovered_by_collective` | 尸体回收合同 |
| `action_necrotic_collective_prepare_dragon_bait` | `dragon_bait.prepare_village_stores` / `dragon_assault` | 17 / 35 / 2 / 8 | 龙袭问题 active | 疲劳钟+10，毁坏+10，污染+6 | `event_dragon_diverted` | 巨龙诱饵合同 |
| `action_necrotic_collective_secure_source` | `necrotic_source.secure_for_collective` / `necrotic_spread` | 18 / 35 / 2 / 7 | 污染问题 active | 污染+8，毁坏+2 | `event_necrotic_source_secured` | 污染源合同 |
| `action_necrotic_collective_seed_resonance` | `necrotic_ritual.seed_conversion` / `forbidden_ritual` | 16 / 35 / 1 / 5 | 污染>=25 | 污染+8，毁坏+3 | `event_necrotic_resonance_seeded` | 否 |

## 9. 行动与 target lock 审计

| 合同目标 | 同 lock 行动 | 规则结果 |
|---|---|---|
| 北路撤离 | `action_free_alliance_evacuate_north_road` | NPC完成复用；pending 时行动不能抢占 |
| 石桥防线 | `action_free_alliance_reinforce_stone_bridge` | 仅常规直接行动；合同未处理仍按问题恶化 |
| 战地治疗队 | `action_free_alliance_stabilize_field_camp` | 不复用；同目标排他 |
| 矿村救援 | `action_free_alliance_search_mining_village` | 不复用；同目标排他 |
| 巨龙定位 | `action_arcane_guild_locate_dragon_lair` | NPC完成复用 |
| 鳞片样本 | `action_arcane_guild_collect_dragon_scales` | NPC完成复用 |
| 束缚塔 | `action_arcane_guild_deploy_binding_towers` | NPC完成复用 |
| 污染源 | `action_necrotic_collective_secure_source` | NPC完成复用 |
| 反仪式 | 无同 lock 行动 | 魔法结界与死灵共振使用不同 lock，可合并 |
| 尸体回收 | `action_necrotic_collective_recover_corpses` | NPC完成复用 |
| 巨龙诱饵 | `action_necrotic_collective_prepare_dragon_bait` | NPC完成复用 |

道路侦察没有同 lock 行动；自由联盟的难民路线巡逻使用不同 lock，因此可以在 pending 侦察合同存在时先取得较低质量的安全路线。魔法工会飞行分析和死灵集团诱饵可以同时作用于龙袭问题，但使用不同 lock，且只提交可交换相加的钟增量与事件，不直接写问题终态。

## 10. 合同覆盖审计

合同自身字段与代表性数值见 `docs/content/contracts/09_contract_template_catalog.md`。审计后的关键变更只有两项：

1. `contract_north_road_evacuation` 从道路问题改锚到 `problem_evacuating_civilians`。道路侦察解决道路问题并创建撤离问题，北路撤离随后以 problem 或 followup 来源出现。
2. `contract_investigate_necrotic_source` 改由死灵集团提出，并重写为“控制失控的死灵污染源”。专业完成可以避免一次更大的无序扩散，但仍会把污染核心交给死灵集团并提高污染。

合同总数仍为 12，提出方分布为自由联盟 5、魔法工会 4、死灵集团 3。数量不平均，但三个阵营始终各占一个合同栏，因此不会影响每周可见性。

### 10.1 目标覆盖矩阵

| 阵营小目标 | 玩家合同 | NPC行动 | 主要钟/事件 |
|---|---|---|---|
| `free_secure_routes` | 道路侦察 | 难民路线巡逻 | 安全路线事件、撤离 |
| `free_rescue_isolated` | 矿村救援、治疗队 | 搜索矿村、稳定营地 | 撤离、污染 |
| `free_hold_corridor` | 石桥防线 | 加固石桥 | 撤离、巨龙疲劳、毁坏 |
| `free_complete_evacuation` | 北路撤离 | 自行撤离 | 撤离达到70 |
| `arcane_locate_target` | 定位巢穴 | 自行定位、飞行分析 | 巢穴事件、捕获准备 |
| `arcane_calibrate_binding` | 鳞片样本 | 低质量样本 | 准备达到30 |
| `arcane_contain_corruption` | 破坏仪式 | 污染结界 | 污染低于60 |
| `arcane_complete_capture` | 束缚塔 | 部分束缚塔 | 准备80、疲劳60 |
| `necrotic_secure_material` | 尸体回收 | 自行回收 | 污染上升 |
| `necrotic_control_source` | 控制污染源 | 掌握污染源 | 污染上升、失控问题关闭 |
| `necrotic_shape_battlefield` | 巨龙诱饵 | 粗放诱饵 | 疲劳、毁坏、污染 |
| `necrotic_complete_conversion` | 三类死灵合同反复推进 | 共振播种 | 污染达到100 |

### 10.2 问题—合同—行动矩阵

| 世界问题 | 玩家合同 | 可用主要行动 | 未处理方向 |
|---|---|---|---|
| 东部道路 | 道路侦察 | 难民路线巡逻 | 道路失守 |
| 平民撤离 | 北路撤离、石桥防线 | 自行撤离、加固石桥 | 撤离线崩溃 |
| 战地医疗 | 治疗队 | 稳定营地 | 医疗系统失败 |
| 矿村失联 | 矿村救援 | 搜索幸存者 | 矿村覆灭 |
| 巨龙位置 | 定位巢穴 | 自行定位 | 巨龙迁移 |
| 捕获窗口 | 鳞片、束缚塔 | 收集样本、部分束缚塔 | 捕获窗口关闭 |
| 污染扩散 | 控制污染源、破坏仪式 | 掌握污染源、污染结界、播种共振 | 污染暴涨 |
| 战场尸体 | 尸体回收 | 自行回收、污染结界 | 尸体转化 |
| 巨龙袭击 | 巨龙诱饵 | 诱饵、巡逻、飞行分析 | 村庄焚毁 |

## 11. 结局路径校准

以下使用 `docs/content/contracts/09_contract_template_catalog.md` 中“所有四个 check 均为 Success”的代表性净增量，只验证内容可达性，不替代实际随机结算。

### 11.1 大规模撤离

```text
初值撤离 5
+ 道路侦察 5
+ 北路撤离 18
+ 矿村救援 14
+ 石桥防线 12
+ 两次治疗队 16
= 70
```

这些合同从第 1 周开始按解锁顺序可在第 8—9 周前完成；结局从第 10 周开始判定。毁坏仍会因被动变化和行动代价上升，使该路径不是无代价最优解。

### 11.2 魔法工会活捕

```text
捕获准备：定位 12 + 三次鳞片 54 + 束缚塔 16 = 82

巨龙疲劳：初值 15
- 第2至第10周自然恢复 18
+ 定位 4
+ 三次鳞片 36
+ 束缚塔 5
+ 石桥防线 10
+ 巨龙诱饵 14
= 66
```

诱饵会增加毁坏和污染，石桥会占用救援周，说明最高捕获效率需要跨阵营且带有长期代价。只使用魔法工会合同时也可由其直接行动补足疲劳，但会消耗 influence 和更多周数。

### 11.3 死灵灾变

```text
第10周基础污染：初值 5 + 九次被动增长 18 = 23
+ 三次尸体回收 21
+ 一次控制污染源 8
+ 四次巨龙诱饵 40
+ 一次共振播种 8
= 100
```

玩家可以主动帮助死灵集团，也可能因为长期保留其 pending 合同而让其使用其他 target lock 的直接行动推进。两条路径都能在第 10—14 周进入灾变。

### 11.4 巨龙被杀

- `contract_deploy_binding_towers` 只允许在 `phase_final_window` 出现。
- 其 Severe 仪式结果 `target_killed` 必须映射为 `event_dragon_killed`，并与各阶段严重毁坏合计形成高代价结果。
- 其他内容不得在早期或中期创建该事件。
- 如果玩家既未撤离、未完成安全活捕，也未使污染达到 100，第 15 周使用既定保底触发器杀死巨龙。

## 12. 基准合同审计结果

- `contract_north_road_evacuation`：四阶段数值继续代表撤离主路径；只需把问题锚点与恶化引用从东部道路改为平民撤离问题。
- `contract_deploy_binding_towers`：数值保留；可用阶段收窄为最终窗口，并把 `target_killed` 映射为规范世界事件。
- `contract_recover_intact_corpses`：数值与最低污染代价保留，不需要重做。

因此没有基准合同需要整体重写，只需要两项锚点/可用性修订。其余九份合同在实现任务中按合同目录的代表性净增量分配到四个 check 和最终结果表。

## 13. 完成标准

- 九个问题各有一次性激活、紧迫度、期限、玩家路径、NPC路径、解决与唯一恶化事件。
- 三个阵营在每个非结局阶段都有至少一项可能合法的不同 lock 行动；没有合法目标时允许等待。
- 七个 NPC 完成行动与合同提出方、target lock、成本和效果一致。
- 十二份合同全部连接阵营小目标、世界问题、钟、世界事件与潜在结局。
- 三个 fallback 合同从开局合法，目标锁互不相同。
- 四种结局各有一条 10—15 周可达路径。
- 不引入第十个问题、第十三份合同或 V0.2 行动冲突框架。
