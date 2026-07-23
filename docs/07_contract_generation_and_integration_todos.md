# 合同生成与系统联动设计待办

状态：Draft  
建立日期：2026-07-17  
最近修订：2026-07-22

## 1. 使用规则

- 本文记录设计决策和剩余实现准备事项。
- 通用正式规则以文档 01 至 15 为准；巨龙入侵剧本内容值以文档 17 为准。
- 产品范围变化先改 01，规则改 02，架构改 03，字段改 04。
- 已完成 TODO 的旧方案若被简化修订覆盖，只保留当前结论，不同时保留两套规则。

## 2. 当前 V0.1 不变量

- 玩家经营独立公会，不在开局效忠单一阵营。
- 三个阵营各自最多持有一份 pending Offer，正常周开始形成三栏。
- 玩家每周最多接受一份合同并派遣一支四人队。
- 合同是有报酬和期限的行动方案，不等于世界问题。
- 合同使用 12 份手工模板，不程序拼装剧情。
- 每份合同固定四阶段、每阶段一个 check。
- 世界状态只参数化 check 难度和初始 MissionContext。
- 每个阵营每周只选择合同提案或直接行动之一。
- 规划器先补齐空合同栏，再安排直接行动；行动不能阻止同周三栏生成。
- NPC 行动通过精确 target lock 排他，不运行谈判、抢先或战斗冲突。
- 所有条款公开，任务后统一求值。
- 合同只直接结算提出方关系。
- 所有随机结算使用显式 seed；所有状态变化有结构化原因。
- 周末效果在临时状态合并、检查一批触发器后原子提交。

## 3. 已完成：世界问题与阵营意图

### [x] TODO 01：世界问题紧迫度

完成日期：2026-07-17

```text
urgency_score = base_urgency
              + clock_pressure
              + age_pressure
              + deadline_pressure
              + phase_pressure
```

紧迫度是 0 至 100 的确定性派生值，不保存为权威状态，不引用玩家队伍、金币或阵营关系。玩家看到等级、响应倒计时和最多两个原因。

### [x] TODO 02：FactionIntent

完成日期：2026-07-18；2026-07-20 简化修订。

合同和直接行动使用同一基础评分：

```text
intent_priority = base_priority
                + urgency_contribution
                + agenda_fit
                - repeat_penalty
```

不再使用 phase modifier、continuation bonus、mode bias 或选择 seed。完全同分按 Definition ID。

### [x] TODO 03：阵营每周行动容量

完成日期：2026-07-18；2026-07-20 简化修订。

- 没有 pending Offer：提出一份合同。
- 已有 pending Offer：保留合同并可执行一个不同 target lock 的直接行动。
- 同一阵营同周不再同时创建新 Offer 和新行动。

## 4. 已完成：条款与内容基准

### [x] TODO 03A：合同条款语法

正式规范：`docs/08_contract_clause_spec.md`。

- 七类 category 和 Mandatory/Bonus 保留。
- 所有条款公开，四个 check 后统一求值。
- 只支持 all_conditions。
- 条件缩减为计划、手段、标签、check tier、MissionContext 和重伤数量。
- 效果缩减为报酬百分比、提出方关系和 outcome tag。
- 封顶与 ideology impact 使用独立字段。

### [x] TODO 03B：12 份合同模板概要

正式目录：`docs/09_contract_template_catalog.md`。

仍保留 4 份撤离/保护、3 份侦察/路线、3 份捕获/研究/仪式、2 份高收益伦理合同。每个阵营必须有至少一个正常阶段可达的 repeatable Agenda fallback。

### [x] TODO 03C：3 份完整基准合同

正式定义：`docs/10_baseline_contracts.md`。

村民撤离、奥术束缚塔和完整尸体回收继续作为三类机制基准。所有阶段表固定为四行，每阶段一个 check；条款不再读取 pending 世界钟 delta。

## 5. 已完成：合同提案生成

正式规范：`docs/11_contract_proposal_generation.md`。

### [x] TODO 04：模板与世界问题匹配

继续使用问题到合同的显式白名单；problem、followup、agenda 三类来源保留。

### [x] TODO 05：候选表示

2026-07-20 修订：删除 `ContractProposalCandidate`。`FactionTurnPlanner` 在阵营内部使用临时候选并直接选择最高分定义，不建立第二套投影类型。

### [x] TODO 06：提案资格

保留阶段、问题、解锁、前置、互斥、声望、重复策略、pending 和 target lock 硬条件。只保存入选 Offer 的原因，不持久化所有被排除候选原因。

### [x] TODO 07：提案优先级

