# Task 014 — GameSession, Dashboard and Roster

状态：Completed
里程碑：Milestone 3（四屏可点击循环）
依赖：Task 011—013、Gate F

## Goal

建立 V0.1 的唯一会话所有者和 Football Manager 风格应用外壳，并完成两个只读信息
界面：Dashboard 与 Roster。玩家启动新战役后必须看到真实第 1 周局势、三个阵营
合同栏、NPC 行动预告、信箱和八名成员，而不是静态占位文本。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 第 4—6、10、13 节
- `docs/02_core_loop_and_rules.md` 第 2、10、12—14 节
- `docs/03_godot_architecture.md` 第 4、6—11、16 节
- `docs/04_data_model.md` 全部静态/运行时状态与 ViewData 相关章节
- `docs/14_week_flow_faction_commitments_and_messages.md`
- `docs/17_dragon_invasion_scenario_spec.md`
- `docs/18_dragon_invasion_problem_and_action_catalog.md`
- `docs/19_content_catalog_state_and_situation_rules.md`
- `docs/22_campaign_bootstrap_forecast_and_ui_shell.md`
- Task 011—013 的真实 DataCatalog、WeekFlow、Message 和内容 API

## Allowed files

- `game/app/**`
- `game/features/dashboard/**`
- `game/features/roster/**`
- `game/features/shared/**`
- `game/ui/components/**`、`game/ui/theme/**`
- CampaignSetupDefinition、FactionSetupDefinition 的 runtime/authoring 类型与唯一 `.tres`
- `ContentManifest`、`CatalogValidator`、`DataCatalog`，仅接入 setup 类型
- `game/domain/simulation/campaign_bootstrapper.gd`
- `project.godot`，仅注册 `GameSession` 与 `SceneRouter` 和本地化资源
- Task 014 localization、fixtures、tests 与 `tests/run_all.gd`
- 本任务与 Gate F 直接相关文档

不得修改合同、维护、阵营、局势、消息或 WeekFlow 公式。Bootstrapper 只能组合现有
公开 API；不得为第 1 周复制 Planner 或 Offer 逻辑。

## Required implementation

### Campaign setup publication

- 正式 manifest 恰好发布一个 Gate F CampaignSetupDefinition。
- setup 的八名成员、三个阵营、一个 Situation 和三个开局问题引用全部闭合。
- DataCatalog 提供 detached `get_campaign_setup(id)` 与稳定 `get_all_campaign_setups()`。
- Catalog 加载失败继续保持原子发布语义。

### CampaignBootstrapper

实现 Gate F 第 3 节精确构造顺序：

- 显式 seed。
- 内部 week 0 CampaignState。
- setup 的 Guild、成员、阵营和 Situation 初值。
- 九问题完整状态，三项 active deadline 正确。
- starts_unlocked 合同稳定集合。
- 调用真实 WeekFlowCoordinator 打开第 1 周。

返回 typed result，包含 detached new state、opening result 或 issues。任何错误不得返回
部分 CampaignState。

### GameSession

注册为第二个 Autoload，负责：

- `start_new_campaign(setup_id, campaign_seed)`
- 持有唯一正式 CampaignState
- 返回 detached `get_campaign_snapshot()`
- 暴露 `no_campaign`、`planning`、`resolution_review`、`ended` 阶段
- 调用 WeeklyMessageProjector 的正式 mark_read 命令并仅在成功后替换状态
- 保存最近一次可显示错误，但不打印领域公式或吞掉 typed issues

Task 014 不实现接受/拒绝 Offer、结束本周、保存或加载。不要为后续任务创建空方法。

GameSession signal 只允许会话替换、消息已读和错误通知；signal 不承载多步业务流程。

### SceneRouter and app shell

注册第三个也是最后一个 V0.1 Autoload。路由白名单：

```text
dashboard
contracts
roster
resolution
```

