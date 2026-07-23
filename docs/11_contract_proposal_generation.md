# 合同提案生成规范 V0.1

状态：Accepted（简化修订）  
日期：2026-07-20

## 1. 目的与核心决定

V0.1 不运行全局合同候选池的二次筛选。三个阵营各自负责一个合同栏，每个阵营最多保留一份 `pending` Offer：

```text
阵营没有 pending Offer
→ 本周从自己的合法合同中提出一份最高优先级合同

阵营已有 pending Offer
→ 保留该 Offer，本周不再提出新合同
```

因此结构上每阵营最多一份 pending 合同；在非结局阶段且内容目录合法时，正常周开始恰好形成三栏。每个阵营都必须有一个合法 fallback Agenda 模板，保证自己的空栏能够恢复。玩家在规划阶段拒绝合同后，当周仍保留空栏，下一周由同一阵营重新提出。

V0.1 明确不使用：

- 不创建 `ContractProposalCandidate` 二次投影。
- 同问题或同提出方多样性惩罚。
- 最高紧迫问题强制入口。
- Agenda 数量配额或全局补位算法。
- `continuation_bonus`、`proposal_mode_bias` 和选择随机种子。

## 2. 提案来源

合同来源仍固定为：

- `problem`：响应 active 世界问题。
- `followup`：由已完成合同、世界事件或局势规则解锁。
- `agenda`：阵营在没有合适问题锚点时推进自身公开目标。

问题来源继续使用 `WorldProblemDefinition.contract_definition_ids` 显式白名单，不按标签自动拼装合同。`allow_agenda_origin = true` 的手工模板可以作为 Agenda 来源。Followup 与 Agenda Offer 的运行时 `related_problem_id` 为空，但仍使用完整阶段、条款、结果表和世界后果。

同一手工模板在同一周只产生一个来源候选，来源优先级固定为 `problem > followup > agenda`，避免复制相同任务。

## 3. 阵营本周模式

每个阵营在规划快照上只选择一种模式：

| 当前状态 | 本周模式 |
|---|---|
| 已有 pending Offer | `direct_action` |
| 没有 pending Offer | `contract_proposal` |

提出合同本身就是阵营本周的主要决定，因此同一阵营不会在同周同时创建新 Offer 和直接行动承诺。pending Offer 期间，阵营可以对其他目标执行直接行动，但不得使用任何 pending Offer 已占用的 `target_lock_key`。

## 4. 合同资格

阵营只在自己的 ContractDefinition 中选择候选。候选必须依次通过：

1. Campaign 尚未进入结局。
2. `sponsor_faction_id` 等于当前阵营。
3. 合同定义、四阶段、四个 check、条款和结果表引用合法。
4. 当前局势阶段允许该合同。
5. problem 来源的问题仍为 active，且问题白名单包含该合同。
6. 合同已初始开放或已经解锁。
7. 前置合同已经完成，互斥合同尚未完成。
8. 公会声望达到最低值。
9. `once_per_campaign` 合同尚未完成。
10. 当前没有相同合同实例组合处于一次性拒绝抑制；若该项会使本阵营无合法合同，则允许该组合作为兜底并记录 `declined_offer_reused_no_alternative`。
11. `target_lock_key` 未被任何 pending Offer 或本次合同提案遍次中先选出的新 Offer 占用。
12. Agenda 来源满足 `allow_agenda_origin`，且模板可重复。

不读取当前队伍能力、成员伤病、玩家金币、补给或阵营关系来迎合玩家。阵营关系只在 Offer 创建时修改期限和报酬。

资格失败只产生 debug 原因。只有最终入选合同的资格与评分原因进入 Offer 历史。

## 5. 简化优先级

```text
proposal_priority = proposal_base_priority
                  + urgency_contribution
                  + agenda_fit
                  - repeat_penalty
```

| 项 | 范围 |
|---|---:|
| proposal_base_priority | 0..20 |
| urgency_contribution | 0..40 |
| agenda_fit | -30..30 |
| repeat_penalty | 0..20 |

