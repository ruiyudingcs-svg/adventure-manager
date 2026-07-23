# 纵向切片开发路线 V0.1

## 1. 开发原则

- 每个里程碑必须产生可运行构建。
- 先证明规则，再制作表现。
- 每项任务控制在 Codex 能完整理解和验证的范围。
- 不以“写了多少代码”作为进度，只以退出条件为准。
- 发现范围不足时删功能，不通过增加基础设施拖延验证。

## 2. Milestone 0：仓库与可运行骨架

### 目标

建立可打开、可命令行运行、可测试的 Godot 项目。

### 工作项

- 创建 Godot 项目
- 建立目录结构
- 创建 `app_root.tscn`
- 建立最小导航壳
- 创建 `AGENTS.md`
- 创建 headless 测试器
- 配置 `.gitignore`
- 添加一项 smoke test

### 退出条件

- 编辑器可打开项目且无错误。
- 启动后显示空 Dashboard。
- headless 测试命令退出码为 0。
- 仓库中没有第三方插件。

## 3. Milestone 1：纯逻辑模拟

### 目标

不依赖 UI，完成一次合同结算和一周推进。

### 工作项

- CapabilityBlock
- IdeologyVector
- AdventurerDefinition / State
- ContractDefinition / Offer / Plan
- ReasonEntry / StateChange
- SeededRandom
- ContractResolver 内部的纯态度计算
- TeamCapabilityCalculator
- ContractResolver
- ContractResolver 内部的纯条款求值
- ContractStageDefinition / ContractCheckDefinition
- MissionContext 与阶段间修正
- CheckResult / PhaseResult
- WeekFlowCoordinator 的最小流程
- 单元与确定性测试

### 退出条件

- 固定四人队、合同和 seed 可生成完整结果。
- 结果含逐判定评分、阶段结果、最终等级、疲劳、伤病、报酬和原因日志。
- 前序侦察或寻路结果可以确定性地修正后续主要行动与撤离。
- 三份基准合同可由同一条款和阶段模型结算，不需要合同专用脚本。
- 同一 seed 连续运行 100 次结果一致。
- 不同队伍产生可解释的不同结果。

## 4. Milestone 2：数据目录与首批内容

### 目标

把规则从硬编码样例迁移到 `.tres` 定义数据。

### 工作项

- DataCatalog
- CatalogValidator
- 8 名成员定义
- 3 个职业标签
- 5 个补给定义
- 6 份合同定义
- 新游戏状态构建器

### 退出条件

- 修改 `.tres` 数值无需修改结算器。
- 无效引用能在启动时被验证器发现。
- 一次 10 周自动模拟无崩溃。

## 5. Milestone 3：四屏可点击循环

### 目标

玩家能完整走通“阅读—选择—结算—下一周”。

### 工作项

- Dashboard
- Roster
- Contract Planning
- Resolution
- SceneRouter
- ViewData / Presenter
- 基本输入验证

### 退出条件

- 可在 UI 中接受合同、选四人、选补给、选倾向并结算。
- 结算页能按阶段展示原因。
- UI 刷新不会重新投掷结果。
- 所有核心规则仍可 headless 测试。

## 6. Milestone 4：世界危机与阵营

### 目标

让合同选择产生 10 至 15 周的长期方向。

内容设计进度：局势阶段、结局、阵营目标和五条钟已经在 `docs/17_dragon_invasion_scenario_spec.md` 定案；九个问题、阵营行动、合同覆盖与结局路径已经在 `docs/18_dragon_invasion_problem_and_action_catalog.md` 定案。Milestone 4 的内容设计前置已完成，领域实现与测试仍未完成。

### 工作项

- 3 个阵营定义与状态
- SituationDefinition / State
- WorldProblemDefinition / State
- WeeklyUpkeepResolver
- WeekFlowCoordinator
- SituationResolver
- FactionTurnPlanner
- ContractOfferService
- ContractResolver
- WeeklyMessageProjector
- FactionActionCommitmentState
- MessageState
- WorldEventState
- 巨龙入侵剧本内容规格
- 三个阵营的最终目标与 3 至 5 个阶段性小目标
- 5 条进度钟
- 9 个完整世界问题定义与问题依赖图
- 三个阵营的完整 weekly_action_table
- 阵营单一周模式、精确 target lock 排他与延迟行动结算
- 合同倒计时、玩家拒绝与未处理结果
- 阵营关系对合同期限和报酬的档位加成
- 跨钟触发规则
- 其余 6 份合同
- V0.1 内容任务类型与 12 份合同的目标覆盖审计
- 4 个具有精确条件与稳定优先级的结局

