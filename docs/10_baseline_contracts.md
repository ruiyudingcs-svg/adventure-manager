# 三份基准合同完整定义 V0.1

状态：Accepted balance baseline  
日期：2026-07-19

## 1. 目的

本文件完整定义三份机制差异最大的基准合同，用于验证阶段判定、MissionContext、条款、价值观、阵营和世界钟能否共享同一数据模型。数值是首轮可测试基准，不是最终平衡值；修改时必须人工审查原因日志和预期差异。

三份合同：

1. `contract_north_road_evacuation`
2. `contract_deploy_binding_towers`
3. `contract_recover_intact_corpses`

## 2. 公共约定

能力权重顺序：`F/O/Sc/Su/A/D`，分别表示 frontline、offense、scouting、support、arcana、discipline。  
价值观向量顺序：`L/A/K/P/T`，分别表示 protect_life、respect_authority、seek_knowledge、pursue_profit、taboo_tolerance。

判定等级点数：Exceptional 100、Success 75、Partial 50、Failure 25、Severe 0。每份合同固定执行四个正权重判定，权重总和为 1.0；最终合同分数直接求加权和，不再归一化。

所有手算样例默认选择 Balanced，因此 Approach 评分与合同级 MissionContext 修正均为 0。各 check 的 profile 已显式列出，Cautious 与 Aggressive 按 `docs/15_staged_contract_resolution_rules.md` 的全局表结算。

表格缩写：

- `ctx`：立即应用的 MissionContextDelta。
- `world`：延迟应用的世界钟变化。
- `risk`：该 check 追加的伤病风险百分点。
- `tags`：结果标签。

世界钟缩写：

- `evacuated` = `villagers_evacuated`
- `destruction` = `settlement_destruction`
- `dragon_exhaustion` = `dragon_exhaustion`
- `capture_preparation` = `capture_preparation`
- `corruption` = `necrotic_corruption`

所有未列出的 ctx 和 world 变化为 0。所有效果仍需在实现中生成独立 ReasonEntry。

## 3. 北境道路村民撤离

### 3.1 合同头

```text
id: contract_north_road_evacuation
sponsor: faction_free_adventurers
related_problem: problem_evacuating_civilians
target_lock_key: north_road.evacuate_civilians
base_reward: 220
base_fatigue: 12
risk_level: 2
offer_duration_weeks: 2
unhandled_policy: npc_or_escalate
npc_completion_action_id: action_free_alliance_evacuate_north_road
intent_ideology_vector: L+4 A+1 K0 P0 T-1
expected_method_tags: rescue, protection, evacuation
allowed_supplies: medical, scouting, protection, rations
```

模板初始 MissionContext 全部为 0。Offer 生成时可以按 `docs/12_contract_instantiation_and_commitment.md` 叠加锁定初值，但不得改变本合同固定的四个 check 或阶段顺序。

### 3.2 阶段与判定

| phase | check ID | type | profile | difficulty | weight | capability weights | failure cap |
|---|---|---|---|---:|---:|---|---|
| approach | evac_find_safe_route | navigation | careful | 22 | 0.15 | F.10/O0/Sc.55/Su.15/A0/D.20 | Partial |
| main_action | evac_secure_column | protection | careful | 30 | 0.30 | F.45/O.10/Sc0/Su.25/A0/D.20 | Partial |
| special_objective | evac_recover_stragglers | rescue | careful | 26 | 0.25 | F.15/O0/Sc.20/Su.40/A0/D.25 | Partial |
| extraction | evac_move_column_out | extraction | careful | 28 | 0.30 | F.20/O0/Sc.25/Su.25/A0/D.30 | Failure |

实际 method tags：

- `evac_find_safe_route`：scouting、rescue。
- `evac_secure_column`：protection、nonlethal。
- `evac_recover_stragglers`：rescue、medical。
- `evac_move_column_out`：evacuation、protection。

结构化上下文修正：

- `evac_secure_column`：route_safety 每点 +2，最多 +6；enemy_pressure 每点 -2。
- `evac_recover_stragglers`：intel 每点 +2，最多 +6；time_pressure 每点 -2。
- `evac_move_column_out`：route_safety 每点 +2；protected_civilians 每点 +1，最多 +4；time_pressure 每点 -2；extraction_pressure 每点 -3。
- scouting tools 对 navigation +5；medical 对 rescue +5；protection supplies 对 protection +5。

