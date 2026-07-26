# Task 012 — Weekly Message Projection

状态：Completed（2026-07-24）
里程碑：Milestone 3（可解释周结果）
依赖：Task 009—011

## Goal

实现 MessageRequest、MessageState 和 WeeklyMessageProjector，把已经成功提交的
Offer、维护、行动、世界事件、合同历史和周结果投影为稳定、可去重的消息。
消息只解释既有事实，不参与规则求值，也不能使失败事务产生可见历史。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 5.3、10 节
- `docs/02_core_loop_and_rules.md` 第 10.5、14 节
- `docs/03_godot_architecture.md` 第 7—11、13 节
- `docs/04_data_model.md` 第 3.11—3.12、4.1—4.2 节
- `docs/11_contract_proposal_generation.md` 第 8 节
- `docs/13_unhandled_contract_and_npc_results.md` 第 7 节
- `docs/14_week_flow_faction_commitments_and_messages.md` 第 7—10 节
- Task 009—011 的实际 typed result 和 StateChange API

## Allowed files

- `game/domain/messages/message_request.gd`
- `game/domain/messages/message_state.gd`
- `game/domain/simulation/weekly_message_projector.gd`
- `game/domain/campaign/campaign_state.gd`
- `game/domain/simulation/campaign_transaction.gd`
- `game/domain/simulation/week_flow_coordinator.gd`，仅集成提交后消息投影
- `game/domain/simulation/contract_offer_service.gd`，仅集成拒绝消息投影
- Task 009—011 result types，仅允许增加 MessageRequest 输出
- Task 012 对应 tests/fixtures 和 `tests/run_all.gd`

不得修改游戏公式、重新运行 Resolver、创建 UI 或实现 SaveService。

## Required state and values

CampaignState 增加：

```text
message_history: Array[MessageState]
```

MessageRequest 和 MessageState 严格使用 `docs/04` 第 3.12 节。两者必须：

- 对 parameters 做深复制。
- 验证 category、importance、source 和稳定 ID。
- 提供稳定 signature。
- 不保存 Node、Resource、StateChange 对象或任意可执行文本。

category 白名单：

```text
upkeep
world_event
contract_offer
contract_lifecycle
faction_action
contract_result
week_summary
```

importance 白名单：`low`、`normal`、`high`、`critical`。

## Ownership rule

只有 WeeklyMessageProjector 创建 MessageState。其他服务可以返回
MessageRequest，但不得：

- append message_history
- 计算 message instance ID
- 根据消息反向改变 State
- 把 UI 文案当成 reason 或 rule

Projector 只能在 WeekOpeningResult、WeekResolution 或玩家命令的领域事务已经
成功产生预览 new_state 后运行。输入 result 没有成功 new_state 时必须拒绝投影；
调用方只有在消息事务也成功后才能发布最终 CampaignState，避免领域状态已替换但
消息失败的半提交。

## Stable identity and ordering

```text
message_instance_id = stable instance ID of:
    week_index, source_type, source_id, category
```

同一组合只允许一条。若既有同 ID 消息内容相同，投影为确定性 no-op；同 ID 内容
不同是错误并拒绝整批消息。

同一周消息按以下键稳定排序并分配连续 `sort_order`：

1. request.trace_order 升序
2. category 固定顺序：upkeep、world_event、contract_offer、
   contract_lifecycle、faction_action、contract_result、week_summary
3. source_type 升序
4. source_id 升序
5. title_key 升序

Projector 不依赖输入数组顺序。既有历史不重排；新消息的 sort_order 从该周已有
最大值加一开始。

## Projection policy

### Week opening

- 工资/维护、恢复和成员警告。
- passive、问题期限、旧 Offer 终止和世界事件。
- 新 Offer 到达。
- 本周 committed action 预告。
- 周开始摘要。

### Player commands

- Offer declined。
- 计划确认失败只返回即时 command issue，不写持久消息；成功计划也不额外制造
  一条无事实变化消息。

### Week end

- 玩家合同结果，包含 final tier、reward、supply cost 和主要成员后果。
- 每个 resolved faction action。
- 世界事件、问题、phase 和 ending 变化。
- 周总结。

### Visibility and reason selection

- 只把 `visibility = player` 的 ReasonEntry 写入 parameters。
- debug reasons 不进入玩家消息文本参数，但保留在 source result。
- 每份 Offer 固定一条来源说明，最多选择两条 player 原因。
- 选择规则为原始 trace/source order，再按 reason code；不得按 amount 重新评分。
- urgency 消息只展示 band、remaining turns 和最多两个公开原因，不展示精确 AI
  priority 或被排除候选。

## Public API

```text
project_requests(base_state, committed_result, requests)
    -> MessageProjectionResult

mark_read(base_state, message_id)
    -> MessageProjectionResult
```

Result 包含 operations、created messages、state changes/new state 或 issues。
消息通过 CampaignTransaction 的 `append_record` 白名单写入；mark_read 使用显式
message target/field dispatch，不直接修改对象。

Task 012 必须窄幅集成 WeekFlowCoordinator 和 Offer command result，使它们返回的
最终 new_state 已包含消息；不得先替换无消息状态再尝试第二次外部提交。

## Focused tests

至少覆盖：

1. 同一 requests 的所有排列产生相同 ID、顺序、sort_order 和 parameters。
2. 同一成功 result 重试不重复追加消息。
3. 同 ID 同内容 no-op；同 ID 不同内容整批失败。
4. 失败/无 new_state 的事务不能产生消息。
5. Offer 来源 + 最多两条 player reason；debug 不泄漏。
6. 周开始、拒绝、合同结果、行动、事件、结局和周总结类别覆盖。
7. mark_read 只改变目标消息且有 StateChange/reason。
8. parameters、ReasonEntry、MessageRequest 和 MessageState 不共享可变 Dictionary。
9. 消息投影不改变金币、成员、阵营、Offer、问题、钟或结局。
10. 存在既有同周消息时只为新消息追加连续 sort_order。

## Out of scope

- 本地化文本内容和 UI 排版
- 邮箱筛选、删除、分页或通知动画
- 世界规则、合同公式、候选评分
- SaveService JSON

## Acceptance tests

先运行 Task 012 focused/integration tests，再运行完整 suite。

## Completion checklist

- [x] MessageState 只有 Projector 可以创建。
- [x] 消息只投影成功提交的既有事实。
- [x] 稳定 ID、排序、去重和冲突规则完整。
- [x] player/debug 可见性没有泄漏。
- [x] 消息投影不改变其他领域状态。
- [x] focused/full suite 实际运行。

## Expected report

- MessageRequest/MessageState schema 和公开 API
- 各时机的消息来源映射
- 稳定排序、去重和可见性证据
- CampaignState/Transaction 扩展
- focused/full 测试结果