Task 014 实装 Dashboard 与 Roster；Contracts、Resolution 使用明确的未完成占位屏，
Resolution 在无 review snapshot 时禁用。Router 每次只在 ScreenContainer 挂载一个
主要 Feature scene，不保存 CampaignState。

`app_root.tscn` 改为：

```text
AppRoot
├── Background
├── AppShell
│   ├── Sidebar
│   ├── TopToolbar
│   └── ScreenContainer
└── ModalLayer
```

Sidebar、顶部状态和页面标题来自共享 ViewData。最低视口 1280×720；较大视口只扩展
内容，不增加新的信息层级。

### Dashboard

上下文选项卡固定为：

- Overview：周、Guild、局势阶段、五条钟摘要、待处理警报和三合同摘要。
- Problems：active 问题、紧迫度 band、剩余响应回合、最多两个 player reason。
- Inbox：消息稳定排序、重要度、已读状态和详情；点击后调用 GameSession mark_read。

显示 committed NPC action 的阵营、行动标题、目标与公开原因，不显示 priority 分数、
被排除候选或内部补足原因。

### Roster

上下文选项卡固定为：

- Members
- Relationships
- Recent Records

左侧稳定成员列表，右侧 Inspector 显示能力、疲劳、士气、伤病、恢复周、性格、价值
观、工资、关系和近期计数。Recent Records 只从 ContractHistoryEntry 投影，不增加
出勤或生涯统计存档。

### Presentation and localization

- View 只接收 ViewData，不读取深层 CampaignState。
- Presenter 接收 detached state 与 detached definitions。
- 所有列表使用稳定 ID 或已定义 sort_order 决胜。
- 建立简体中文 Godot localization 表；本任务覆盖应用壳、Guild、八名成员、三个
  阵营、局势、问题、行动和消息所需文本。
- 缺失翻译在开发构建中显示可定位 issue，不静默展示内部 key。

## Focused tests

至少覆盖：

1. 同一 setup/seed 两次生成相同第 1 周 content signature。
2. Gate F 全部初值、active 问题和 deadline 正确。
3. 第 1 周恰好三个 pending Offer，且不执行维护或被动钟变化。
4. setup 缺失引用、重复成员或非法初值阻止 Catalog 发布和新游戏。
5. GameSession 返回的 snapshot 修改后不影响正式状态。
6. mark_read 只提交正式 Projector 结果。
7. Dashboard urgency 只显示 band、remaining turns 和最多两个 player reason。
8. Roster 最近记录只从合同历史派生。
9. Router 白名单、禁用 Resolution 和单 ScreenContainer 行为正确。
10. Dashboard/Roster 场景可在 1280×720 headless 实例化，无缺失节点或脚本错误。

## Out of scope

- 合同规划、预测、接受/拒绝和正式周末结算
- Resolution 结果展示
- SaveService、存档选择或设置
- 新成员、合同、阵营、问题、行动或结局
- 动画系统、全局事件总线、响应式移动端布局

## Acceptance tests

先运行 CampaignBootstrapper、GameSession、Presenter 和 scene focused tests，再运行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

并在 Godot 4.7 中手动检查 1280×720、1600×900、1920×1080 三种尺寸。

## Completion checklist

- [x] Gate F setup 通过 manifest 发布和验证。
- [x] 新战役稳定进入真实第 1 周 planning。
- [x] GameSession 是唯一 CampaignState 所有者且不包含公式。
- [x] 三 Autoload 上限没有突破。
- [x] Dashboard 与 Roster 使用 Presenter/ViewData。
- [x] FM 式侧边栏、单行选项卡与顶部工具栏职责不重叠。
- [x] focused/full suite 和三尺寸手工检查实际完成。

## Expected report

- CampaignSetupDefinition 与开局 content signature
- GameSession/SceneRouter 公开 API 和会话所有权
- Dashboard/Roster ViewData 字段和稳定排序
- localization 覆盖与缺失项
- focused/full 测试及三尺寸手工结果
- 未解决的 UI 可用性风险
