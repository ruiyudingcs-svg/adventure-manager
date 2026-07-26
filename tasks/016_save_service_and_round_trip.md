# Task 016 — SaveService, Versioning and Round Trip

状态：Completed
里程碑：Milestone 5（存档、平衡与可测试构建）
依赖：Task 011、014—015、Gate F

## Goal

实现一个可审计、带版本、原子写入的 V0.1 JSON 存档。玩家可以在任意 planning
阶段保存和加载，包括 pending Offer、拒绝额度、已接受计划与 NPC 行动承诺；加载
不得改变任何锁定 seed、快照、预测输入或下次正式结算。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 4、5、13 节
- `docs/03_godot_architecture.md` 第 4.5、6、14—16 节
- `docs/04_data_model.md` 全部 CampaignState 与嵌套 State
- `docs/12_contract_instantiation_and_commitment.md`
- `docs/14_week_flow_faction_commitments_and_messages.md`
- `docs/19_content_catalog_state_and_situation_rules.md`
- `docs/22_campaign_bootstrap_forecast_and_ui_shell.md` 第 4—5 节
- Task 014—015 的真实 GameSession 与 planning/review 边界

## Allowed files

- `game/persistence/**`
- `game/app/game_session.gd`，仅委托 SaveService 并原子发布加载结果
- `game/features/shared/**`、`game/ui/components/**`，仅保存/加载对话与反馈
- `project.godot`，仅配置存档相关但不新增 Autoload
- Task 016 localization、fixtures、tests 与 `tests/run_all.gd`
- `docs/03_godot_architecture.md`、`docs/04_data_model.md`，仅同步最终 schema/version

不得修改领域公式、Catalog 内容、CampaignState 业务字段或 Autoload 列表。若现有
State 缺少序列化 getter，应只增加只读复制/投影 API，不开放任意字段写入。

## Save envelope

正式格式为 UTF-8 JSON：

```text
format = "adventure_manager_campaign"
save_version = 1
campaign_setup_id
saved_at_unix_seconds
campaign_state
```

`saved_at_unix_seconds` 只作文件元数据，不进入 CampaignState、seed、预测、排序或
任何模拟。JSON object key 使用稳定书写顺序；数组保留各自权威顺序。

CampaignState DTO 必须完整保存：

- campaign seed、week 和 Guild
- 八名 AdventurerState 与关系 delta/近期计数
- 三名 FactionState
- SituationState、九问题和 ending
- world events、contract history
- pending/accepted/declined Offer 的全部锁定字段与实例化快照
- active plan、declined_offer_week
- faction action commitments
- message history 与 is_read

静态 Definition 只保存稳定 ID，不复制 `.tres` 数值。ProblemUrgencyResult、
ForecastViewData、Presenter cache、WeekOpeningResult、WeekResolution review snapshot
均不保存。

## SaveService

SaveService 是普通 `RefCounted` 服务，由 GameSession 持有，不注册 Autoload。

公开 API：

```text
save_planning_state(path, setup_id, campaign_state) -> SaveResult
load_planning_state(path, data_catalog) -> LoadResult
inspect_save(path) -> SaveMetadataResult
```

只允许 GameSession phase 为 planning 时保存。resolution_review、no_campaign 和
ended 的保存请求返回玩家可见 issue；不得写半结算结果。

## Atomic write and recovery

1. 序列化到同目录临时文件。
2. flush/close。
3. 重新读取临时文件并走完整 parse/schema/state 验证。
4. 若正式文件存在，重命名为 `.bak`。
5. 临时文件重命名为正式文件。
6. 成功后删除 `.bak`；替换失败则恢复 `.bak`。

加载优先读取正式文件；正式文件损坏而 `.bak` 合法时可以返回 recovery candidate，
但必须由玩家确认后才发布，不静默覆盖。

## Load validation

顺序固定为：

