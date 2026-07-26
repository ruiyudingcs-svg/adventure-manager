# V0.1 合同模板目录

状态：Accepted（TODO 21G 已完成）  
日期：2026-07-22

## 1. 目的与边界

本文件固定 V0.1 的 12 份手工合同模板及其设计覆盖。它确定合同身份、提出方、问题锚点、目标锁、阶段骨架、能力重点、条款方向、价值冲突、世界钟方向、Agenda 来源资格和未处理策略。

十二份模板已经按 `docs/17_dragon_invasion_scenario_spec.md` 的阵营目标与进度钟，以及 `docs/18_dragon_invasion_problem_and_action_catalog.md` 的问题和行动完成覆盖审计。模板总数固定为十二份。

本文件不重复保存合同的完整实现数值。三份基准合同见
`docs/10_baseline_contracts.md`；其余九份合同的精确 check 难度、五档数值、疲劳、
伤病率、条款和 MissionContextDelta 已由 Gate E 固定在
`docs/21_remaining_contract_numerical_rules.md`。合同来源、资格和筛选规则由
`docs/11_contract_proposal_generation.md` 固定；精确世界状态实例绑定见
`docs/12_contract_instantiation_and_commitment.md`。

## 2. 内容 ID

阵营：

- `faction_free_adventurers`：自由冒险者联盟
- `faction_arcane_guild`：魔法工会
- `faction_necrotic_collective`：死灵集团

问题锚点：

- `problem_eastern_road_blocked`
- `problem_evacuating_civilians`
- `problem_field_medical_collapse`
- `problem_mining_village_isolated`
- `problem_dragon_location_unknown`
- `problem_dragon_capture_window`
- `problem_necrotic_spread`
- `problem_battlefield_corpses`
- `problem_dragon_assault_pressure`

这些问题 ID 是合同内容锚点。问题来源使用显式合同白名单；标记为 Agenda 的模板还可以在没有 active 锚点问题时，由提出方用于推进自身目标。Agenda 版本仍使用同一手工阶段、条款和世界效果，运行时 `related_problem_id` 为空。

## 3. 总览

| ID | 类型 | 提出方 | 关联问题 | 目标锁 | Agenda 来源 |
|---|---|---|---|---|---|
| contract_north_road_evacuation | 撤离 | 自由联盟 | evacuating_civilians | north_road.evacuate_civilians | 否 |
| contract_hold_stone_bridge | 保护 | 自由联盟 | evacuating_civilians | stone_bridge.hold_evacuation_line | 否 |
| contract_escort_field_healers | 保护 | 自由联盟 | field_medical_collapse | field_hospital.escort_healers | 是 |
| contract_rescue_mining_village | 救援 | 自由联盟 | mining_village_isolated | mining_village.rescue_survivors | 否 |
| contract_scout_eastern_road | 侦察 | 自由联盟 | eastern_road_blocked | eastern_road.scout_route | 是 |
| contract_locate_dragon_lair | 侦察 | 魔法工会 | dragon_location_unknown | dragon_lair.locate_without_alert | 是 |
| contract_investigate_necrotic_source | 研究/采集 | 死灵集团 | necrotic_spread | necrotic_source.secure_for_collective | 否 |
| contract_collect_dragon_scales | 研究 | 魔法工会 | dragon_capture_window | dragon_capture.collect_scales | 是 |
| contract_deploy_binding_towers | 仪式 | 魔法工会 | dragon_capture_window | dragon_capture.deploy_binding_towers | 否 |
| contract_disrupt_necrotic_ritual | 仪式 | 魔法工会 | necrotic_spread | necrotic_ritual.disrupt_conversion | 否 |
| contract_recover_intact_corpses | 伦理 | 死灵集团 | battlefield_corpses | battlefield.recover_intact_corpses | 是 |
| contract_prepare_dragon_bait | 伦理 | 死灵集团 | dragon_assault_pressure | dragon_bait.prepare_village_stores | 是 |

未处理策略固定为：

