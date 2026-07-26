# 其余九份合同完整数值规则 V0.1

状态：Accepted  
日期：2026-07-25  
负责范围：Gate E、Task 013

## 1. 文档职责

本文把 `docs/content/contracts/09_contract_template_catalog.md` 已固定的九份非基准合同展开成可直接
构造 `ContractDefinition` 的完整数值。文档 09 继续拥有合同身份、提出方、问题
锚点、target lock、Agenda 资格、阶段方向和代表性 Success/Failure 净世界变化；
本文不得覆盖这些内容。

三份基准合同继续由 `docs/rules/contracts/10_baseline_contracts.md` 单独负责：

- `contract_north_road_evacuation`
- `contract_deploy_binding_towers`
- `contract_recover_intact_corpses`

它们的 golden 不属于 Gate E，不得因实现本文而自动修改。

本文中的共享表只用于减少文档重复。Task 013 必须把每个 check 的五档 outcome、
权重、modifier、tag、ideology 和 effect 显式写入 `.tres`；运行时不得增加模板展开、
插值、合同 ID 分支或新的结算公式。

## 2. 九份合同头部

价值观顺序为 `L/A/K/P/T`，分别表示 protect life、respect authority、
seek knowledge、pursue profit 和 taboo tolerance。

| contract ID | base reward | base fatigue | risk | intent ideology |
|---|---:|---:|---:|---|
| `contract_hold_stone_bridge` | 240 | 14 | 3 | +3/+2/0/0/-1 |
| `contract_escort_field_healers` | 210 | 10 | 2 | +4/+1/0/-1/-2 |
| `contract_rescue_mining_village` | 250 | 13 | 3 | +5/0/0/-1/-2 |
| `contract_scout_eastern_road` | 160 | 8 | 2 | +2/0/+1/0/-1 |
| `contract_locate_dragon_lair` | 210 | 10 | 3 | 0/+1/+5/+1/+1 |
| `contract_investigate_necrotic_source` | 300 | 14 | 4 | -2/-2/+4/+3/+5 |
| `contract_collect_dragon_scales` | 280 | 15 | 4 | 0/+1/+5/+2/+2 |
| `contract_disrupt_necrotic_ritual` | 270 | 16 | 4 | +3/+1/+2/0/-4 |
| `contract_prepare_dragon_bait` | 320 | 15 | 4 | -4/-3/+1/+5/+4 |

九份合同的 `min_reputation = 0`。starts unlocked、repeat policy、来源、阶段、
proposal 参数、offer duration、availability、unhandled policy 和 NPC action
引用严格读取文档 09 第 3、10 节，不在本文重复定义。

## 3. Check 公共数值

### 3.1 能力权重与 Approach profile

能力顺序为 `F/O/Sc/Su/Ar/D`。同一 check type 在本文九份合同中使用相同权重：

| check type | capability weights | approach profile |
|---|---|---|
| `navigation` | 5/0/55/15/0/25 | careful |
| `reconnaissance` | 0/0/45/10/20/25 | careful |
| `protection` | 45/5/5/25/0/20 | careful |
| `rescue` | 20/0/15/40/0/25 | careful |
| `confrontation` | 25/35/10/5/5/20 | forceful |
| `salvage` | 5/5/15/30/25/20 | neutral |
| `ritual` | 5/0/5/20/45/25 | careful |
| `extraction` | 15/0/30/25/5/25 | careful |

每份合同固定四阶段。前三个 check 的 `failure_result_cap = Partial`，extraction 的
`failure_result_cap = Failure`。

### 3.2 阶段权重

救援、保护和侦察类以此作为初始设计基线：

```text
approach 0.15 / main_action 0.30 / special_objective 0.30 / extraction 0.25
```

研究、仪式和高风险伦理类以此作为初始设计基线：

```text
approach 0.15 / main_action 0.25 / special_objective 0.40 / extraction 0.20
```

