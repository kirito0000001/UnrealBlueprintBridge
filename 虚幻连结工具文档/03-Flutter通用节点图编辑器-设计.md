# Flutter 通用节点图编辑器 - 设计

版本：0.1  
日期：2026-07-07  
目标项目：`D:\UnrealMap\UnrealBlueprintBridge`  
Flutter 项目名：`unreal_blueprint_bridge`

## 1. 定位

这个项目从“幻杀 / Unreal 专用桥”调整为通用跨平台节点图 / 蓝图草稿编辑器。

第一版只做三件事：

- 画节点。
- 连引脚。
- 保存 / 加载结构化 JSON。

它不执行节点逻辑，不生成真实 Unreal 蓝图，不修改 `.uasset`。未来 Unreal 插件、其他项目、AI 工具可以读取这些 JSON，把它当成蓝图设计草稿、流程说明或实现参考。

## 2. 平台和技术栈

### 2.1 技术栈

- Flutter。
- Dart 业务逻辑。
- 自绘节点画布。
- JSON 作为图数据交换格式。

### 2.2 目标平台

第一版支持：

- Windows。
- Android。

同一套 Dart 数据模型、图编辑逻辑和大体一致的 UI 在两个平台复用。

Windows 端后续可以扩展：

- 本地文件管理。
- 启动器。
- 和 Unreal 插件通信。
- 打开项目目录。

Android 端第一版定位：

- 查看草稿。
- 编辑节点。
- 触控拖拽。
- 缩放和平移。
- 连线。
- 同步草稿。

Android 端不直接启动 Windows EXE，也不负责调用 Unreal Editor。

## 3. 非目标

第一版明确不做：

- 不执行图逻辑。
- 不做运行时解释器。
- 不直接生成 `.uasset`。
- 不直接编辑 Unreal 蓝图资产。
- 不依赖幻杀项目。
- 不依赖 GetTheMeaning 插件。
- 不做账号、云服务和多人协作。
- 不做复杂节点类型系统。
- 不做完整蓝图视觉复刻。

这些非目标是为了把第一版压在“可用的图编辑器”范围内。

## 4. 为什么用 Flutter

Flutter 适合这个项目的原因：

- Windows 和 Android 可以共用大部分 UI 和业务逻辑。
- 自绘画布、手势、缩放、拖拽、触控支持比较统一。
- Android 端比 WinUI 路线自然很多。
- Dart 的 JSON 模型和测试比较轻量。
- 项目放在英文路径 `D:\UnrealMap\UnrealBlueprintBridge`，可以降低 Flutter / Gradle / Windows 构建链遇到中文路径问题的概率。

当前环境里命令行尚未识别 `flutter` / `dart`，正式实现前需要安装 Flutter SDK 或把 Flutter 加入 PATH。

## 5. 产品形态

### 5.1 Windows 布局

Windows 首屏就是编辑器，不做 landing page。

建议布局：

```text
+-------------------------------------------------------------+
| 顶部工具栏：新建 打开 保存 导出 缩放 自动布局 删除            |
+-------------+-----------------------------------+-----------+
| 节点库       |                                   | 属性面板  |
| Event        |            节点画布               | 标题      |
| Function     |                                   | 说明      |
| Branch       |                                   | 引脚      |
| Variable     |                                   | 类型      |
| Note         |                                   | JSON预览  |
+-------------+-----------------------------------+-----------+
| 状态栏：保存状态 / 当前缩放 / 节点数量 / 连线数量              |
+-------------------------------------------------------------+
```

关键点：

- 画布是主角，占据最大区域。
- 左侧节点库可以收起。
- 右侧属性面板可以收起。
- 顶部工具栏只放高频动作。
- JSON 预览可以在右侧属性面板或底部抽屉里显示。

### 5.2 Android 布局

Android 屏幕更小，采用画布优先：

```text
+--------------------------------+
| 顶部 AppBar：保存 更多 缩放归位 |
+--------------------------------+
|                                |
|            节点画布            |
|                                |
+--------------------------------+
| 底部操作栏：添加 节点 属性 连线 |
+--------------------------------+
```

关键点：

- 默认全屏画布。
- 节点库通过底部 Sheet 打开。
- 属性面板通过底部 Sheet 或右侧抽屉打开。
- 触控优先支持双指缩放、单指拖动节点、空白处拖动画布。

## 6. 第一版核心功能

### 6.1 画布

必须支持：