### 3.3 CheckOutcome

#### evac_find_safe_route

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | route_safety+3, intel+2 | destruction+0 | 0 | route_mastered | L+1 |
| Success | route_safety+2, intel+1 | destruction+1 | 0 | route_secured | L+1 |
| Partial | route_safety+1, time_pressure+1 | destruction+2 | 0 | route_uncertain | 0 |
| Failure | time_pressure+2, enemy_pressure+1 | destruction+4 | +5 | route_delayed | 0 |
| Severe | route_safety-1, time_pressure+3, enemy_pressure+2 | destruction+6 | +10 | route_compromised | L-1 |

#### evac_secure_column

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | protected_civilians+3, enemy_pressure-2 | destruction+0, dragon_exhaustion+2 | 0 | column_secure | L+1 |
| Success | protected_civilians+2, enemy_pressure-1 | destruction+1, dragon_exhaustion+1 | +3 | column_protected | L+1 |
| Partial | protected_civilians+1, team_strain+1 | destruction+3 | +8 | column_disrupted | 0 |
| Failure | collateral_pressure+2, team_strain+2 | destruction+6 | +15 | civilians_exposed | L-1 |
| Severe | collateral_pressure+3, extraction_pressure+2 | destruction+9 | +25 | column_broken | L-2 |

#### evac_recover_stragglers

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | protected_civilians+4 | destruction+0 | 0 | all_stragglers_recovered | L+2 |
| Success | protected_civilians+3, time_pressure+1 | destruction+1 | +3 | all_stragglers_recovered | L+2 |
| Partial | protected_civilians+2, time_pressure+2 | destruction+2 | +8 | some_stragglers_recovered | L+1 |
| Failure | protected_civilians+1, time_pressure+2, collateral_pressure+1 | destruction+4, corruption+1 | +12 | stragglers_abandoned | L-2 |
| Severe | collateral_pressure+2, extraction_pressure+1 | destruction+6, corruption+3 | +20 | stragglers_lost | L-3 |

#### evac_move_column_out

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | — | evacuated+24, destruction+2, dragon_exhaustion+4, corruption-3 | 0 | evacuation_complete | L+2 |
| Success | — | evacuated+18, destruction+5, dragon_exhaustion+2 | +3 | evacuation_success | L+2 |
| Partial | — | evacuated+10, destruction+10, corruption+2 | +8 | evacuation_partial | L+1 |
| Failure | — | evacuated+3, destruction+16, corruption+5 | +15 | evacuation_failed | L-2 |
| Severe | — | evacuated+0, destruction+24, dragon_exhaustion-2, corruption+10 | +25 | evacuation_disaster | L-4 |

### 3.4 条款

| clause | importance/category | condition | success | failure |
|---|---|---|---|---|
| evac_no_wounded_abandoned | mandatory/target_state | tag all_stragglers_recovered | tag clause.humane_evacuation, ideology L+1 | reward -20%, sponsor relation -6, cap Partial, ideology L-3 |
| evac_collateral_limit | mandatory/collateral | final collateral_pressure <=2 | sponsor relation +2 | sponsor relation -4, tag clause.excessive_destruction |
| evac_no_heavy_injury | bonus/personnel_safety | heavy injury count <=0 | reward +10%, sponsor relation +2 | 无 |

### 3.5 合同最终结果表

| tier | reward multiplier | fatigue multiplier | base sponsor relation | tags |
|---|---:|---:|---:|---|
| Exceptional | 1.25 | 0.90 | +8 | contract.exceptional, evacuation.heroic |
| Success | 1.00 | 1.00 | +5 | contract.success |
| Partial | 0.65 | 1.10 | +1 | contract.partial |
| Failure | 0.25 | 1.25 | -4 | contract.failure |
| Severe | 0.00 | 1.40 | -8 | contract.severe_failure |

### 3.6 未处理配置

- 策略：`npc_or_escalate`。
- NPC 路径引用 `action_free_alliance_evacuate_north_road`；该行动消耗 influence 8，并产生 evacuated+10、destruction+8。
- NPC 路径不可执行且问题仍 active 时，复用 `problem_evacuating_civilians.escalation_effects`：撤离线崩溃事件、destruction+15、corruption+5，并关闭本合同入口。
- 如果关联问题已经不是 active，则本 Offer 只进入 `expired`，不重复应用世界效果。