上述数值只解释设计取向；第 4.1 节的逐合同显式权重才是唯一实现值，二者
不一致时一律以第 4.1 节为准。每份合同四项权重必须恰好合计 1.0。

### 3.3 Context modifier

以下 modifier 按阶段位置固定，不按合同 ID 分支：

```text
approach:
    none

main_action:
    intel 每点 +2，maximum_absolute_amount = 6
    alert_level 每点 -2，maximum_absolute_amount = 6

special_objective:
    intel 每点 +1，maximum_absolute_amount = 4
    team_strain 每点 -2，maximum_absolute_amount = 6

extraction:
    route_safety 每点 +2，maximum_absolute_amount = 6
    alert_level 每点 -3，maximum_absolute_amount = 9
    extraction_pressure 每点 -3，maximum_absolute_amount = 9
```

### 3.4 Context outcome 与 check injury risk

下表的 A/M/O/X 分别表示 approach、main action、special objective 和 extraction。
`objective` 使用第 4 节为各合同指定的 MissionContext key。负 context delta 仍由
MissionContext 在应用后裁剪到 0。

| tier | A context / risk | M context / risk | O context / risk | X context / risk |
|---|---|---|---|---|
| Exceptional | route_safety+3, intel+2, alert_level-1 / 0 | enemy_pressure-2 / 0 | objective+4 / 0 | — / 0 |
| Success | route_safety+2, intel+1 / 0 | enemy_pressure-1 / +3 | objective+3 / +3 | — / +3 |
| Partial | route_safety+1, time_pressure+1 / +3 | team_strain+1, collateral_pressure+1 / +8 | objective+2, time_pressure+1 / +8 | — / +8 |
| Failure | alert_level+1, time_pressure+2 / +8 | team_strain+2, collateral_pressure+2 / +15 | objective+1, alert_level+2 / +15 | — / +18 |
| Severe | alert_level+2, enemy_pressure+2 / +15 | team_strain+3, collateral_pressure+3, extraction_pressure+1 / +25 | alert_level+3, extraction_pressure+2 / +25 | — / +30 |

所有 check outcome 的 `fatigue` MemberEffect 为 0，不创建对应零值对象。疲劳只读取
base fatigue、Approach、补给和 final outcome multiplier。

## 4. 四阶段定义、方法与补给

### 4.1 Check ID、类型、难度和权重