- 平移。
- 缩放。
- 网格背景。
- 选择节点。
- 拖动节点。
- 选择连线。
- 删除选中项。
- 缩放归位。

Windows 输入：

- 鼠标滚轮缩放。
- 鼠标中键或空白拖拽平移。
- 左键选择和拖动节点。

Android 输入：

- 双指缩放和平移。
- 单指拖动节点。
- 点击选择。
- 长按打开节点操作。

### 6.2 节点

第一版节点字段：

- 标题。
- 说明。
- 节点类型。
- 位置。
- 尺寸。
- 输入引脚。
- 输出引脚。

内置节点类型：

- Generic
- Event
- Function
- Branch
- Variable
- Comment
- Note

这些只是草稿类型，不绑定真实 Unreal 节点类。

### 6.3 引脚

第一版引脚字段：

- 标题。
- 方向：input / output。
- 数据类型：exec / bool / int / float / string / object / custom。
- 是否允许多连线。

视觉上：

- 输入引脚在节点左侧。
- 输出引脚在节点右侧。
- `exec` 引脚可以用白色或中性色。
- 数据引脚可以先用统一蓝色，后续再按类型配色。

### 6.4 连线

必须支持：

- 从输出引脚拖到输入引脚创建连线。
- 选中连线。
- 删除连线。
- 保存连线。
- 加载后恢复连线。

连线规则第一版保持简单：

- output 只能连 input。
- input 不能连 input。
- output 不能连 output。
- 默认允许一个 input 只有一条数据线。
- `exec` input 可以先允许多条连线，方便表达多个执行路径进入同一节点。

### 6.5 属性编辑

选中节点后可以编辑：

- 标题。
- 说明。
- 节点类型。
- 输入引脚列表。
- 输出引脚列表。

选中引脚后可以编辑：

- 标题。
- 数据类型。
- 是否允许多连线。

选中连线后可以编辑：

- 标题 / 备注。
- 连线类型。

### 6.6 保存和加载

第一版必须支持：

- 新建图。
- 保存 JSON。
- 加载 JSON。
- 保存失败提示。
- JSON 解析失败提示。

Windows 可以优先使用文件选择器保存 / 打开。

Android 可以先使用应用文档目录保存，再增加导入 / 分享 / 文件选择。

## 7. JSON 数据格式

第一版建议文件扩展名：

```text
.ubbridge.json
```

顶层结构：

```json
{
  "schemaVersion": 1,
  "graph": {
    "id": "graph_001",
    "title": "Login Flow",
    "description": "登录流程草稿",
    "createdAt": "2026-07-07T12:00:00+08:00",
    "updatedAt": "2026-07-07T12:20:00+08:00",
    "viewport": {
      "offsetX": 0,
      "offsetY": 0,
      "zoom": 1.0
    }
  },
  "nodes": [],
  "links": []
}
```

节点：

```json
{
  "id": "node_event_login",
  "nodeType": "Event",
  "title": "Login Request",
  "description": "玩家请求登录。",
  "position": { "x": 120, "y": 80 },
  "size": { "width": 240, "height": 140 },
  "pins": [
    {
      "id": "exec_out",
      "direction": "output",
      "title": "Then",
      "dataType": "exec",
      "allowMultipleLinks": true
    }
  ]
}
```

连线：

```json
{
  "id": "link_001",
  "fromNodeId": "node_event_login",
  "fromPinId": "exec_out",
  "toNodeId": "node_check_user",
  "toPinId": "exec_in",
  "title": "",
  "description": "",
  "linkType": "exec"
}
```

设计原则：

- `id` 稳定，不随标题变化。
- `position` 使用画布坐标，不使用屏幕坐标。
- JSON 字段用英文，便于其他项目读取。
- 节点说明可以写中文。
- 未知字段读取时尽量保留，便于后续版本兼容。

## 8. 代码结构建议

Flutter 项目建议结构：

```text
lib/
  main.dart
  app/
    blueprint_bridge_app.dart
  core/
    models/
      graph_document.dart
      graph_node.dart
      graph_pin.dart
      graph_link.dart
      graph_viewport.dart
    services/
      graph_json_codec.dart
      graph_file_service.dart
      graph_validation_service.dart
    state/
      graph_editor_controller.dart
      selection_state.dart
      tool_state.dart
  features/
    editor/
      editor_page.dart
      graph_canvas.dart
      graph_painter.dart
      node_widget.dart
      node_palette_panel.dart
      inspector_panel.dart
      editor_toolbar.dart
      mobile_editor_shell.dart
      desktop_editor_shell.dart
  shared/
    widgets/
    theme/
```