规则：

- problem 来源读取问题紧迫度；followup 和 agenda 的 `urgency_contribution = 0`。
- `agenda_fit` 来自提出方的静态 Agenda tag 权重。
- repeat penalty 只用于 `repeatable` 模板；冷却期内线性降低，最大 20。
- 最终分数必须大于 0。
- 排序依次使用 `proposal_priority` 降序、`proposal_base_priority` 降序、ContractDefinition ID 升序。
- 不使用随机数解决提案排序；相同状态始终选择同一模板。

followup 若需要优先展示，直接在手工 ContractDefinition 中设置更高的 `proposal_base_priority`，不增加独立 continuation 公式。

## 6. Offer 创建

阵营最高优先级候选通过 `ContractOfferService` 创建 `ContractOfferState`，并一次性锁定：

- 合同与提出方。
- 来源类型和关联问题。
- target lock。
- Offered week 与 expires week。
- 关系修正后的报酬和有效期。
- ContractInstantiationSnapshot。
- 合同结算 seed。
- 入选原因。

```text
offer_instance_id = stable_id(
    offered_week,
    faction_id,
    contract_definition_id,
    origin_type,
    related_problem_id,
    target_lock_key
)

resolution_seed = hash(campaign_seed, offer_instance_id, "contract_resolution")
```

Offer 创建后不因世界钟、问题状态或阵营关系变化重新排序、取消或重算。完整实例化规则见 `docs/12_contract_instantiation_and_commitment.md`。

## 7. 三栏与拒绝

- 每个阵营最多一份 pending Offer，因此不需要同提出方多样性算法。
- 不限制多个阵营响应同一个世界问题；不同阵营可以提出立场不同但 target lock 不同的合同。
- 同一精确 target lock 只能有一个 pending Offer。
- 正常周开始时每个阵营补充自己的空栏。
- 全部空栏补齐后才选择直接行动，因此行动不会阻止本周合同生成。
- 玩家每周最多拒绝一份；拒绝后当周不补位。
- 下一周该阵营重新选择，原实例组合优先排除一次；没有其他合法合同时允许重复，不能因此留下空栏。

如果某阵营在非结局阶段没有任何合法合同，返回 `faction_offer_missing` Catalog 错误。该错误只表示该阵营的手工内容覆盖不足，不触发全局 Agenda 补位或生成无效任务。

## 8. 玩家可见原因

每份 Offer 显示：

1. 一条来源说明：问题、后续或 Agenda。
2. 最多两条 `visibility = player` 的入选原因。
3. 提出方、剩余回合、锁定报酬和关联问题。

精确评分、被排除候选和 ContractDefinition ID 排序只用于 debug，不存入玩家消息。ReasonEntry 不支持条件发现层级。

## 9. 验证与测试

CatalogValidator 必须检查：

- 每个非结局阶段，每个阵营至少有一个可达、可重复、正 Agenda 匹配的 fallback 合同。
- 三个 fallback 合同使用互不相同的 target lock。
- 问题白名单与合同 `related_problem_id` 双向一致。
- 合同提出方、来源、目标锁、前置、互斥、声望与重复策略合法。
- 三个阵营不会同时持有相同 target lock 的 pending Offer。
- 不存在 `ContractProposalCandidate`、多样性分或 Agenda 补位配置。

确定性测试至少覆盖：

- 无 pending 的阵营只创建一份最高分 Offer。
- 有 pending 的阵营保留旧 Offer 且不创建新 Offer。
- 阵营按稳定 faction ID 顺序共享 target lock 集合；相同输入得到相同分配结果。
- 合同提案遍次完成后才安排直接行动，行动不能改变本周 Offer 选择。
- 同分按稳定 ContractDefinition ID 选择。
- 拒绝后当周空栏；下一周有替代候选时避开原组合，无替代候选时确定性复用并记录原因。
- 相同 CampaignState 生成相同 Offer ID、报酬、期限、seed 和原因顺序。