| contract | phase | check ID | type | difficulty | weight | objective key |
|---|---|---|---|---:|---:|---|
| stone bridge | approach | `bridge_read_battlefield` | reconnaissance | 25 | 0.15 | — |
| stone bridge | main | `bridge_hold_line` | protection | 31 | 0.30 | — |
| stone bridge | special | `bridge_break_assault` | confrontation | 33 | 0.35 | `protected_civilians` |
| stone bridge | extraction | `bridge_withdraw` | extraction | 29 | 0.20 | — |
| field healers | approach | `healers_find_route` | navigation | 21 | 0.15 | — |
| field healers | main | `healers_guard_column` | protection | 27 | 0.30 | — |
| field healers | special | `healers_recover_crates` | salvage | 24 | 0.30 | `collected_resources` |
| field healers | extraction | `healers_deliver_camp` | extraction | 26 | 0.25 | — |
| mining village | approach | `mining_find_survivors` | navigation | 24 | 0.15 | — |
| mining village | main | `mining_free_villagers` | rescue | 30 | 0.35 | — |
| mining village | special | `mining_recover_supplies` | salvage | 27 | 0.20 | `collected_resources` |
| mining village | extraction | `mining_escape_collapse` | extraction | 29 | 0.30 | — |
| eastern road | approach | `road_find_crossing` | navigation | 19 | 0.25 | — |
| eastern road | main | `road_map_hazards` | reconnaissance | 22 | 0.30 | — |
| eastern road | special | `road_shield_scouts` | protection | 24 | 0.20 | `intel` |
| eastern road | extraction | `road_return_report` | extraction | 23 | 0.25 | — |
| dragon lair | approach | `lair_follow_tracks` | navigation | 23 | 0.15 | — |
| dragon lair | main | `lair_observe_pattern` | reconnaissance | 28 | 0.35 | — |
| dragon lair | special | `lair_collect_residue` | salvage | 29 | 0.30 | `collected_resources` |
| dragon lair | extraction | `lair_withdraw_unseen` | extraction | 27 | 0.20 | — |
| necrotic source | approach | `source_trace_leak` | reconnaissance | 28 | 0.15 | — |
| necrotic source | main | `source_secure_perimeter` | confrontation | 34 | 0.25 | — |
| necrotic source | special | `source_stabilize_core` | ritual | 35 | 0.40 | `collected_resources` |
| necrotic source | extraction | `source_smuggle_core` | extraction | 32 | 0.20 | — |
| dragon scales | approach | `scales_track_target` | reconnaissance | 29 | 0.15 | — |
| dragon scales | main | `scales_force_opening` | confrontation | 35 | 0.30 | — |
| dragon scales | special | `scales_extract_samples` | salvage | 34 | 0.35 | `collected_resources` |
| dragon scales | extraction | `scales_escape_pursuit` | extraction | 33 | 0.20 | — |
| disrupt ritual | approach | `ritual_reach_site` | navigation | 27 | 0.15 | — |
| disrupt ritual | main | `ritual_break_guard` | confrontation | 35 | 0.30 | — |
| disrupt ritual | special | `ritual_shatter_core` | ritual | 37 | 0.35 | `intel` |
| disrupt ritual | extraction | `ritual_extract_records` | extraction | 33 | 0.20 | — |
| dragon bait | approach | `bait_select_route` | navigation | 26 | 0.15 | — |
| dragon bait | main | `bait_prepare_stores` | salvage | 31 | 0.25 | — |
| dragon bait | special | `bait_bind_lure` | ritual | 35 | 0.40 | `collected_resources` |
| dragon bait | extraction | `bait_leave_unseen` | extraction | 32 | 0.20 | — |

### 4.2 Check method tags、expected tags 与 allowed supplies

每格中的四组 method tags 按阶段顺序对应 A/M/O/X。`expected_method_tags` 是四组
按出现顺序稳定去重后的并集。

| contract | check method tags A / M / O / X | allowed supply tags |
|---|---|---|
| stone bridge | reconnaissance+scouting / protection+nonlethal / confrontation+protection / extraction+evacuation | scouting, protection, medical, rations |
| field healers | scouting+medical / protection+medical / medical+research / extraction+medical | scouting, protection, medical, rations |
| mining village | scouting+rescue / rescue+medical / research+rescue / extraction+protection | scouting, protection, medical, rations |
| eastern road | scouting / reconnaissance+scouting / protection+nonlethal / extraction+scouting | scouting, protection, rations |
| dragon lair | scouting+stealth / reconnaissance+research / research+preservation / stealth+extraction | scouting, protection, arcane_binding, rations |
| necrotic source | reconnaissance+research / confrontation+protection / ritual+necromancy+preservation / smuggling+stealth | scouting, protection, arcane_binding, rations |
| dragon scales | reconnaissance+research / confrontation+nonlethal / research+preservation / stealth+extraction | scouting, protection, arcane_binding, rations |
| disrupt ritual | scouting+protection / confrontation+protection / ritual+binding / extraction+research | protection, medical, arcane_binding, rations |
| dragon bait | scouting+deception / deception+research / ritual+necromancy / stealth+smuggling | scouting, protection, arcane_binding, rations |

九份合同的 `instantiation_rules` 均为空数组。问题紧迫度继续影响提案分数，但不在
V0.1 额外改变 check difficulty 或初始 MissionContext。

## 5. 五档世界效果

### 5.1 Success/Failure 阶段锚点