1. 文件存在、UTF-8 与 JSON 根类型。
2. format 精确匹配。
3. save_version：1 接受，未知未来版本拒绝；V0.1 不伪造空迁移。
4. CampaignSetupDefinition 存在。
5. DTO 字段类型、必需字段、稳定 ID 和数值范围。
6. 所有 Definition ID 在 DataCatalog 中存在且属于 setup 闭包。
7. 构造全新的 CampaignState 并运行完整 validate。
8. 重新派生问题紧迫度、remaining turns 和所有 Presenter 数据。
9. 全部成功后 GameSession 一次性替换正式状态并进入 planning。

加载失败必须保留当前会话。错误包含文件、JSON path/field 和原因，不输出完整存档
内容或吞掉异常。

## Round-trip equivalence

保存前后比较 canonical content signature。对已接受 plan 还必须：

1. 从保存前 state 复制并正式 resolve。
2. 从加载后 state 使用同一 detached definitions 正式 resolve。
3. 比较 WeekResolution、ContractResolution、StateChange、ReasonEntry、消息和最终
   CampaignState signature。

两者必须完全一致。不得通过重新生成 Offer、重算实例化快照或替换 locked seed
使测试通过。

## UI

V0.1 只提供一个正式存档位：

- 顶部工具栏 `保存`
- 开始页 `继续游戏`
- `新游戏` 覆盖已有存档前确认
- 明确的保存成功、无存档、损坏、版本不兼容和恢复候选提示

不实现云存档、多槽、缩略图、存档重命名或用户账号。

## Focused tests

至少覆盖：

1. 空 planning、第 1 周和中期 planning 往返。
2. 三 pending Offer、declined 占位/额度、accepted plan 分别往返。
3. committed/resolved action、消息已读、历史、问题和世界事件往返。
4. relationship dictionary、Reason parameters、MissionContext 和嵌套数组深复制。
5. 未知版本、缺字段、错类型、非法 ID、缺 Definition 和非法状态拒绝。
6. 加载失败不替换当前 GameSession。
7. 临时文件验证失败不覆盖正式文件；合法 `.bak` 可作为恢复候选。
8. planning 以外阶段禁止保存。
9. accepted plan 保存前后 WeekResolution 全 signature 相同。
10. 相同状态两次序列化除 saved_at 元数据外 canonical state JSON 相同。

## Out of scope

- 云存档、多槽、自动同步、压缩、加密
- 任意未来版本迁移框架
- 保存 Resolution review snapshot、Forecast 或 Presenter cache
- 改变存档后世界结果的兼容修复

## Acceptance tests

先运行 codec、schema、文件原子性、GameSession 和 round-trip focused tests，再运行完整
suite。随后在实际 Godot 构建中手动执行：新游戏→保存→退出→继续→确认状态→结算。

## Completion checklist

- [x] JSON schema 与 save_version 1 明确且完整。
- [x] SaveService 不是 Autoload。
- [x] 只在 planning 保存，不存在半结算存档。
- [x] 原子写入、备份恢复和加载失败保留会话。
- [x] accepted plan 往返后正式结果完全一致。
- [x] focused/full suite 与手工退出重载流程实际完成。

验证记录：2026-07-25 用户已手工确认新游戏→保存→退出→继续与状态恢复正确；
首次继续后的第二周结算暴露 ResolutionPresenter 访问 ActionDefinition 非 schema
字段的问题，现已改为按稳定 action ID 派生标题键并增加回归测试。聚焦测试
`3 passed, 0 failed`，完整 Godot 4.7 headless suite 为
`Summary: 216 passed, 0 failed`。退出时仍有既有 ObjectDB/Resource 清理警告；
修复后的实际 UI 第二周结算已由用户确认通过。

## Expected report

- JSON envelope、字段清单和 canonical signature
- 原子替换与 `.bak` 恢复行为
- Definition 闭包和版本验证
- accepted plan 往返等价证据
- focused/full 测试与手工流程结果