| ID | unhandled_policy | npc_completion_action_id |
|---|---|---|
| contract_north_road_evacuation | npc_or_escalate | action_free_alliance_evacuate_north_road |
| contract_hold_stone_bridge | escalate | — |
| contract_escort_field_healers | escalate | — |
| contract_rescue_mining_village | escalate | — |
| contract_scout_eastern_road | escalate | — |
| contract_locate_dragon_lair | npc_or_expire | action_arcane_guild_locate_dragon_lair |
| contract_investigate_necrotic_source | npc_or_escalate | action_necrotic_collective_secure_source |
| contract_collect_dragon_scales | npc_or_expire | action_arcane_guild_collect_dragon_scales |
| contract_deploy_binding_towers | npc_or_escalate | action_arcane_guild_deploy_binding_towers |
| contract_disrupt_necrotic_ritual | escalate | — |
| contract_recover_intact_corpses | npc_or_escalate | action_necrotic_collective_recover_corpses |
| contract_prepare_dragon_bait | npc_or_escalate | action_necrotic_collective_prepare_dragon_bait |

带 NPC 路径的七项行动已经在 `docs/18_dragon_invasion_problem_and_action_catalog.md` 的 `weekly_action_table` 中定义，并与合同共享 target lock。所有恶化效果来自对应问题定义。Agenda 来源 Offer 运行时没有问题锚点，因此 NPC 路径不可执行后的恶化分支降为自然过期。

六份 Agenda 模板必须配置 `allow_agenda_origin = true`、`repeat_policy = repeatable`。其中每个阵营至少一份 fallback 模板必须覆盖所有非结局阶段；其余模板可以阶段性出现。问题来源存在时优先使用 problem 来源，不同时复制同一模板的 Agenda 候选。

开局数量保障模板固定为：

- 自由联盟：`contract_scout_eastern_road`
- 魔法工会：`contract_locate_dragon_lair`
- 死灵集团：`contract_recover_intact_corpses`

这三份配置 `starts_unlocked = true`，并以 Agenda 来源覆盖所有非结局阶段，分别作为三个阵营合同栏的 fallback。另三份 Agenda 模板用于阶段轮换。重复冷却只能降低排序，不能使 fallback 失去资格。

## 4. 撤离与保护合同

### 4.1 contract_north_road_evacuation

- 名称：北境道路村民撤离
- 战略目的：在道路彻底失守前转移村民。
- 阶段：navigation → protection → rescue → extraction。
- 能力重点：scouting、frontline、support、discipline。
- Mandatory：不得遗弃伤员；聚落毁坏增量不超过限制。
- Bonus：无英雄重伤。
- 价值冲突：保护生命与激进效率之间的冲突。
- 世界方向：`villagers_evacuated` 大幅增加；`settlement_destruction` 随过程和结果增加；失败可能提高 `necrotic_corruption`。
- 未处理策略：`npc_or_escalate`。自由联盟可通过 `action_free_alliance_evacuate_north_road` 以较高 influence 代价完成较小规模撤离；否则平民撤离线问题恶化并增加毁坏与污染。
- 可出现阶段：早期至中期；安全路线事件解锁后，以平民撤离问题或 followup 来源出现。

### 4.2 contract_hold_stone_bridge

- 名称：坚守石桥撤离线
- 战略目的：为后续撤离争取时间。
- 阶段：reconnaissance → protection → confrontation → extraction。
- 能力重点：frontline、discipline、offense、support。
- Mandatory：桥梁在撤离结束前不得失守。
- Bonus：保住桥体以供后续使用。
- 价值冲突：成员安全与牺牲少数守军换取整体撤离。
- 世界方向：提高 `villagers_evacuated` 与 `dragon_exhaustion`；失败显著提高 `settlement_destruction`。
- 未处理策略：`escalate`。撤离防线问题恶化，产生道路中断事件。
- 可出现阶段：中期至晚期。

### 4.3 contract_escort_field_healers