### 3.7 手算样例

固定 seed 和 fixture 队伍得到：

```text
evac_find_safe_route       48 → Partial     ×0.15
evac_secure_column         66 → Success     ×0.30
evac_recover_stragglers    55 → Partial     ×0.25
evac_move_column_out       63 → Success     ×0.30

contract_score = 50×.15 + 75×.30 + 50×.25 + 75×.30 = 65
initial tier = Success
```

由于 `all_stragglers_recovered` 缺失，第一条 Mandatory 失败，最终等级封顶为 Partial。该路径最终 `collateral_pressure = 0` 且无人重伤：

```text
reward percent = 100 -20 +10 = 90
final reward = round(220 × 0.65 × 0.90) = 129
sponsor relation = +1 -6 +2 +2 = -1
```

该样例证明较高加权分数不能掩盖关键人道条款失败。

## 4. 部署奥术束缚塔

### 4.1 合同头

```text
id: contract_deploy_binding_towers
sponsor: faction_arcane_guild
related_problem: problem_dragon_capture_window
target_lock_key: dragon_capture.deploy_binding_towers
base_reward: 300
base_fatigue: 15
risk_level: 3
offer_duration_weeks: 2
unhandled_policy: npc_or_escalate
npc_completion_action_id: action_arcane_guild_deploy_binding_towers
intent_ideology_vector: L+1 A+2 K+4 P+1 T+2
expected_method_tags: research, protection, ritual, capture, nonlethal
allowed_supplies: scouting, protection, arcane_binding, rations
availability: phase_final_window AND capture_preparation >= 60
```

该合同只在最终窗口出现。`towers_calibrated` 或 `towers_operational` 在合并阶段映射为 `event_binding_towers_operational`；`binding_raise_towers` 的 Severe 结果 `target_killed` 映射为 `event_dragon_killed`。四个 check 全部 Severe 时累计 destruction+35，满足高代价杀龙语义。中期不得生成本合同，也不得由该标签提前创建杀龙事件。

### 4.2 阶段与判定

| phase | check ID | type | profile | difficulty | weight | capability weights | failure cap |
|---|---|---|---|---:|---:|---|---|
| approach | binding_survey_leyline | reconnaissance | careful | 26 | 0.15 | F0/O0/Sc.30/Su.10/A.40/D.20 | Partial |
| main_action | binding_secure_sites | confrontation | forceful | 32 | 0.25 | F.35/O.25/Sc.10/Su.10/A0/D.20 | Partial |
| special_objective | binding_raise_towers | ritual | careful | 36 | 0.40 | F.10/O0/Sc0/Su.20/A.45/D.25 | Partial |
| extraction | binding_withdraw_team | extraction | careful | 30 | 0.20 | F.15/O0/Sc.30/Su.20/A.10/D.25 | Failure |

实际 method tags：

- `binding_survey_leyline`：research、reconnaissance。
- `binding_secure_sites`：protection、confrontation。
- `binding_raise_towers`：ritual、binding、nonlethal。
- `binding_withdraw_team`：stealth、extraction。

上下文修正：

- secure_sites：intel 每点 +2，alert_level 每点 -2。
- raise_towers：intel 每点 +2，最多 +6；team_strain 每点 -2；arcane_binding supply +8。
- withdraw_team：route_safety 每点 +2；alert_level 每点 -3；extraction_pressure 每点 -3。
- Cautious 在 ritual 不扣分但 time_pressure+1；Aggressive 在 confrontation +5，但 collateral_pressure+1、alert_level+1。

### 4.3 CheckOutcome

#### binding_survey_leyline

| tier | ctx | world | risk | tags |
|---|---|---|---:|---|
| Exceptional | intel+3, route_safety+2, alert_level-1 | capture_preparation+2 | 0 | leyline_mastered |
| Success | intel+2, route_safety+1 | capture_preparation+1 | 0 | leyline_mapped |
| Partial | intel+1, time_pressure+1 | — | 0 | leyline_uncertain |
| Failure | time_pressure+2, alert_level+1 | destruction+2 | +5 | survey_exposed |
| Severe | alert_level+2, enemy_pressure+2 | destruction+4 | +10 | dragon_alerted |

#### binding_secure_sites

