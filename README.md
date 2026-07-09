# 虚幻：蓝图连结

`unreal_blueprint_bridge` 是一个基于 Flutter 的通用节点图 / 蓝图草稿编辑器，目标平台先支持 Windows 和 Android。

AI / 插件生成图包请先阅读：[AI_GRAPH_PACKAGE_GUIDE.md](AI_GRAPH_PACKAGE_GUIDE.md)

应用显示名称：`虚幻：蓝图连结`

Android 包名：`com.TFAC.unreal_blueprint_bridge`

第一版先专注于绘制蓝图风格的节点草稿、连接引脚、编辑节点说明，并保存 / 加载结构化 JSON 数据。它不会执行图逻辑，不会生成 Unreal 资产，也不会直接修改 `.uasset` 文件。

## 项目定位

这个工具用于把 Unreal 蓝图、AI 生成的图例、GetTheMeaning 插件导出的项目识别数据集中到一个可查看、可整理、可讨论的节点画布里。它更像“蓝图草稿本 + 项目逻辑阅读器”，不是 Unreal Editor 的替代品。

适合的使用场景：

- 和 AI 讨论蓝图逻辑，让 AI 输出结构化 `GraphIndex.json` 图包。
- 绑定 Unreal 项目后读取 `Saved/GetTheMeaningExports`，查看蓝图资产、函数、变量、事件和执行流。
- 从 GetTheMeaning 的 `*_Logic.json` 生成本地蓝图草稿，用于检查节点、引脚、连线和网络复制信息。
- 在不打开 Unreal 的情况下整理草稿、做注释框、框选节点、拖线、创建变量 / 函数 / 事件示意。

不适合的使用场景：

- 直接运行蓝图逻辑。
- 直接生成或修改 Unreal `.uasset` 文件。
- 作为 1:1 的 Unreal 蓝图编辑器替代。

## 当前能力

- Windows 桌面端可用，Android 作为同一套 Flutter 代码的后续目标。
- 画布支持右键拖动、左键框选、节点拖拽、节点删除、注释框、连线拖拽、输入引脚断开 / 重连。
- 右侧面板支持成员列表、节点搜索、节点细节、变量细节、事件细节、函数细节。
- 变量可创建、重命名、拖到画布生成 Get / Set 节点，并保留 Unreal 风格的复制选项。
- 函数可创建、进入函数图表、设置输入输出；纯函数会按绿色函数风格显示。
- 事件列表支持自定义事件、事件调用节点和网络 RPC 信息。
- 支持导入 AI 生成的 `GraphIndex.json` 图包。
- 支持绑定 `.uproject`，识别对应的 `Saved/GetTheMeaningExports`。
- 支持从 GetTheMeaning 的 `*_Logic.json` 做节点级只读复原。

## GetTheMeaning 复原程度

当前已经能从 `*_Logic.json` 中复原：

- 蓝图资产信息：蓝图类型、父类、资产路径。
- 多个图表：`EventGraph`、函数图表、构造脚本等。
- 节点：节点 id、UE 原始 class、标题、summary、坐标。
- 引脚：pin id、名称、输入 / 输出方向、类型、默认值。
- 连线：执行线和数据线。
- 成员面板：变量、事件、函数。
- 网络信息：变量复制、RepNotify、事件 RPC 类型、可靠 / 不可靠。

当前仍然是“只读复原”：

- 不写回 Unreal `.uasset`。
- 节点尺寸由本工具根据内容重新估算，不保证和 Unreal 蓝图 1:1 一致。
- Widget 蓝图的 UI 可视布局还没有 1:1 复原，当前主要复原逻辑图和 WidgetTree 信息。
- 动态引脚规则只保留导出时已有的引脚，不模拟 Unreal 全部节点扩展规则。
- C++ 索引已经能被 GetTheMeaning 导出，但还没有完整接入到图表细节跳转。

复原路线记录在：[docs/get_the_meaning_blueprint_restore_roadmap.md](docs/get_the_meaning_blueprint_restore_roadmap.md)

## 基本流程

1. 在 Unreal 项目中使用 GetTheMeaning 插件导出数据。
2. 打开本工具，选择“绑定虚幻项目”并选择 `.uproject`。
3. 如果项目下存在 `Saved/GetTheMeaningExports`，工具会识别蓝图资产、C++ 索引和项目配置。
4. 在蓝图资产页选择蓝图和图表，创建草稿。
5. 草稿会优先使用节点级复原；如果导出数据缺少节点图表，会回落到执行线摘要图。
6. 可以在画布中查看、注释、整理、重命名、删除本地草稿。

## 当前范围

- Windows 和 Android Flutter 应用。
- 共享的 Dart 节点图数据模型。
- JSON 编码 / 解码基础服务。
- 桌面端和移动端共用的编辑器外壳。
- 为节点画布、引脚、连线、图文件保存加载流程打基础。

## 开发环境

Flutter SDK:

```text
C:\Users\liuyu\develop\flutter
```

如果当前终端还没有刷新 `PATH`，可以直接使用 Flutter 的完整路径：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' --version
```

Android 构建建议使用单独的 Gradle 缓存目录，避免和 Unreal 相关的全局 Gradle 配置冲突：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
```

## 常用命令

安装依赖：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' pub get
```

格式化：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\dart.bat' format .
```

静态分析：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' analyze
```

运行测试：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' test
```

构建 Windows 版本：

```powershell
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build windows
```

构建 Android 调试 APK：

```powershell
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
$env:GRADLE_USER_HOME='C:\Users\liuyu\.gradle_flutter'
& 'C:\Users\liuyu\develop\flutter\bin\flutter.bat' build apk --debug
```

## 节点图 JSON 结构

第一版计划使用 `.ubbridge.json` 文档，顶层结构类似下面这样：

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

其中：

- `graph` 保存图本身的标题、说明、创建时间、更新时间和视口信息。
- `nodes` 保存节点列表，包括节点位置、标题、说明、类型和引脚。
- `links` 保存连线列表，用于记录输出引脚到输入引脚之间的连接关系。

后续 Unreal 插件或其他工具可以读取这些 JSON，把它们作为蓝图设计草稿、逻辑说明文档或 AI 可读的节点参考数据。

## 本地辅助节点规范

- `Comment` 注释框只用于本地阅读、整理和给 AI/协作者解释蓝图区域。
- 注释框可以包住节点、拖动时带动内部节点，也可以手动拉伸或自动贴合内部节点。
- 后续如果把图同步或转换到 Unreal 蓝图，默认不把 `Comment` 当作正式逻辑节点同步；除非单独实现“同步注释框”选项，否则导出时应跳过注释框及其本地显示信息。
- 注释框的标题、说明、尺寸和颜色等信息都属于本地可视化信息，不应影响蓝图逻辑判断、连线合法性或运行行为。