- 名称：护送战地治疗队
- 战略目的：把治疗人员和物资送入临时营地。
- 阶段：navigation → protection → salvage → extraction。
- 能力重点：support、scouting、frontline、discipline。
- Mandatory：治疗队成员不得死亡；医疗物资必须交付。
- Bonus：不消耗公会医疗包。
- 价值冲突：公共救援与公会自身补给储备。
- 世界方向：提高后续撤离效率，减少合同伤病后果，间接抑制毁坏。
- 未处理策略：`escalate`。医疗系统恶化，生成 `problem_field_medical_collapse` 的升级事件。
- 可出现阶段：全部非结局阶段；问题来源响应医疗崩溃，Agenda 来源表示持续补充救援资源。

### 4.4 contract_rescue_mining_village

- 名称：营救被困矿村
- 战略目的：从坍塌矿道和龙火中救出幸存者。
- 阶段：navigation → rescue → salvage → extraction。
- 能力重点：scouting、support、frontline、discipline。
- Mandatory：不得主动放弃已发现的伤员。
- Bonus：带回矿村储备和道路情报。
- 价值冲突：救援耗时与资源回收、全队安全。
- 世界方向：提高 `villagers_evacuated`；失败增加 `settlement_destruction` 与 `necrotic_corruption`。
- 未处理策略：`escalate`。矿村失联，尸体与废墟成为死灵污染来源。
- 可出现阶段：早期至中期。

## 5. 侦察与路线合同

### 5.1 contract_scout_eastern_road

- 名称：侦察燃烧的东部道路
- 战略目的：为后续撤离合同建立安全路线。
- 阶段：navigation → reconnaissance → protection → extraction。
- 能力重点：scouting、discipline、support。
- Mandatory：必须带回可用路线情报。
- Bonus：不惊动沿途龙兽。
- 价值冲突：快速返回与继续搜索被困者。
- 世界方向：直接钟变化较小；成功解锁或强化撤离合同，失败增加毁坏。
- 未处理策略：`escalate`。道路风险继续未知，提高后续撤离初始 `time_pressure`。
- 可出现阶段：问题来源为早期；Agenda 来源覆盖所有非结局阶段，表示持续更新道路与撤离路线情报。

### 5.2 contract_locate_dragon_lair

- 名称：定位巨龙临时巢穴
- 战略目的：建立活捕计划所需的巢穴坐标和行为情报。
- 阶段：navigation → reconnaissance → salvage → extraction。
- 能力重点：scouting、arcana、discipline。
- Mandatory：不得惊动巨龙；情报必须完整交付。
- Bonus：取得魔力痕迹样本。
- 价值冲突：研究价值与暴露附近聚落的风险。
- 世界方向：提高 `capture_preparation`，小幅提高 `dragon_exhaustion`；失败可能增加毁坏。
- 未处理策略：`npc_or_expire`。魔法工会可通过 `action_arcane_guild_locate_dragon_lair` 自行侦察但效率较低，并消耗 influence；不可执行时机会自然消失。
- 可出现阶段：问题来源为早期至中期；Agenda 来源覆盖所有非结局阶段，表示持续追踪巨龙巢穴与移动规律。

### 5.3 contract_investigate_necrotic_source

- 名称：控制失控的死灵污染源
- 提出方：死灵集团。
- 战略目的：在污染自行扩散前取回核心，并把它交给死灵集团继续利用。
- 阶段：reconnaissance → confrontation → ritual → extraction。
- 能力重点：arcana、scouting、support、discipline。
- Mandatory：污染核心必须保持完整并交付；不得公开委托方。
- Bonus：不让污染接触平民营地。
- 价值冲突：专业控制可以避免更严重的失控后果，但仍然帮助死灵集团掌握污染源并提高长期污染。
- 世界方向：Success 净增加少量 `necrotic_corruption` 并产生 `event_necrotic_source_secured`；Failure 造成更大的污染与毁坏。
- 未处理策略：`npc_or_escalate`。死灵集团可通过 `action_necrotic_collective_secure_source` 自行控制核心；无法行动时问题按既有恶化效果扩散。
- 可出现阶段：中期至晚期；污染达到25后解锁，不允许 Agenda 来源。

