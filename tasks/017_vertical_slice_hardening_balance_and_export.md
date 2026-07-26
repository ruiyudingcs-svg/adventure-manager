# Task 017 — Vertical Slice Hardening, Balance Audit and Export

状态：Validation（自动验证完成；手工整局与 Windows 导出模板待验收）
里程碑：Milestone 5（存档、平衡与可测试构建）
依赖：Task 013—016

## Goal

把已经可玩的纵向切片整理为可交给外部测试者的 V0.1：补齐结局页、最小引导、
错误与空状态，执行真实 10—15 周整局和数值审计，并验证桌面导出。任务以发现和
修复阻断问题为目标，不借机增加内容或重做架构。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md` 全文，特别是第 3、5、11、13 节
- `docs/03_godot_architecture.md` 第 15—17 节
- `docs/05_vertical_slice_roadmap.md` Milestone 5
- `docs/10_baseline_contracts.md`
- `docs/17_dragon_invasion_scenario_spec.md`
- `docs/18_dragon_invasion_problem_and_action_catalog.md` 第 11 节
- `docs/21_remaining_contract_numerical_rules.md`
- `docs/22_campaign_bootstrap_forecast_and_ui_shell.md`
- Task 013 的四条真实 ending path 与 Task 014—016 的实际 UI/存档 API

## Allowed files

- `game/features/ending/**`
- `game/features/onboarding/**`
- `game/features/shared/**`
- `game/ui/components/**`、`game/ui/theme/**`
- `game/app/**`，仅收尾状态、错误处理和 route 集成
- `game/persistence/**`，仅修复 Task 016 验收暴露的明确缺陷
- `tests/integration/**`、`tests/scenarios/**`、`tests/ui/**`、`tests/run_all.gd`
- `tools/balance/**` 或等价只读报告脚本
- `export_presets.cfg` 与必要的非密钥导出配置
- localization 与用户可见说明文档
- 被验证明确证明错误的既有模块；修改前必须在报告中列出缺陷和最小修复理由

不得自动修改 Gate A—F、三份 golden、九合同校准、结局阈值或新增内容。数值差异
先生成报告并等待人工决定。

## Ending screen

GameSession phase 为 ended 时路由到完整结局页，显示：

- 结局标题、叙述和结束周
- 五条钟终值
- 关键世界事件和主要问题结果
- 玩家合同历史摘要
- 三阵营最终关系
- 八名成员疲劳、伤势和 morale
- 最多八条决定性 player reason
- `开始新游戏` 和 `返回标题`

结局页只读已提交 CampaignState/History，不重新运行 ending 选择或推断另一候选。

## Minimal onboarding

只实现第一局、第一周的六步轻量提示：

1. 查看局势和紧迫问题。
2. 阅读三份合同。
3. 选择四名成员。
4. 选择补给和 Approach。
5. 确认并结束本周。
6. 阅读阶段结果和后果。

提示可以跳过，并只在当前应用会话记录完成状态；不增加教程存档 schema、规则引擎
或脚本化任务系统。

## Error and empty states

至少覆盖：

- Catalog/setup 无法加载
- 无合法存档或存档损坏
- 无未读消息
- declined 合同栏
- 无可用 Resolution
- 非法或资金不足计划
- 周末事务失败且正式状态未改变
- 已结束战役
- 缺失 localization key

玩家错误使用对话/inline issue；开发期不变量才使用 assert。所有 destructive UI
动作（覆盖存档、跳过合同、开始新游戏）二次确认。

## UI quality pass

- 1280×720、1600×900、1920×1080 无遮挡、越界或不可滚动内容。
- 单行上下文 tabs，不出现第二层嵌套 tabs。
- 键盘焦点顺序、Enter/Escape、滚轮和 tooltip 可用。
- 禁用按钮给出原因；颜色不是风险、伤病或 tier 的唯一信息来源。
- 长中文文本、最大消息数和八成员关系内容仍可阅读。
- 不引入第三方 UI addon。

## Balance audit

使用真实 Content、GameSession/WeekFlow 和 locked seed，运行至少十局 10—15 周完整
战役。样本策略至少覆盖：

- 四条 Task 013 ending golden 路径各一局
- 高收益偏好
- 低风险/保护生命偏好
- 单一阵营偏好
- 每周跳过合同
- 高补给支出
- 疲劳轮换

每局输出只读报告：

```text
seed
ending_id
ending_week
final_gold
result_tier_counts
contracts_resolved/skipped/declined/expired/npc_completed/escalated
light/heavy_injury_counts
member_final_fatigue/morale
faction_relations
five_clock_values
save_load_checkpoints
```

报告不得成为游戏状态或外部遥测上传。任何建议改数值必须列出受影响 golden、路径和
原因，等待人工批准。

## Full-flow and export validation

自动测试：

1. 四结局从真实新游戏 setup 可达。
2. 同一 seed 与玩家选择重复整局 signature 相同。
3. 每局至少在 planning 保存/加载一次且后续结果不变。
4. 十局没有阻断 issue、重复提交、部分状态或未结束局。
5. UI route、session phase 和 top action 全流程一致。

手工测试：

- 新玩家不查看开发文档完成一局。
- 接合同、跳过、拒绝、存档、继续、结果和结局页各走一次。
- Windows debug/release 导出启动并完成至少两周。

若本机缺少 Godot 4.7 export templates，必须报告环境阻塞，不得声称导出通过或从网络
自动安装。Linux/macOS 导出仅在现有模板与环境允许时追加，不是 Windows 验收的替代。

## Out of scope

- 新合同、成员、阵营、局势、结局或 V0.2 系统
- 云服务、账号、在线遥测、成就、创意工坊
- 动画战斗、配音、完整音乐系统或视觉重制
- 自动接受平衡建议或重写 golden

## Acceptance tests

1. 运行本任务 focused/UI/full-flow tests。
2. 运行全部四条 ending paths。
3. 运行十局 balance audit。
4. 运行完整 suite。
5. 完成三尺寸手工 UI 和 Windows 导出检查。

## Completion checklist

- [x] 结局页完整且不重新求值。
- [x] 六步引导可跳过且不扩展存档 schema。
- [x] 关键错误/空状态具有玩家可理解反馈。
- [ ] 三种分辨率与基础键盘操作可用。
- [x] 十局在 10—15 周内结束且确定性可复现。
- [x] 人工批准的平衡调整已写入 Accepted 规则、golden 与审计报告。
- [x] full suite、手工整局和导出结果如实记录。

## Validation record — 2026-07-25—26

已完成的自动验证：

- 结局页只投影已提交的 `CampaignState`/History，包含五钟、关键事件/问题、
  合同历史、三阵营、八成员和最多八条 player reason；ended phase 只允许结局 route。
- 六步引导仅保存在当前应用会话，可跳过，不修改 save schema。
- Catalog/setup、存档、无消息/无未读消息、declined slot、无 Resolution、非法计划、
  周末事务失败、已结束战役和缺 localization key 均具有显式反馈。
- 1280×720、1600×900、1920×1080 三尺寸已做自动场景实例化、全屏 anchor、
  滚动区和操作按钮检查；键盘焦点、Enter/Escape 与完整人工可读性仍需手工确认。
- Task 013 四条真实 ending path：4 passed、0 failed。
- Task 017 ending/onboarding/inbox/localization focused：9 passed、0 failed。
- Task 014 scene/roster click lifecycle focused：4 passed、0 failed。
- 十局真实 `GameSession` 战役：3 passed、0 failed；全部在第 10—15 周结束，
  每局 planning 保存/加载一次，同 seed/策略的完整状态 signature 可复现。
- Dashboard 信箱点击不再在 `pressed` 信号栈内同步释放按钮；消息已读刷新延迟到
  信号解锁后，且动态节点使用 `queue_free()`。回归测试会在消息回调内同步重建 Inbox。
- Roster 成员点击重建成员列表和详情时使用延迟释放，不再销毁正在发出 `pressed`
  的成员按钮；回归测试实际点击第二名成员并检查选择和列表替换。
- 合同栏使用的四个 `reason.faction_intent_*` key 已补齐中文并重新导入运行时
  `.translation`；覆盖测试通过 `TranslationServer` 验证，不再显示 `[MISSING:…]`。
- 合同 Squad 卡片现显示六项能力以及疲劳、士气、伤势；Presenter 和真实场景测试
  验证八名成员的 detached 数值与 Definition 一致。
- 结算四阶段原因使用固定 `reason.*` 本地化键；工会与世界页保留完整 StateChange
  审计数据，但将活动计划显示为状态、将合同/消息历史和 pending Offer 显示为
  记录数量，不暴露内部签名；成员、阵营、进度钟、字段与可出勤状态投影为中文；
  原因日志使用显式正负数字格式，
  条款效果统一为三种固定本地化键。真实结算场景回归覆盖三个选项卡且不允许出现
  `[MISSING:...]`、`%+g` 或序列化记录。
- 首周合同专项审计先确认旧单次 check 边界 `80/60/40/20` 造成校准过难；经人工
  批准后，单次 check 边界调整为 `70/50/30/10`，合同加权边界仍为
  `80/60/40/20`。48 个 check difficulty、成员能力、随机范围、补给、条款与
  final outcome 数值均未改变。
- 调平后审计对每份 Offer 的全部 70 个四人组合 × 3 Approach 做 64-seed 真实
  解析排序，再从真实前五方案展开全部合法补给；无补给均精确重排 210 个方案，
  准备后分别重排 155、155、95 个方案。最佳准备方案的 64-sample 结果为：
  - 定位巨龙巢穴：1 Failure、37 Partial、26 Success。
  - 回收完整尸体：14 Failure、50 Partial、0 Success；仍是明确的高风险合同。
  - 侦察东部道路：16 Failure、0 Partial、46 Success、2 Exceptional。
  三份锁定 seed 分别为 Partial、Partial、Success，形成早期成功、中等结果和
  高风险选择的清晰梯度。
- 专项报告位于 `tools/balance/task017_contract_difficulty_report.json`，并记录
  check/contract 两套阈值、真实重排数量、check 分数、条款满足率和锁定结果。
- 完整 Godot 4.7 headless suite：233 passed、0 failed。退出时仍有测试夹具造成的
  `ObjectDB`/38 resources 清理警告，不影响测试退出码 0，但应作为后续测试基础设施风险。

只读平衡报告位于
`tools/balance/task017_balance_report.json`。调平后的十个自然策略样本共解析 78 份
玩家合同：64 Failure、10 Partial、4 Success、0 Severe；旧报告为 75 份中的
59 Failure、15 Severe、1 Partial、0 Success。极端失败已经消失并出现成功，但该
自动玩家只选首支合法低疲劳队伍，不读取六项能力或条款，仍明显偏向 Failure。
九局在第 10 周进入 `ending_necrotic_catastrophe`，一局跳过全部合同时在第 15 周进入
`ending_dragon_slain_at_cost`。这项结果保留为“简单策略不足”的风险，不再通过整体
下调合同难度掩盖；四条定向 golden path 仍全部可达。

Windows preset 已写入 `export_presets.cfg`。实际执行 Debug 与 Release 导出均退出 1，
Godot 明确报告缺少：

```text
C:/Users/wsxfp/AppData/Roaming/Godot/export_templates/4.7.stable/windows_debug_x86_64.exe
C:/Users/wsxfp/AppData/Roaming/Godot/export_templates/4.7.stable/windows_release_x86_64.exe
```

因此没有声称 Windows 构建通过，也没有联网安装模板。安装 Godot 4.7 stable export
templates 后，仍需执行 Debug/Release 构建启动、至少两周流程，以及三尺寸/键盘/完整新玩家
整局手工验收。

## Expected report

- 结局页、引导、错误/空状态清单
- 三尺寸与输入可用性结果
- 十局 balance report 摘要和异常
- 四结局、存档往返与确定性证据
- 完整测试和 Windows 导出命令、退出码与环境
- 需要人工决定的任何数值调整