职责边界：

- Model 只描述数据。
- `graph_json_codec` 负责 JSON 序列化和兼容。
- `graph_file_service` 负责保存 / 读取文件。
- `graph_validation_service` 负责连线合法性检查。
- `graph_editor_controller` 负责编辑命令，例如新增节点、移动节点、创建连线、删除选中项。
- `graph_painter` 只画网格和连线。
- `node_widget` 只显示节点和引脚。
- 平台差异放在 shell 和 file service，不扩散到业务模型。

## 9. 状态管理

第一版不需要引入复杂状态框架。

推荐：

- 先用 `ChangeNotifier` / `ValueNotifier`。
- `GraphEditorController` 作为中心编辑控制器。
- 所有编辑命令都通过 controller 执行。
- UI 不直接改 model list，避免 Windows / Android 行为漂移。

后续如果项目变大，再考虑 Riverpod。

## 10. 画布实现思路

第一版可用 Flutter 原生组件完成：

- `InteractiveViewer` 承载缩放和平移。
- `Stack` 放节点。
- `CustomPainter` 绘制网格和连线。
- 节点用 Flutter widget，便于文字、输入框、按钮和触控。

坐标转换：

- Model 保存画布坐标。
- 屏幕事件通过当前 transform 转换到画布坐标。
- 连线端点从节点 position + pin local offset 计算。

后续如果节点数量很大，再优化为更强的可视区域裁剪和批量绘制。

## 11. 文件和平台差异

### 11.1 Windows

Windows 第一版：

- 打开 JSON 文件。
- 另存为 JSON 文件。
- 记住最近文件路径。
- 可以从命令行参数打开文件，后续供 Unreal 插件调用。

### 11.2 Android

Android 第一版：

- 默认保存到应用文档目录。
- 提供草稿列表。
- 支持导入 JSON。
- 支持分享 JSON。

如果第一阶段文件选择器配置太耗时，可以先完成应用内草稿列表，再做系统文件选择。

## 12. 错误处理

必须处理：

- JSON 格式错误。
- schemaVersion 不支持。
- node id 重复。
- link 引用不存在的 node / pin。
- 保存路径不可写。
- Android 权限或文件选择失败。

处理原则：

- 不崩溃。
- 明确告诉用户失败原因。
- 尽量保留当前内存图。
- 加载失败不覆盖当前图。

## 13. 测试和验证

第一版最低验证：

- `flutter analyze`
- Dart model / JSON codec 单元测试。
- Windows debug 启动。
- Android debug 构建。
- 手动测试新增节点、拖动、缩放、连线、保存、加载。

需要特别测：

- Windows 鼠标和 Android 触控行为是否一致。
- 保存后再打开，节点位置和连线是否恢复。
- 删除节点后相关连线是否清理。
- JSON 损坏时是否不覆盖当前图。

## 14. 第一版完成标准

第一版完成后应做到：

- Windows 可以启动编辑器。
- Android 可以启动编辑器。
- 可以新增节点。
- 可以拖动节点。
- 可以编辑节点标题和说明。
- 可以新增输入 / 输出引脚。
- 可以从输出引脚连到输入引脚。
- 可以删除节点和连线。
- 可以保存 JSON。
- 可以加载 JSON 并恢复画布。
- JSON 结构清晰，能被 Unreal 插件或其他项目读取。

## 15. 后续扩展

后续可以继续加：

- Undo / Redo。
- 自动布局。
- 节点模板。
- 分组 / 注释框。
- 搜索节点。
- Mermaid / Markdown 导出。
- Unreal 蓝图风格节点主题。
- GetTheMeaning JSON 导入。
- Codex 友好的“复制图摘要”。
- Windows 端本地项目管理。
- Unreal 插件一键打开草稿。
- Android 和 PC 草稿同步。

## 16. 实现前置条件

正式动手前需要确认：

- Flutter SDK 已安装并加入 PATH。
- `flutter doctor` 能识别 Windows desktop 和 Android toolchain。
- `D:\UnrealMap\UnrealBlueprintBridge` 可以清理 `.vs` 并创建 Flutter 项目。

当前检查结果：

- 目标目录只剩 `.vs`。
- 目标目录不是 git 仓库。
- 当前命令行未识别 `flutter`。
- 当前命令行未识别 `dart`。

所以实现第一步应是配置 Flutter 环境，或者由用户提供已经可用的 Flutter SDK 路径。