缩写：E villagers evacuated、D settlement destruction、X dragon exhaustion、
P capture preparation、C necrotic corruption。每格为该阶段 `Success / Failure`。

| contract | A | M | O | X |
|---|---|---|---|---|
| stone bridge | X+1 / D+4 | E+4,D+1,X+3 / E+1,D+7,C+1 | E+4,D+2,X+5 / E+1,D+8,C+1 | E+4,D+1,X+1 / D+3,C+1 |
| field healers | — / D+2 | E+2,D+1,C-1 / E+1,D+5,C+3 | E+2,C-2 / D+3,C+3 | E+4,D+1,C-1 / E+1,D+4,C+2 |
| mining village | E+1 / D+3,C+1 | E+6,D+1,C-1 / E+2,D+7,C+4 | E+3,D+1,C-1 / D+5,C+4 | E+4,D+2 / E+1,D+5,C+3 |
| eastern road | E+1 / D+3 | E+1 / D+2,C+1 | E+1,D+1 / D+3,C+1 | E+2 / D+2 |
| dragon lair | P+1 / D+2,X-1 | X+1,P+5 / D+4,X-1 | D+1,X+2,P+4 / D+3 | X+1,P+2 / D+3 |
| necrotic source | C+1 / D+1,C+3 | D+1,C+2 / D+3,C+4 | D+1,C+4 / D+3,C+7 | C+1 / D+1,C+4 |
| dragon scales | X+1,P+3 / D+2,X-1 | D+2,X+6,P+3 / D+8,X-2 | D+1,X+4,P+10 / D+5,X-1,P+2 | X+1,P+2 / D+3 |
| disrupt ritual | C-2 / D+1,C+3 | D+2,C-4 / D+4,C+6 | D+1,C-10 / D+3,C+9 | C-2 / D+2,C+4 |
| dragon bait | D+1,X+1,C+1 / D+3,C+2 | D+3,X+3,C+2 / D+6,X+1,C+4 | D+4,X+8,C+5 / D+8,X+1,C+7 | D+2,X+2,C+2 / D+5,C+5 |

四个 Success 或四个 Failure 的合计必须精确等于文档 09 第 11 节。不得把该合计
再次写入 final outcome。

### 5.2 Exceptional、Partial 与 Severe 的 authoring 展开

对每个阶段、每个出现于 Success 或 Failure 锚点中的 clock，分别令 `s` 和 `f`
为该阶段 Success/Failure 数值；缺少该 clock 视为 0：

```text
step =
    0                                      if s == f
    max(1, round_away(abs(f - s) / 4.0))  otherwise

Exceptional = s + sign(s - f) * step
Success     = s
Partial     = round_away((s + f) / 2.0)
Failure     = f
Severe      = f + sign(f - s) * step
```

生成 authoring 数值时，villagers evacuated 和 settlement destruction 的单项结果
不得低于 0；零值 effect 不写入 Resource。其他 clock 允许负 delta，并在正式事务
中按既有 StateOperation 规则合并、裁剪。

以上展开在 Task 013 创建 `.tres` 时执行一次并固化。ContractResolver 不包含该
公式，也不从 Success/Failure 动态计算其他 tier。

## 6. Outcome tags 与 ideology

### 6.1 通用 tag 与 reason

每个 check outcome 都添加：

```text
<check_id>_<tier>
```

其中 tier 使用 `exceptional/success/partial/failure/severe`。每个非零 context、
member 或 world effect 的 reason code 使用：

```text
<check_id>_<tier>_<effect_or_context_key>
```

除此之外只添加下表所需的语义 tag：