2026-07-20 修订为四项简式：base、urgency、agenda、repeat。Followup 通过手工 base priority 表达，不使用独立 continuation bonus。

### [x] TODO 08：三栏生成

2026-07-20 修订：三个阵营各自维护一个合同栏。不运行全局多样性、最高紧迫问题保障、Agenda 数量限制或补位算法。非结局阶段某阵营没有合法 fallback 时返回 `faction_offer_missing` 内容错误。

## 6. 已完成：合同实例化与占位

正式规范：`docs/12_contract_instantiation_and_commitment.md`。

### [x] TODO 09：世界状态绑定

实例化只允许修改 check 难度和初始 MissionContext。快照只保存最终 overlay 与原因，不保存源规则、读取事实、可选 check 或独立预测原因。

### [x] TODO 10：玩家拒绝

每周最多拒绝一份；当周不补位；下周优先避开同一实例组合一次，但无其他合法候选时允许重复。拒绝没有世界、关系或 influence 效果。

### [x] TODO 11：提出方承诺

pending Offer 直接占用提出方合同栏和精确 target lock。提出方下一周可以对其他目标直接行动；不允许撤回，不处理第三方提前完成。

## 7. 已完成：未处理合同

正式规范：`docs/13_unhandled_contract_and_npc_results.md`。

### [x] TODO 12：过期、NPC 完成和恶化

继续使用 `expire`、`npc_or_expire`、`npc_or_escalate`、`escalate` 四种固定策略。不存在随机选择和 npc_failed。

### [x] TODO 13：NPC 完成

NPC 完成复用提出方已有 FactionActionDefinition，不运行合同四阶段，不改变英雄或公会关系，也不占当周直接行动名额。

## 8. 已完成：周流程与消息

正式规范：`docs/14_week_flow_faction_commitments_and_messages.md`。

### [x] TODO 14：周流程

合同和行动读取同一快照，并在周末一个事务中提交。

### [x] TODO 14A：阵营行动排他

2026-07-20 修订：删除 objective group、stance relation、NPC faction relation 和 coexist/negotiation/race/clash。所有行动只使用精确 target lock；合同提案遍次先执行，随后在稳定阵营顺序下为行动选择目标，冲突 key 的后选者改选下一行动或等待。

### [x] TODO 15：消息与原因可见性

ReasonEntry 只保留 player 和 debug。删除 player_if_discovered、display priority 与情报 ID。Offer 显示一条来源和最多两条 player 原因；消息仍由 WeeklyMessageProjector 稳定去重。

## 9. 已完成：分阶段结算

正式规范：`docs/15_staged_contract_resolution_rules.md`。

### [x] TODO 16：MissionContext

十个指标统一为默认 0、范围 0 至 10；同 check 同 key delta 先合并后裁剪。

### [x] TODO 17：Approach

check 只声明 careful、forceful 或 neutral，数值使用一张全局表，合同级效果只应用一次。

### [x] TODO 18：条款边界

所有公开条款各求值一次；效果叠加；报酬百分比合计限制 -100% 至 +100%。

### [x] TODO 19：任务后价值观

使用实际 CheckOutcome、条款和去重 method tags。V0.1 删除 departure strikes 和永久离队；Opposed 且 morale 不高于 20 的成员拒绝派遣。

### [x] TODO 20：阵营反馈

2026-07-20 修订：删除 FactionReactionRule。只计算提出方的最终等级基础关系与条款关系，单合同裁剪到 -20 至 +20。

### [x] TODO 21：效果合并

数值先求和后裁剪，集合稳定去重，矛盾状态使事务失败。触发器在临时状态上每个周边界只检查一批，不递归；最终验证成功后原子提交。

### [x] TODO 21A：V0.1 复杂度削减

完成日期：2026-07-20。

已删除或推迟：

- 全局合同栏二次筛选与多样性算法。
- NPC 多模式冲突。
- 每阶段多个或可选 check。
- 非公开条款和条件发现原因。
- 跨阵营合同反应。
- 永久离队。
- 递归触发器。
- 为每个小步骤建立独立顶层服务。

## 10. V0.1 前置组：巨龙入侵剧本内容闭环

正式计划：`docs/16_dragon_invasion_scenario_content_plan.md`。

本组属于 V0.1 验收，现已在 TODO 22 实现任务拆分前完成。现有 TODO 03B 只代表最初十二份合同概要完成；最终内容以文档17、18和修订后的合同目录为准。

### [x] TODO 21B：局势阶段与结局骨架

确定初始事实、早中晚阶段、四个结局的世界状态、精确触发方向和同周多结局优先级。巨龙死亡使用事件或 outcome tag，不把 `dragon_exhaustion` 当作生命值。