| tier | ctx | world | risk | tags |
|---|---|---|---:|---|
| Exceptional | enemy_pressure-2, team_strain+0 | dragon_exhaustion+3 | +3 | sites_secure |
| Success | enemy_pressure-1, team_strain+1 | dragon_exhaustion+2 | +5 | sites_held |
| Partial | team_strain+2, collateral_pressure+1 | destruction+2, dragon_exhaustion+1 | +10 | sites_contested |
| Failure | team_strain+3, alert_level+1 | destruction+5 | +18 | sites_breached |
| Severe | extraction_pressure+2, alert_level+2 | destruction+9, dragon_exhaustion-2 | +28 | deployment_routed |

#### binding_raise_towers

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | extraction_pressure-1 | capture_preparation+20, dragon_exhaustion+4 | 0 | towers_calibrated, target_alive | K+2,L+1 |
| Success | — | capture_preparation+15, dragon_exhaustion+3 | +3 | towers_operational, target_alive | K+2,L+1 |
| Partial | alert_level+1 | capture_preparation+8, destruction+2 | +8 | towers_unstable, target_alive | K+1 |
| Failure | alert_level+2, extraction_pressure+1 | capture_preparation+2, destruction+6 | +15 | binding_failed, target_alive | K-1 |
| Severe | alert_level+3, extraction_pressure+3 | capture_preparation+0, destruction+12 | +25 | tower_collapse, target_killed | L-4,K-2 |

#### binding_withdraw_team

| tier | ctx | world | risk | tags |
|---|---|---|---:|---|
| Exceptional | — | destruction+0 | 0 | withdrawal_clean, operation_hidden |
| Success | — | destruction+1 | +3 | withdrawal_success |
| Partial | — | destruction+3 | +8 | withdrawal_observed |
| Failure | — | destruction+6 | +18 | team_cut_off, sponsor_exposed |
| Severe | — | destruction+10, capture_preparation-4 | +30 | withdrawal_disaster, sponsor_exposed |

### 4.4 条款

| clause | importance/category | condition | success | failure |
|---|---|---|---|---|
| binding_target_alive | mandatory/target_state | tag target_alive and target_killed absent | sponsor relation +3, ideology L+1 | reward -30%, sponsor relation -10, cap Failure, ideology L-4 |
| binding_use_calibrated_device | mandatory/method | supply arcane_binding present and method binding used | tag clause.calibrated_binding | reward -20%, sponsor relation -6, cap Partial |
| binding_no_necromancy | mandatory/method | method necromancy not used | ideology T-1 | reward -25%, sponsor relation -8, cap Failure, ideology T+3,A-2 |
| binding_operation_hidden | bonus/secrecy | tag operation_hidden | reward +15%, sponsor relation +3 | 无 |

### 4.5 合同最终结果表

| tier | reward multiplier | fatigue multiplier | base sponsor relation | tags |
|---|---:|---:|---:|---|
| Exceptional | 1.30 | 0.90 | +10 | contract.exceptional, capture.breakthrough |
| Success | 1.00 | 1.00 | +6 | contract.success, capture.progress |
| Partial | 0.60 | 1.15 | +1 | contract.partial |
| Failure | 0.20 | 1.30 | -5 | contract.failure |
| Severe | 0.00 | 1.50 | -10 | contract.severe_failure |

### 4.6 未处理配置

- 策略：`npc_or_escalate`。
- NPC 路径引用 `action_arcane_guild_deploy_binding_towers`；该行动消耗 influence 10，并产生 capture_preparation+8、destruction+4。
- NPC 路径不可执行且问题仍 active 时，复用 `problem_dragon_capture_window.escalation_effects`：捕获窗口关闭、destruction+8、capture_preparation-6，并生成巨龙迁移事件。
- 如果关联问题已经不是 active，则本 Offer 只进入 `expired`，不重复应用世界效果。

### 4.7 手算样例

```text
binding_survey_leyline   68 → Success  ×0.15
binding_secure_sites     54 → Partial  ×0.25
binding_raise_towers     72 → Success  ×0.40
binding_withdraw_team    57 → Partial  ×0.20

contract_score = 75×.15 + 50×.25 + 75×.40 + 50×.20 = 63.75
initial tier = Success
```

队伍携带束缚器、没有使用死灵术、目标存活，但行动未保持隐蔽。Mandatory 全部满足，Bonus 失败：

```text
final tier = Success
final reward = round(300 × 1.00) = 300
sponsor relation = +6 +3 = +9
```