| contract | semantic tags |
|---|---|
| stone bridge | `bridge_line_held`：O Exceptional/Success；`bridge_intact`：X Exceptional/Success |
| field healers | `healers_safe`：M Exceptional/Success；`medical_supplies_delivered`：X Exceptional/Success/Partial |
| mining village | `all_survivors_recovered`：M Exceptional/Success；`rescue_complete`：X Exceptional/Success/Partial |
| eastern road | `usable_route`：M Exceptional/Success；`route_report_delivered`：X Exceptional/Success/Partial |
| dragon lair | `lair_coordinates_found`：M Exceptional/Success；`dragon_alerted`：M Failure/Severe；`intelligence_delivered`：X Exceptional/Success/Partial |
| necrotic source | `source_core_intact`：O Exceptional/Success；`core_delivered`：X Exceptional/Success/Partial；`operation_hidden`：X Exceptional/Success |
| dragon scales | `target_alive`：M Exceptional/Success/Partial/Failure；`target_escaped`：M Severe；`sample_intact`：O Exceptional/Success；`sample_delivered`：X Exceptional/Success/Partial |
| disrupt ritual | `ritual_core_destroyed`：O Exceptional/Success；`contaminated_material_taken`：O Failure/Severe；`ritualists_identified`：X Exceptional/Success |
| dragon bait | `dragon_diverted`：O Exceptional/Success；`operation_hidden`：X Exceptional/Success |

鳞片合同的 Severe 只表示目标逃脱，不创建 `target_killed` 或
`event_dragon_killed`。V0.1 只有 final-window 束缚塔 Severe 和第 15 周保底触发器
可以创建杀龙事件。

### 6.2 Check outcome ideology

除 special objective 外，九份合同的 check outcome ideology 都为零。special
objective 使用以下五档：

| contract | Exceptional | Success | Partial | Failure | Severe |
|---|---|---|---|---|---|
| stone bridge | L+3,A+1 | L+2,A+1 | L+1 | L-2,A-1 | L-4,A-2 |
| field healers | L+4,A+1 | L+3,A+1 | L+1 | L-3 | L-5 |
| mining village | L+4 | L+3 | L+1 | L-3 | L-5 |
| eastern road | L+2,K+1 | L+1,K+1 | K+1 | L-1 | L-2 |
| dragon lair | K+4,A+1 | K+3,A+1 | K+1 | L-1,K-2 | L-2,K-4 |
| necrotic source | L-1,K+3,P+2,T+4 | L-2,K+2,P+2,T+4 | L-2,K+1,P+1,T+3 | L-4,K-1,T+5 | L-5,K-2,T+5 |
| dragon scales | K+4,P+2,T+1 | K+3,P+1,T+1 | K+1 | L-2,K-2 | L-4,K-3 |
| disrupt ritual | L+3,K+2,T-3 | L+2,K+1,T-2 | L+1,T-1 | L-3,K-1,T+3 | L-5,K-2,T+5 |
| dragon bait | L-2,A-2,P+4,T+3 | L-3,A-2,P+3,T+3 | L-3,A-1,P+2,T+3 | L-5,A-3,P+1,T+5 | L-5,A-4,T+5 |

## 7. 条款

每份合同的三条条款按本节表格顺序使用 authoring `priority = 10/20/30`；
即两条 mandatory 先后求值，bonus 最后求值。该顺序只负责稳定审计，不改变
第 8 节 final outcome profile。

每份合同恰好两个 Mandatory 和一个 Bonus。Mandatory 1 成功时 sponsor relation
+3，Mandatory 2 成功时 +2。Bonus 只在成功时应用表中效果；失败无 effect、cap、
tag 或 ideology。

### 7.1 自由联盟合同