已完成：见 `docs/17_dragon_invasion_scenario_spec.md` 第 2—4 节。

### [x] TODO 21C：三个阵营目标树

为每个阵营定义一个最终目标、成功与受阻条件、3 至 5 个小目标，以及它们与钟、问题、合同和直接行动的关系。

已完成：见 `docs/17_dragon_invasion_scenario_spec.md` 第 5 节。

### [x] TODO 21D：五条进度钟完整规格

确定每条钟的语义、初值、被动变化、生产者、抑制者、关键阈值、可见解释以及阶段、问题和结局用途。

已完成：见 `docs/17_dragon_invasion_scenario_spec.md` 第 6 节。

### [x] TODO 21E：世界问题图

把九个问题锚点补成完整 WorldProblemDefinition，固定激活、紧迫度、期限、解决、恶化、事件和后续解锁。

已完成：见 `docs/18_dragon_invasion_problem_and_action_catalog.md` 第 2—4 节。

### [x] TODO 21F：阵营直接行动目录

补齐三个阵营的 weekly_action_table，覆盖所有非结局阶段，并完成目标、问题、target lock、influence、效果和合同复用关系。

已完成：见 `docs/18_dragon_invasion_problem_and_action_catalog.md` 第 5—9 节。

### [x] TODO 21G：十二份合同覆盖审计与内容定案

先固定撤离、保护、救援、侦察、研究/采集、仪式和高收益伦理行动等内容任务类型，再按目标树、钟、问题和行动回查十二份合同；允许调整现有模板的提出方、来源、阶段、锚点、解锁、后果和未处理策略，默认不增加模板数量。任务类型只是内容分类，不新增运行时任务类型系统。

已完成：合同目录见 `docs/09_contract_template_catalog.md`，覆盖审计与路径校准见 `docs/18_dragon_invasion_problem_and_action_catalog.md` 第 10—12 节。

整组完成标准：三个阵营的目标链、五条钟、九个问题、直接行动、十二份合同和四个结局可以从同一开局形成 10 至 15 周的完整可达闭环。

## 11. 延后项：不属于 V0.1 验收

### [ ] TODO V02-01：同一世界问题的多阵营行动交互

V0.1 只用精确 `target_lock_key` 排他：相同 key 的后选者改选或等待，不运行冲突结算；不同 key 即使属于同一世界问题也可以同时推进。

后续版本若验证确有表现价值，再根据目标类型、阵营立场和 NPC 阵营关系，把同一问题上的并发行动归入谈判、一方抢先或战斗等少量固定结算模式。该项不得在 V0.1 中提前引入 objective group、stance matrix、NPC 外交状态或通用冲突框架。

## 12. 实现任务与测试

### [ ] TODO 22：拆分实现任务

按七个主要服务拆分：

1. `WeekFlowCoordinator`
2. `WeeklyUpkeepResolver`
3. `SituationResolver`
4. `FactionTurnPlanner`
5. `ContractOfferService`
6. `ContractResolver`
7. `WeeklyMessageProjector`

条款、任务后成员评价和提出方关系是 ContractResolver 内的纯计算组件，不单独成为顶层服务。预测是 ContractOfferService 的纯查询。

完成标准：每项任务只跨一个主要服务并包含确定性测试，不恢复已删除的 V0.2 抽象。

### [ ] TODO 23：集成测试矩阵

至少覆盖：

- 三个阵营各自最多一份 pending Offer。
- 无 pending 时只提案，有 pending 时只直接行动。
- 合同提案遍次先于直接行动遍次，直接行动不能阻止空栏补齐。
- 同一状态稳定选择相同合同和行动。
- target lock 在 Offer 与行动间全局唯一。
- 每份合同恰好四个阶段、每阶段一个 check。
- 世界状态只绑定难度与初始 MissionContext。
- pending、declined、accepted、resolved、expired、npc_completed、escalated 状态互斥。
- Offer 快照、报酬、期限和 seed 在存档往返后不变。
- 条款全部公开并只读取白名单 trace 数据。
- Opposed 低士气成员拒绝派遣，不存在永久离队。
- 合同只改变提出方关系。
- 合同与阵营行动整批提交或整批拒绝。
- 每个周边界只执行一批触发器。
- 10 至 15 周模拟中每个阵营都能持续产生合法 fallback Offer。

## 13. 推荐顺序

```text
TODO 01 至 21A 设计规则（已完成）
→ TODO 21B 至 21G 巨龙入侵剧本内容闭环
→ TODO 22 实现任务拆分
→ TODO 23 集成测试矩阵
```