### 退出条件

- 同一开局可走向至少四种不同结局。
- 三个阵营各有一个最终目标和 3 至 5 个可由合同或直接行动推进的小目标。
- 五条进度钟都有初值、被动变化、生产者、抑制者和阈值用途。
- 九个世界问题都有激活、期限、解决、恶化、事件和后续解锁。
- 三个阵营的直接行动表覆盖所有非结局阶段。
- 十二份合同全部连接至少一个阵营小目标、世界问题、进度钟和潜在结局。
- 不处理某类问题会产生可见后果。
- 世界问题紧迫度能由基础值、进度钟、年龄、期限和阶段确定性派生。
- 阵营直接行动和合同提案使用同一四项优先级与原因记录。
- 阵营直接行动与合同提案读取同一规划快照，行动效果不改写同周合同和预测。
- 合同提案遍次先于直接行动遍次，行动不会阻止正常三栏恢复。
- 每个阵营无 pending 时只提案、有 pending 时只直接行动，且有自动测试。
- pending Offer、新 Offer 和行动承诺的精确 target lock 全局唯一。
- 三个阵营各自拥有可达 fallback Agenda 合同，正常周稳定恢复三栏。
- 未接受合同可按固定策略被玩家拒绝、自然过期、由 NPC 完成或转化为问题恶化；NPC 完成复用预制阵营行动且不存在随机失败，提出方不能撤回。
- 世界状态只绑定 check 难度和初始 MissionContext，预测与结算读取同一 effective contract。
- 合同最后有效周、关系期限加成和关系报酬加成都有自动测试。
- 至少三份合同具有短期收益与长期目标冲突。
- Dashboard 显示当前局势和下周风险预测。
- Dashboard 显示本周 NPC 行动预告；合同来源原因可解释但不泄露精确 AI 权重。

## 7. Milestone 5：存档、平衡与可测试构建

### 目标

形成可交给外部测试者的 V0.1。

### 工作项

- SaveService
- 存档版本号
- 加载验证
- 关键遥测输出
- 数值平衡
- 教程提示
- 错误和空状态处理
- Windows / Linux 或 macOS 导出测试

### 退出条件

- 任意周可保存并加载。
- 加载后已锁定结果不改变。
- 新玩家不依赖开发者解释即可完成一局。
- 10 次完整测试中无阻断 bug。

## 8. 每周个人开发节奏

建议使用固定循环：

```text
定义一个可验证问题
→ 写或更新文档
→ 创建一个小任务文件
→ 让 Codex 实现
→ 人工审查 diff
→ 运行测试
→ 在 Godot 中手动验证
→ 提交
→ 记录发现与下一问题
```

不要让 Codex 连续完成整个里程碑。一次任务最好只跨一个领域服务或一个界面流程。

## 9. 第一批任务顺序

1. Project bootstrap
2. ReasonEntry 与 StateChange
3. SeededRandom
4. CapabilityBlock 与 TeamCapabilityCalculator
5. IdeologyVector 与合同内态度计算
6. ContractResolver
7. WeekFlowCoordinator
8. DataCatalog 与验证器
9. 首批 4 名成员和 2 份合同
10. Dashboard 壳
11. Roster
12. Contract Planning
13. Resolution
14. 世界进度钟
15. 存档

## 10. 暂停扩张的信号

出现以下任一情况时停止增加内容，先修复结构：

- 同一公式在两个地方实现。
- UI 必须直接改多个状态对象才能工作。
- 无法复现某个测试者的结果。
- 新合同需要修改结算器才能加入。
- 原因日志无法说明关键变化。
- Codex 每次任务都需要阅读整个仓库。
- 单一任务修改超过三个领域模块。