| clause ID | importance/category | all conditions | success | failure |
|---|---|---|---|---|
| `bridge_hold_line_clause` | mandatory/target_state | tag `bridge_line_held` | relation +3；L+1 | reward -30%，relation -8，cap Failure；L-3 |
| `bridge_civilians_passed` | mandatory/collateral | protected_civilians >=3 | relation +2；L+1 | reward -15%，relation -4，cap Partial；L-2 |
| `bridge_intact_bonus` | bonus/efficiency | tag `bridge_intact` | reward +10%，relation +2；L+1 | — |
| `healers_keep_team_alive` | mandatory/personnel_safety | tag `healers_safe` | relation +3；L+1 | reward -30%，relation -8，cap Failure；L-4 |
| `healers_deliver_supplies` | mandatory/delivery | collected_resources >=3；tag `medical_supplies_delivered` | relation +2；L+1 | reward -20%，relation -5，cap Partial；L-2 |
| `healers_preserve_guild_medicine` | bonus/efficiency | selected supply tag `medical` absent | reward +10%，relation +2 | — |
| `mine_no_survivor_abandoned` | mandatory/target_state | tag `all_survivors_recovered` | relation +3；L+1 | reward -30%，relation -8，cap Failure；L-3 |
| `mine_complete_rescue` | mandatory/delivery | tag `rescue_complete` | relation +2；L+1 | reward -20%，relation -5，cap Partial；L-2 |
| `mine_recover_reserves` | bonus/delivery | collected_resources >=3 | reward +10%，relation +2；P+1 | — |
| `road_find_usable_route` | mandatory/target_state | tag `usable_route` | relation +3；K+1 | reward -30%，relation -8，cap Failure；K-2 |
| `road_deliver_report` | mandatory/delivery | tag `route_report_delivered` | relation +2 | reward -15%，relation -4，cap Partial；K-1 |
| `road_remain_unnoticed` | bonus/secrecy | alert_level <=1 | reward +10%，relation +2 | — |

### 7.2 魔法工会合同

| clause ID | importance/category | all conditions | success | failure |
|---|---|---|---|---|
| `lair_do_not_alert_dragon` | mandatory/secrecy | tag `dragon_alerted` absent | relation +3；L+1 | reward -30%，relation -8，cap Failure；L-2 |
| `lair_complete_intelligence` | mandatory/delivery | tag `lair_coordinates_found`；tag `intelligence_delivered` | relation +2；K+1 | reward -20%，relation -6，cap Partial；K-2 |
| `lair_collect_residue` | bonus/delivery | collected_resources >=3 | reward +15%，relation +3；K+1 | — |
| `scales_keep_target_alive` | mandatory/target_state | tag `target_alive` | relation +3；L+1 | reward -35%，relation -10，cap Failure；L-4 |
| `scales_deliver_intact_samples` | mandatory/delivery | tag `sample_intact`；tag `sample_delivered` | relation +2；K+1 | reward -25%，relation -8，cap Partial；K-2 |
| `scales_limit_collateral` | bonus/collateral | collateral_pressure <=1 | reward +15%，relation +3；L+1 | — |
| `ritual_destroy_core` | mandatory/target_state | tag `ritual_core_destroyed` | relation +3；L+1,T-1 | reward -35%，relation -10，cap Failure；L-3,T+3 |
| `ritual_take_no_contamination` | mandatory/method | tag `contaminated_material_taken` absent | relation +2；T-2 | reward -20%，relation -6，cap Partial；T+3 |
| `ritual_identify_operators` | bonus/delivery | tag `ritualists_identified` | reward +10%，relation +2；K+1 | — |

### 7.3 死灵集团合同

| clause ID | importance/category | all conditions | success | failure |
|---|---|---|---|---|
| `source_deliver_intact_core` | mandatory/delivery | tag `source_core_intact`；tag `core_delivered` | relation +3；P+1,T+2 | reward -35%，relation -10，cap Failure；L-2,T+3 |
| `source_keep_sponsor_secret` | mandatory/secrecy | tag `operation_hidden` | relation +2；A-1 | reward -20%，relation -6，cap Partial；A-2 |
| `source_protect_camp` | bonus/collateral | collateral_pressure <=1 | reward +10%，relation +2；L+1 | — |
| `bait_divert_dragon` | mandatory/target_state | tag `dragon_diverted` | relation +3；P+1,T+1 | reward -30%，relation -8，cap Failure |
| `bait_keep_sponsor_secret` | mandatory/secrecy | tag `operation_hidden` | relation +2；A-1 | reward -20%，relation -6，cap Partial；A-2 |
| `bait_no_civilian_deaths` | bonus/collateral | collateral_pressure <=1 | reward +15%，relation +2；L+2 | — |

