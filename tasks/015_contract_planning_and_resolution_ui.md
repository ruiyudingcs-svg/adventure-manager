# Task 015 — Contract Planning and Resolution UI

状态：Completed
里程碑：Milestone 3（四屏可点击循环）
依赖：Task 004、009、011—014、Gate F

## Goal

完成玩家可操作的合同规划和只读结算流程。玩家必须能够比较三份 Offer、选择四名
成员、最多两项补给与 Approach，看到稳定预测和公开风险，确认一次不可撤销计划，
结束本周并阅读完整人员、财政、阵营与世界后果。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 5.3、7.5—8、10、13 节
- `docs/02_core_loop_and_rules.md` 第 4—8、10、12、14 节
- `docs/03_godot_architecture.md` 第 7—13、16 节
- `docs/04_data_model.md` Contract Offer/Plan/Resolution 与结果类型
- `docs/08_contract_clause_spec.md`
- `docs/12_contract_instantiation_and_commitment.md`
- `docs/14_week_flow_faction_commitments_and_messages.md`
- `docs/15_staged_contract_resolution_rules.md`
- `docs/22_campaign_bootstrap_forecast_and_ui_shell.md`
- Task 014 的真实 GameSession、Presenter 和 SceneRouter API

## Allowed files

- `game/features/contract_planning/**`
- `game/features/resolution/**`
- `game/features/shared/**`
- `game/ui/components/**`
- `game/domain/simulation/contract_forecast_service.gd`
- `game/app/game_session.gd`，仅接入 typed Offer/WeekFlow commands 和 review snapshot
- `game/app/scene_router.gd`，仅启用 Contracts/Resolution 路由
- Task 015 localization、fixtures、tests 与 `tests/run_all.gd`
- Gate F 或 UI 专项文档，仅在实现暴露明确矛盾时修改

不得修改 ContractResolver、ClauseEvaluator、AttitudeCalculator、Offer、Transaction、
WeekFlow 或 Gate A—E 公式。若现有公开 API 无法提供 Gate F 预测，先报告，不复制
公式到 UI。

## Required flow

### Planning draft

选择中的 Offer、成员、补给和 Approach 只存在于
`ContractPlanningController` 的临时 draft：

```text
offer_instance_id
selected_member_ids
selected_supply_ids
approach
content_signature
```

切换合同时重置不兼容选择；切换页面时可以保留本场景 draft，但不得写 CampaignState。
只有“确认派遣”调用一次正式 PlanContractCommand/accept_offer。成功后计划不可取消、
编辑或替换。

### Contracts screen

上下文选项卡：

1. Offers：三阵营合同卡、declined 占位、期限、报酬、风险和来源。
2. Details：目标、四阶段概要、Mandatory/Bonus 条款和公开方法。
3. Squad & Preparation：八人选择、最多两个补给、Approach。
4. Review：供应成本、预测区间、条款状态、成员态度与最多两个价值观警告。

拒绝使用现有 DeclineContractOfferCommand；每周额度、当周不补位和 disabled
占位全部读取成功后的 CampaignState，不在 View 中推断。

### ContractForecastService

严格实现 Gate F 第 5 节：

- 完整复用正式 Resolver。
- 64 个稳定样本 seed。
- 排除 locked resolution seed。
- 索引 6/57 的 likely tier 区间。
- 五档条款覆盖映射。
- 成员伤病只生成四档 ViewData。
- 不写状态、不消耗真实随机源、不保存预测。

预测失败返回 typed issues，Review 禁用确认并显示原因；不得退化为全零预测。

### GameSession commands

Task 015 增加：

```text
decline_offer(command)
accept_plan(command)
resolve_current_week(skip_contract)
acknowledge_resolution()
```

每个方法只在 Gate F 允许的阶段执行，只有 typed result 成功后才替换正式状态。

- `resolve_current_week(false)` 要求唯一 accepted Offer 和 active plan。
- `resolve_current_week(true)` 要求两者均不存在，并弹出二次确认。
- 成功 WeekResolution 缓存为 detached review snapshot，阶段变为 resolution_review。
- 重复点击、场景刷新或重入不得再次 resolve。
- acknowledge 只在 review 阶段打开下一周；已有 ending 则进入 ended。

### Resolution screen

上下文选项卡：

- Summary
- Four Phases
- Members
- Guild & World
- Reason Log

必须显示最终 tier、报酬、补给成本、四个 CheckResult、条款、疲劳、伤病、morale、
阵营关系、钟/问题/事件/阶段/结局变化和 player reason。debug reason 仅在明确的开发
开关中显示，默认不进入玩家日志。

所有内容读取缓存的 WeekResolution 和已提交 StateChange；不从新 CampaignState
反推差异。

### Top action

- 无 active plan：`结束本周`，确认 skip contract。
- 有 active plan：`派遣并结束本周`。
- review：`进入第 N+1 周`。
- ended：隐藏。

按钮禁用时必须显示 validation reason。用户输入错误不得触发 assert。

### Localization

补齐十二合同、37条条款、补给、Approach、tier、check type、结果、原因与四个结局
在 Planning/Resolution 中使用的简体中文文本。文案不得泄漏内部优先级、seed 或
不可见原因。

## Focused tests

至少覆盖：

1. draft 操作不改变 CampaignState。
2. 非四人、重复成员、不可用/拒绝成员、非法补给和超预算计划不提交。
3. accept 成功后不可取消、重选或接受第二份合同。
4. decline 每周一次、当周不补位且占位显示正确。
5. 相同 plan 的 ForecastViewData 完全一致，64 seed 均不等于 locked seed。
6. 改变成员、补给或 Approach 改变 signature，并按新 signature 稳定预测。
7. 条款五档映射和成员最多两个警告正确。
8. resolve 重复点击只提交一次；刷新 Resolution 不重投。
9. skip contract 与 accepted plan 互斥。
10. acknowledge 后只打开一次下一周；ending 进入 ended。
11. 结果 ViewData 与 WeekResolution/StateChange 一致，不从终态猜差异。
12. Planning/Resolution 场景 headless 实例化与完整点击 smoke 通过。

## Out of scope

- 取消已接受合同、修改已确认计划、多合同或多队并行
- 精确成功率、真实 seed 预览、可选/跳过 check
- 存档与加载
- 新规则、新内容、动画战斗或程序化文本

## Acceptance tests

先运行 forecast、planning command、GameSession week flow、Presenter 和 scene focused
tests，再运行完整 suite。随后在 Godot 4.7 手动完成至少两个连续周循环，其中一周
接合同、一周明确跳过合同。

## Completion checklist

- [x] 玩家可从三个 Offer 完成一次合法计划。
- [x] 预测遵守 Gate F 且不泄漏真实结果。
- [x] 正式状态只在 typed command 成功后替换。
- [x] Resolution 缓存一次且 UI 刷新不重投。
- [x] 四屏导航形成完整阅读—选择—结算—下一周循环。
- [x] focused/full suite 与两周手工流程实际完成。

完成说明：Required flow 的 Top action 必须在现有应用壳根节点连接，因此实现对
`game/app/app_root.gd` 做了仅限按钮绑定、跳过二次确认、路由与刷新操作的窄修改；
没有把领域公式或状态写入 UI。

## Expected report

- Planning draft、ForecastViewData 与 ResultViewData 字段
- 64样本稳定性和 locked seed 隔离证据
- accept/decline/skip/resolve/acknowledge 状态转换
- UI validation 与 localization 覆盖
- focused/full 测试和两周手工结果