## 6. 捕获、研究与仪式合同

### 6.1 contract_collect_dragon_scales

- 名称：收集巨龙鳞片样本
- 战略目的：校准活捕仪式而不杀死巨龙。
- 阶段：reconnaissance → confrontation → salvage → extraction。
- 能力重点：offense、scouting、arcana、discipline。
- Mandatory：目标不得死亡；样本必须完整。
- Bonus：不造成额外聚落毁坏。
- 价值冲突：危险研究、成员安全与知识价值。
- 世界方向：提高 `capture_preparation` 和 `dragon_exhaustion`；失控时增加毁坏。
- 未处理策略：`npc_or_expire`。魔法工会可通过 `action_arcane_guild_collect_dragon_scales` 自行取得低质量样本；不可执行时机会自然消失。
- 可出现阶段：中期至晚期；巢穴定位后解锁，可使用 problem 或 Agenda 来源。

### 6.2 contract_deploy_binding_towers

- 名称：部署奥术束缚塔
- 战略目的：在关键节点建立活捕巨龙的束缚网络。
- 阶段：reconnaissance → confrontation → ritual → extraction。
- 能力重点：arcana、discipline、frontline、support。
- Mandatory：巨龙必须存活；必须使用校准束缚器；禁止死灵术。
- Bonus：行动保持隐蔽。
- 价值冲突：权威研究计划、非致命手段与高风险部署。
- 世界方向：大幅提高 `capture_preparation`，并可能提高 `dragon_exhaustion`；失败增加毁坏。
- 未处理策略：`npc_or_escalate`。魔法工会可通过 `action_arcane_guild_deploy_binding_towers` 以高 influence 代价部署部分塔；否则捕获窗口问题恶化。
- 可出现阶段：仅晚期；捕获准备达到60后解锁。Severe 中的 `target_killed` 映射为 `event_dragon_killed`。

### 6.3 contract_disrupt_necrotic_ritual

- 名称：破坏死灵转化仪式
- 战略目的：阻止尸体和龙血被转化为死灵灾害。
- 阶段：navigation → confrontation → ritual → extraction。
- 能力重点：offense、arcana、discipline、support。
- Mandatory：必须破坏仪式核心；不得带走污染材料。
- Bonus：取得施术者身份记录。
- 价值冲突：是否使用同类禁忌术式进行反制。
- 世界方向：降低 `necrotic_corruption`；失败触发大幅污染增长。
- 未处理策略：`escalate`。死灵转化推进并可能直接触发灾难结局。
- 可出现阶段：中期至晚期。

## 7. 高收益伦理合同

### 7.1 contract_recover_intact_corpses

- 名称：回收战场完整尸体
- 战略目的：把完整尸体和残留魔力交给死灵集团。
- 阶段：navigation → confrontation → salvage → extraction；ritual 只作为结果与手段标签，不增加第二个 check。
- 能力重点：arcana、support、discipline、scouting。
- Mandatory：至少交付三具完整尸体；不得暴露委托方。
- Bonus：回收高价值奥术残留。
- 价值冲突：高利润和知识收益对抗保护生命、宗教禁忌与权威合法性。
- 世界方向：最低也会增加 `necrotic_corruption`；成功只降低操作失控造成的额外污染。
- 未处理策略：`npc_or_escalate`。死灵集团可通过 `action_necrotic_collective_recover_corpses` 自行回收并造成更高污染；否则尸体问题自然恶化。
- 可出现阶段：问题来源为中期；Agenda 来源覆盖所有非结局阶段，表示回收本周战场产生的新尸体与奥术残留。

### 7.2 contract_prepare_dragon_bait