## 5. 回收战场完整尸体

### 5.1 合同头

```text
id: contract_recover_intact_corpses
sponsor: faction_necrotic_collective
related_problem: problem_battlefield_corpses
target_lock_key: battlefield.recover_intact_corpses
base_reward: 360
base_fatigue: 14
risk_level: 3
offer_duration_weeks: 1
unhandled_policy: npc_or_escalate
npc_completion_action_id: action_necrotic_collective_recover_corpses
intent_ideology_vector: L-2 A-3 K+2 P+4 T+5
expected_method_tags: stealth, corpse_handling, preservation, smuggling
allowed_supplies: scouting, protection, arcane_binding, rations
```

这份合同至少增加 4 点 necrotic_corruption。高技能只减少额外失控污染，不能把伦理代价优化为零。

### 5.2 阶段与判定

| phase | check ID | type | profile | difficulty | weight | capability weights | failure cap |
|---|---|---|---|---:|---:|---|---|
| approach | corpse_avoid_patrols | navigation | careful | 28 | 0.15 | F0/O0/Sc.45/Su.10/A.15/D.30 | Partial |
| main_action | corpse_secure_battlefield | confrontation | forceful | 32 | 0.25 | F.25/O.25/Sc.15/Su.15/A0/D.20 | Partial |
| special_objective | corpse_preserve_remains | salvage | neutral | 34 | 0.40 | F0/O0/Sc.10/Su.25/A.40/D.25 | Partial |
| extraction | corpse_smuggle_cargo | extraction | careful | 33 | 0.20 | F.10/O0/Sc.30/Su.20/A.15/D.25 | Failure |

实际 method tags：

- `corpse_avoid_patrols`：stealth、deception。
- `corpse_secure_battlefield`：confrontation、corpse_handling。
- `corpse_preserve_remains`：preservation、corpse_handling。
- `corpse_smuggle_cargo`：stealth、smuggling。

上下文修正：

- secure_battlefield：intel 每点 +2；alert_level 每点 -2。
- preserve_remains：collected_resources 初始不加分；team_strain 每点 -2；arcane_binding supply +4。
- smuggle_cargo：route_safety 每点 +2；alert_level 每点 -3；每超过3份 collected_resources，额外 -2。
- Cautious：所有 corruption 增量减少 2，最低仍为4，time_pressure+1。
- Aggressive：secure_battlefield +5，但 alert_level+1、collateral_pressure+1。

### 5.3 CheckOutcome

#### corpse_avoid_patrols

| tier | ctx | world | risk | tags |
|---|---|---|---:|---|
| Exceptional | route_safety+3, intel+2, alert_level-1 | — | 0 | approach_unseen |
| Success | route_safety+2, intel+1 | — | 0 | patrols_avoided |
| Partial | route_safety+1, time_pressure+1 | — | 0 | patrol_gap_narrow |
| Failure | alert_level+1, time_pressure+2 | destruction+1 | +5 | patrols_suspicious |
| Severe | alert_level+2, enemy_pressure+2 | destruction+3 | +12 | patrols_alerted |

#### corpse_secure_battlefield

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | collected_resources+1, enemy_pressure-2 | destruction+0 | +3 | field_secured | P+1,T+1 |
| Success | enemy_pressure-1 | destruction+1 | +5 | field_controlled | P+1,T+1 |
| Partial | team_strain+1, collateral_pressure+1 | destruction+3 | +10 | field_contested | L-1,T+1 |
| Failure | alert_level+1, team_strain+2 | destruction+6 | +18 | violent_recovery | L-2,T+2 |
| Severe | alert_level+2, extraction_pressure+2 | destruction+10, corruption+3 | +28 | battlefield_massacre | L-4,T+3 |

#### corpse_preserve_remains

| tier | ctx | world | risk | tags | ideology |
|---|---|---|---:|---|---|
| Exceptional | collected_resources+4 | corruption+4 | 0 | intact_corpses_4, remains_stable | L-1,K+2,P+2,T+4 |
| Success | collected_resources+3 | corruption+7 | +3 | intact_corpses_3, remains_stable | L-2,K+1,P+2,T+4 |
| Partial | collected_resources+2, alert_level+1 | corruption+10 | +8 | intact_corpses_2, remains_leaking | L-2,P+1,T+4 |
| Failure | collected_resources+1, alert_level+2 | corruption+13 | +15 | remains_damaged, remains_leaking | L-3,T+5 |
| Severe | collected_resources+0, alert_level+3, extraction_pressure+2 | corruption+18, destruction+4 | +25 | preservation_disaster | L-4,K-2,T+5 |