## 8. Final outcome tables

所有 V0.1 合同继续使用固定 injury risk `-10/-5/0/+10/+20`。
Final outcome 不包含 `modify_clock`。

### 8.1 Relief profile

用于 stone bridge、field healers、mining village 和 eastern road：

| tier | reward multiplier | fatigue multiplier | injury | base relation |
|---|---:|---:|---:|---:|
| Exceptional | 1.25 | 0.90 | -10 | +8 |
| Success | 1.00 | 1.00 | -5 | +5 |
| Partial | 0.65 | 1.10 | 0 | +1 |
| Failure | 0.25 | 1.25 | +10 | -4 |
| Severe | 0.00 | 1.40 | +20 | -8 |

### 8.2 High-risk research profile

用于 dragon lair、necrotic source、dragon scales 和 disrupt ritual：

| tier | reward multiplier | fatigue multiplier | injury | base relation |
|---|---:|---:|---:|---:|
| Exceptional | 1.30 | 0.90 | -10 | +10 |
| Success | 1.00 | 1.00 | -5 | +6 |
| Partial | 0.60 | 1.15 | 0 | +1 |
| Failure | 0.20 | 1.30 | +10 | -5 |
| Severe | 0.00 | 1.50 | +20 | -10 |

### 8.3 High-profit ethical profile

用于 dragon bait：

| tier | reward multiplier | fatigue multiplier | injury | base relation |
|---|---:|---:|---:|---:|
| Exceptional | 1.35 | 0.95 | -10 | +10 |
| Success | 1.00 | 1.00 | -5 | +6 |
| Partial | 0.65 | 1.15 | 0 | +1 |
| Failure | 0.25 | 1.30 | +10 | -4 |
| Severe | 0.00 | 1.50 | +20 | -8 |

每档添加标准 `contract.exceptional/success/partial/failure/severe_failure` tag。
Exceptional 和 Success 额外创建下列关键事件；其他 tier 不创建：

| contract | event key |
|---|---|
| stone bridge | `event_stone_bridge_secured` |
| field healers | `event_field_healers_delivered` |
| mining village | `event_mining_village_rescued` |
| eastern road | `event_eastern_route_secured` |
| dragon lair | `event_dragon_lair_located` |
| necrotic source | `event_necrotic_source_secured` |
| dragon scales | `event_binding_scales_calibrated` |
| disrupt ritual | `event_necrotic_ritual_disrupted` |
| dragon bait | `event_dragon_diverted` |

关键事件只是离散事实，不重复增加第 5 节已经由 check outcomes 产生的 clock delta。

## 9. Gate E 验收

1. 九份合同全部能编译为四阶段、每阶段一个 check、五档 outcome 的
   `ContractDefinition`。
2. 每份合同的四个 Success 与四个 Failure 世界效果之和精确匹配文档 09。
3. Exceptional/Partial/Severe 按第 5.2 节展开后显式保存在 `.tres`，运行时不插值。
4. Task 017 人工批准调平后，三份基准 golden 为 Success/242/+9/12、
   Exceptional/390/+13/14、Partial/234/+2/16。
5. Final outcome 没有数值型世界钟效果，Success 事件不重复累计 clock。
6. 污染源和诱饵 Success 仍增加 corruption；技能不能消除伦理代价。
7. 鳞片合同不创建杀龙事件；只有 Accepted 晚期路径可以杀龙。
8. 所有 check、clause、method、supply、event 和 reason ID 稳定且引用闭合。
9. 相同 Definition、计划和 seed 重复结算得到完全相同结果。
10. Task 013 的四条真实周流程路径分别在既定 10—15 周窗口可达；差异必须人工
    审查，不得添加测试专用世界效果。