- 名称：以村庄物资设置巨龙诱饵
- 战略目的：把巨龙引向死灵集团选择的战场。
- 阶段：navigation → salvage → ritual → extraction；deception 作为实际手段标签。
- 能力重点：scouting、discipline、arcana、support。
- Mandatory：诱饵必须生效；不得暴露提出方。
- Bonus：避免直接平民死亡。
- 价值冲突：高报酬和战略操控对抗聚落财产与平民风险。
- 世界方向：可能提高 `dragon_exhaustion`，但增加 `settlement_destruction` 与 `necrotic_corruption`。
- 未处理策略：`npc_or_escalate`。死灵集团可通过 `action_necrotic_collective_prepare_dragon_bait` 采用更粗暴方案；不可执行时巨龙袭击压力恶化。
- 可出现阶段：中期至晚期。

## 8. 覆盖检查

| 设计维度 | 覆盖合同 |
|---|---|
| frontline | 石桥、防护撤离、束缚塔、反仪式 |
| offense | 石桥、鳞片样本、反仪式 |
| scouting | 道路侦察、巢穴、矿村、尸体回收 |
| support | 撤离、治疗队、矿村、尸体保存 |
| arcana | 巢穴、污染源、束缚塔、反仪式、尸体回收 |
| discipline | 全部高风险和时间条款合同 |
| Cautious 优势 | 撤离、巢穴、污染源、治疗队 |
| Aggressive 诱惑 | 石桥、鳞片、反仪式、诱饵 |
| target_state | 撤离、鳞片、束缚塔 |
| method | 束缚塔、污染源、尸体回收 |
| collateral | 撤离、石桥、诱饵 |
| secrecy | 巢穴、尸体回收、诱饵 |
| delivery | 治疗队、鳞片、尸体回收 |
| efficiency | 撤离、束缚塔、道路侦察 |
| personnel_safety | 治疗队、撤离、矿村 |

审计后十二份合同的主类型为：1份撤离、2份保护、1份救援、2份侦察、2份研究/采集、2份仪式和2份高收益伦理行动。至少三份合同明确存在“最高成功率不是显然最佳长期选择”的情况。

## 9. 内容任务类型

| 内容类型 | 合同 |
|---|---|
| 撤离 | 北路村民撤离 |
| 保护 | 石桥防线、战地治疗队 |
| 救援 | 矿村救援 |
| 侦察 | 东部道路、巨龙巢穴 |
| 研究/采集 | 污染源控制、鳞片样本 |
| 仪式 | 束缚塔、破坏死灵仪式 |
| 高收益伦理 | 尸体回收、巨龙诱饵 |

这些类型只用于内容目录、覆盖审计与界面筛选，不新增运行时 `TaskType`。实际四阶段仍使用既有 `check_type`，合同来源仍使用 `origin_type`。

## 10. 生成与解锁参数

表中四个数值依次为 `proposal_base_priority / urgency_weight / recent_repeat_cooldown / offer_duration_weeks`。

| contract ID | starts unlocked | repeat policy | 合法来源 | 阶段 | 解锁条件 | 参数 |
|---|---|---|---|---|---|---:|
| `contract_north_road_evacuation` | 否 | once | problem / followup | `phase_early_crisis`, `phase_open_conflict` | 安全路线事件 | 18 / 35 / 0 / 2 |
| `contract_hold_stone_bridge` | 否 | once | problem | `phase_open_conflict`, `phase_final_window` | 平民撤离问题 active | 17 / 35 / 0 / 2 |
| `contract_escort_field_healers` | 否 | repeatable | problem / agenda | 全部非结局阶段 | 医疗问题首次激活 | 14 / 30 / 2 / 2 |
| `contract_rescue_mining_village` | 否 | once | problem | `phase_early_crisis`, `phase_open_conflict` | 矿村问题 active | 17 / 35 / 0 / 2 |
| `contract_scout_eastern_road` | 是 | repeatable | problem / agenda | 全部非结局阶段 | fallback | 8 / 25 / 1 / 3 |
| `contract_locate_dragon_lair` | 是 | repeatable | problem / agenda | 全部非结局阶段 | fallback | 8 / 25 / 1 / 3 |
| `contract_investigate_necrotic_source` | 否 | once | problem | `phase_open_conflict`, `phase_final_window` | 污染达到25 | 18 / 35 / 0 / 2 |
| `contract_collect_dragon_scales` | 否 | repeatable | problem / agenda | `phase_open_conflict`, `phase_final_window` | 巢穴定位事件 | 15 / 30 / 2 / 2 |
| `contract_deploy_binding_towers` | 否 | repeatable | problem / followup | `phase_final_window` | 捕获准备达到60 | 20 / 40 / 1 / 2 |
| `contract_disrupt_necrotic_ritual` | 否 | repeatable | problem / followup | `phase_open_conflict`, `phase_final_window` | 污染问题 active | 20 / 40 / 1 / 2 |
| `contract_recover_intact_corpses` | 是 | repeatable | problem / agenda | 全部非结局阶段 | fallback | 8 / 25 / 1 / 2 |
| `contract_prepare_dragon_bait` | 否 | repeatable | problem / agenda | `phase_open_conflict`, `phase_final_window` | 进入中期 | 15 / 30 / 2 / 2 |

