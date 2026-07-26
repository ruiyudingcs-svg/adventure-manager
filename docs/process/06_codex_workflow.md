# Codex 协作工作流

## 1. 目标

Codex 应作为受约束的实现者和审查助手，而不是替代产品决策。它擅长处理清晰边界、可运行测试和明确文件范围的任务。

## 2. 仓库级指令

把本包的 `AGENTS.md` 放到 Git 仓库根目录。Codex 会在开始工作前读取项目指令；子目录需要特殊规则时，可以放置更具体的 `AGENTS.md` 或 override 文件。

根指令只保留长期稳定内容：

- 产品边界
- 架构规则
- 命名规范
- 测试命令
- 禁止事项
- 完成定义

临时需求不要塞进根 AGENTS，写入单独 task 文件。

## 3. 一项任务的标准结构

每个任务必须包含：

```text
Goal
Context
Allowed files
Required behavior
Out of scope
Acceptance tests
Manual verification
Expected report
```

任务应引用文档章节，而不是重复创造规则。

## 4. 推荐提示词

### 4.1 实现任务

```text
Read AGENTS.md and docs relevant to tasks/NNN_name.md.
Inspect the existing implementation before editing.
Implement only the task scope.
Do not add dependencies or redesign adjacent systems.
Run the specified headless tests.
Then report:
1. files changed,
2. behavior implemented,
3. tests run and results,
4. remaining risks or assumptions.
```

### 4.2 只做审查

```text
Review the current diff against AGENTS.md and the referenced task.
Do not edit files.
Identify correctness defects, scope creep, nondeterminism,
state mutation risks, missing tests, and Godot-specific issues.
Rank findings by severity and cite file paths and lines.
```

### 4.3 修复单一 bug

```text
Reproduce the reported bug with a failing test first.
Make the smallest fix that restores the documented behavior.
Do not refactor unrelated files.
Run the focused test and the full headless suite.
```

## 5. 人工审查清单

每次接受 Codex 修改前检查：

- 是否修改了任务范围外文件。
- 是否把规则写进 UI。
- 是否引入全局状态或新 Autoload。
- 是否使用全局随机数。
- 是否直接修改静态 Definition。
- 是否缺少原因记录。
- 是否补充了测试。
- 是否静默吞掉错误。
- 是否添加依赖或插件。
- 是否更新相关文档。

## 6. Codex 禁止自行决定的事项

未经明确任务授权，Codex 不得：

- 改变 Godot 主版本或次版本。
- 把 GDScript 改为 C#。
- 引入 addon、NuGet 包或外部服务。
- 增加 Autoload。
- 改动存档 schema。
- 修改产品范围。
- 创建通用 ECS、事件总线、依赖注入框架。
- 重构整个目录结构。
- 把 V0.2 功能提前实现。
- 自动更新 golden trace。

## 7. 任务粒度

合适的任务：

- 实现 `ContractResolver` 内部的纯态度计算和测试。
- 新增两份合同 Resource，并通过验证器。
- 为 Contract Planning 添加队伍人数验证。
- 修复存档后随机种子改变的问题。

过大的任务：

- “完成整个游戏原型”。
- “实现所有管理系统”。
- “重构架构让它更专业”。
- “加入完整战斗系统”。

## 8. 分支与提交

建议一项任务一个分支或至少一个独立提交。

提交信息：

```text
feat(simulation): add deterministic contract resolver
fix(save): preserve locked contract seed
content(contracts): add north road evacuation offers
docs(scope): clarify v0.1 injury tiers
```

Codex 的最终报告不等于代码正确。只有测试、人工 diff 审查和 Godot 手动运行全部通过后才合并。

## 9. 上下文控制

- 任务文件只引用必要文档。
- 不要求 Codex每次重读全部概念讨论。
- 已废弃设计放入 archive，不与有效文档混在一起。
- 文件头写明状态：draft、accepted、superseded。
- 规则发生冲突时，以 `01_v0.1_product_spec.md` 为产品最高优先级，以 ADR 为技术决策最高优先级。

## 10. 完成定义

Codex 任务只有满足以下条件才完成：

- 行为符合任务和文档。
- 无任务外功能。
- 新行为有测试。
- 全部现有测试通过。
- Godot 项目无解析错误。
- 公开类型和非显然规则有文档注释。
- 报告中列出假设与未解决风险。