#### corpse_smuggle_cargo

| tier | ctx | world | risk | tags |
|---|---|---|---:|---|
| Exceptional | — | corruption+0 | 0 | cargo_delivered, operation_hidden |
| Success | — | corruption+0 | +3 | cargo_delivered, operation_hidden |
| Partial | — | corruption+1 | +8 | cargo_delivered, rumors_spread |
| Failure | — | corruption+3, destruction+2 | +18 | partial_delivery, sponsor_exposed |
| Severe | — | corruption+6, destruction+5 | +30 | cargo_lost, sponsor_exposed |

### 5.4 条款

| clause | importance/category | condition | success | failure |
|---|---|---|---|---|
| corpse_deliver_three | mandatory/delivery | collected_resources >=3 and tag cargo_delivered | sponsor relation +5, ideology P+1,T+2 | reward -40%, sponsor relation -10, cap Partial |
| corpse_keep_sponsor_secret | mandatory/secrecy | tag operation_hidden | sponsor relation +3 | reward -20%, sponsor relation -6, cap Partial, tag sponsor_exposed |
| corpse_arcane_residue | bonus/delivery | collected_resources >=4 and tag remains_stable | reward +20%, sponsor relation +2, ideology K+1 | 无 |

### 5.5 合同最终结果表

| tier | reward multiplier | fatigue multiplier | base sponsor relation | tags |
|---|---:|---:|---:|---|
| Exceptional | 1.35 | 0.95 | +10 | contract.exceptional, necrotic.delivery_prime |
| Success | 1.00 | 1.00 | +6 | contract.success, necrotic.delivery |
| Partial | 0.65 | 1.15 | +1 | contract.partial |
| Failure | 0.25 | 1.30 | -4 | contract.failure |
| Severe | 0.00 | 1.50 | -8 | contract.severe_failure |

### 5.6 未处理配置

- 策略：`npc_or_escalate`。
- 成功交付产生 `cargo_delivered` 时创建 `event_corpses_delivered`，供战场尸体问题的 resolution rule 使用；重复 Agenda 合同仍可创建历史事件，但问题不会重生。
- NPC 路径引用 `action_necrotic_collective_recover_corpses`；该行动消耗 influence 6，产生 corruption+12，并使用行动事件隐藏提出方身份。
- NPC 路径不可执行且问题仍 active 时，复用 `problem_battlefield_corpses.escalation_effects`：尸体自行转化、corruption+15、destruction+5，并创建游荡亡者问题。
- 如果关联问题已经不是 active，则本 Offer 只进入 `expired`，不重复应用世界效果。

### 5.7 手算样例

```text
corpse_avoid_patrols        67 → Success  ×0.15
corpse_secure_battlefield   51 → Partial  ×0.25
corpse_preserve_remains     69 → Success  ×0.40
corpse_smuggle_cargo        34 → Failure  ×0.20

contract_score = 75×.15 + 50×.25 + 75×.40 + 25×.20 = 58.75
initial tier = Partial
```

保存判定取得3具完整尸体，但撤离失败只形成 partial_delivery，交付条款失败；行动也没有保持隐蔽：

```text
reward percent = 100 -40 -20 = 40
final reward = round(360 × 0.65 × 0.40) = 94
sponsor relation = +1 -10 -6 = -15
```

如果撤离达到 Success，则两条 Mandatory 都满足，合同维持 Partial，报酬为 `round(360×0.65)=234`，但仍至少产生 7 点 corruption 和明确的成员价值观反应。

## 6. 基准合同共同验证结论

- 同一四阶段模型可以表达救援、非致命仪式和禁忌交付。
- 支持性上下文变化可以改变后续 check，而无需阶段脚本。
- 关键条款可以封顶最终等级，防止平均分掩盖主要违约。
- 世界钟由实际 CheckOutcome 改变，条款只评价和施加合同后果。
- 英雄能力影响 check，英雄价值观同时影响执行态度和任务后反馈。
- 高收益伦理合同保留不可优化掉的世界代价，确保成功率最高不等于长期最优。
- NPC 未处理结果使用简化阵营行动，不运行玩家四阶段模拟。