`once` 对应数据值 `once_per_campaign`。三个 fallback 的 target lock 不同，并且不因 repeat penalty 失去最终兜底资格。第1周固定只能由三个阵营分别选出道路侦察、定位巢穴和尸体回收三个 fallback；其他模板当时尚未解锁。

## 11. 代表性世界结果校准

以下数值固定“四个 check 全部得到 Success”与“四个 check 全部得到 Failure”时的净 campaign delta。三份基准合同的数值直接汇总自
`docs/10_baseline_contracts.md`；其余九份合同必须按
`docs/21_remaining_contract_numerical_rules.md` 拆分到逐阶段五档结果，本文的净值
不能作为 final outcome 再次应用。

缩写：`E` 撤离，`D` 毁坏，`X` 巨龙疲劳，`P` 捕获准备，`C` 死灵污染。

| contract ID | 全 Success 净变化 | 全 Failure 净变化 | Success 关键事件 |
|---|---|---|---|
| `contract_north_road_evacuation` | E+18, D+8, X+3 | E+3, D+30, C+6 | `event_north_road_evacuation_completed` |
| `contract_hold_stone_bridge` | E+12, D+4, X+10 | E+2, D+22, C+3 | `event_stone_bridge_secured` |
| `contract_escort_field_healers` | E+8, D+2, C-4 | E+2, D+14, C+8 | `event_field_healers_delivered` |
| `contract_rescue_mining_village` | E+14, D+4, C-2 | E+3, D+20, C+12 | `event_mining_village_rescued` |
| `contract_scout_eastern_road` | E+5, D+1 | D+10, C+2 | `event_eastern_route_secured` |
| `contract_locate_dragon_lair` | D+1, X+4, P+12 | D+12, X-2 | `event_dragon_lair_located` |
| `contract_investigate_necrotic_source` | D+2, C+8 | D+8, C+18 | `event_necrotic_source_secured` |
| `contract_collect_dragon_scales` | D+3, X+12, P+18 | D+18, X-4, P+2 | `event_binding_scales_calibrated` |
| `contract_deploy_binding_towers` | D+1, X+5, P+16 | D+19, P+2 | `event_binding_towers_operational` |
| `contract_disrupt_necrotic_ritual` | D+3, C-18 | D+10, C+22 | `event_necrotic_ritual_disrupted` |
| `contract_recover_intact_corpses` | D+1, C+7 | D+9, C+16 | `event_corpses_delivered` |
| `contract_prepare_dragon_bait` | D+10, X+14, C+10 | D+22, X+2, C+18 | `event_dragon_diverted` |

规则：

- `settlement_destruction` 和 `villagers_evacuated` 不得产生负向 delta。
- 尸体回收、污染源控制和巨龙诱饵即使成功也必须增加污染；技能只能减少额外失控，不能消除伦理代价。
- 束缚塔 Severe 的 `target_killed` 只在 final 阶段可达，并创建 `event_dragon_killed`；其四阶段累计毁坏不得低于30。
- 其他结果组合按四个 check 实际档位求和，不从这张表插值，也不把表中净值作为额外 final outcome 重复应用。
