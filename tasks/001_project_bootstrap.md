# Task 001 — Project Bootstrap

状态：Ready  
里程碑：Milestone 0  
依赖：无

## Goal

创建 V0.1 的最小 Godot 4.7 项目、可运行 Dashboard 壳和无第三方依赖的 headless 测试器。此任务只建立基础设施，不定义任何游戏领域 API。

## Required reading

- 根目录 `AGENTS.md`
- `docs/01_v0.1_product_spec.md`
- `docs/03_godot_architecture.md`
- `docs/05_vertical_slice_roadmap.md` 的 Milestone 0
- `tasks/000_v0.1_execution_map.md`

## Preconditions

- 仓库中尚未存在可运行的 Godot 项目。
- 使用 Godot 4.7 stable、GDScript 静态类型、桌面优先和 `Control` UI。
- 不安装第三方 addon 或测试框架。

## Allowed files

- `project.godot`
- `.gitignore`
- `README.md`
- `game/app/app_root.tscn`
- `game/app/app_root.gd`
- `game/features/dashboard/dashboard_view.tscn`
- `game/features/dashboard/dashboard_view.gd`
- `game/ui/theme/**`
- `tests/run_all.gd`
- `tests/unit/test_smoke.gd`

除非现有同名文件阻止本任务，否则不得修改其他文件。

## Required behavior

1. `project.godot` 使用 Godot 4.7 兼容配置，主场景固定为 `res://game/app/app_root.tscn`。
2. `AppRoot` 是最小应用容器，实例化 Dashboard；不得持有合同、成员、阵营或世界规则。
3. Dashboard 使用 `Control` 容器布局，显示：
   - 项目标题；
   - 当前周占位值；
   - 金币占位值；
   - 一个可扩展的空内容区。
4. 1280×720 下不得依赖绝对坐标堆叠主要控件；窗口变化时布局仍保持可用。
5. `tests/run_all.gd` 能以稳定顺序发现并运行仓库内测试，汇总成功/失败数量，并以正确进程退出码结束。
6. smoke test 至少验证：
   - 主场景路径存在并可加载；
   - `app_root.tscn` 可实例化；
   - Dashboard 节点存在；
   - 测试结束后释放实例。
7. `.gitignore` 至少排除 `.godot/`、导出临时文件和本地编辑器产生物，但不得忽略游戏资源或测试。
8. 新增 GDScript 使用静态类型；不得创建全局事件总线。

## Autoload decision

本任务不创建 `GameSession`、`DataCatalog` 或 `SceneRouter` stub，也不在 `project.godot` 注册 Autoload。它们在出现真实职责与测试时再加入；空全局对象会制造错误依赖。

## Out of scope

- 任何合同、英雄、补给、阵营、局势和周流程类型
- `GameSession`、`DataCatalog`、`SceneRouter`
- 存档与加载
- 最终美术、动画、音频和本地化系统
- 响应式多分辨率完善
- 第三方插件

## Acceptance tests

执行：

```bash
godot --headless --path . --script res://tests/run_all.gd
```

必须满足：

- 退出码为 0；
- 无 GDScript parser error；
- smoke test 确认主场景和 Dashboard 可加载、实例化和释放；
- 测试结果顺序固定，不依赖文件系统返回顺序。

若环境中没有 `godot` 可执行文件，必须明确报告测试未运行，不得将静态检查表述为通过。

## Manual verification

1. 用 Godot 4.7 打开项目。
2. 运行主场景。
3. 在 1280×720 确认四项 Dashboard 内容可见且无重叠。
4. 改变窗口大小，确认主要容器不会脱离窗口。

## Completion checklist

- [ ] 只修改 Allowed files。
- [ ] 无 Autoload 和 addon。
- [ ] UI 脚本不含游戏公式。
- [ ] headless 测试实际运行并记录结果。
- [ ] `git diff` 中没有 `.godot/` 或其他生成文件。

## Expected report

- 修改文件列表
- 主场景和测试器的行为
- 精确测试命令、退出码和摘要
- Godot 警告
- 假设与未完成项

