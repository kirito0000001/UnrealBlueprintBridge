# 虚幻：蓝图连结

`unreal_blueprint_bridge` 是一个基于 Flutter 的通用节点图 / 蓝图草稿编辑器，当前以 Windows 桌面端为主要使用平台，Android 保留为后续目标。

AI / 插件生成图包请先阅读：[AI_GRAPH_PACKAGE_GUIDE.md](AI_GRAPH_PACKAGE_GUIDE.md)

应用显示名称：`虚幻：蓝图连结`

Android 包名：`com.TFAC.unreal_blueprint_bridge`

当前版本专注于绘制蓝图风格的节点草稿、阅读 GetTheMeaning 导出结果、组织 AI 图例，以及保存 / 加载结构化 JSON 数据。它不会执行图逻辑，不会生成 Unreal 资产，也不会直接修改 `.uasset` 文件。

## 项目定位

这个工具用于把 Unreal 蓝图、AI 生成的图例、GetTheMeaning 插件导出的项目识别数据集中到一个可查看、可整理、可讨论的节点画布里。它更像“蓝图草稿本 + 项目逻辑阅读器”，不是 Unreal Editor 的替代品。

应用提供两种工作区：

- **Unreal 项目工作区**：选择 `.uproject` 后，把工作区路径设为项目 `Saved/BlueprintBridge` 下的 `.ubbridge` 路径，并定位 `Saved/GetTheMeaningExports`。
- **通用草稿工作区**：不依赖 Unreal 项目，用于绘制流程图、规则图、系统设计图或尚未落地的蓝图逻辑草稿。

两种工作区都只保存本地视觉草稿，不会把画布内容写回 Unreal 资产。

适合的使用场景：

- 和 AI 讨论蓝图逻辑，让 AI 输出结构化 `GraphIndex.json` 图包。
- 绑定 Unreal 项目后读取 `Saved/GetTheMeaningExports`，查看蓝图资产、函数、变量、事件和执行流。
- 从 GetTheMeaning 的 `*_Logic.json` 生成本地蓝图草稿，用于检查节点、引脚、连线和网络复制信息。
- 在不打开 Unreal 的情况下整理草稿、做注释框、框选节点、拖线、创建变量 / 函数 / 事件示意。

不适合的使用场景：

- 直接运行蓝图逻辑。
- 直接生成或修改 Unreal `.uasset` 文件。
- 作为 1:1 的 Unreal 蓝图编辑器替代。

## 功能说明

### 工作区与项目数据

- 可绑定 `.uproject`，自动建立 Unreal 项目工作区并定位 `Saved/GetTheMeaningExports`。
- 可创建不绑定 Unreal 的通用草稿项目，草稿保存在应用数据目录的 `Drafts` 下。
- 导入 GetTheMeaning 后，可按目录浏览蓝图资产，并查看资产路径、蓝图类型、父类、变量、函数、事件和图表摘要。
- 工作区状态、GetTheMeaning 导入摘要和画布草稿会保存到本地；重新打开应用或切换工作区时可以恢复。

### GetTheMeaning 蓝图阅读

- 读取 `ExportIndex.json`、`GraphIndex.json`、`CppSourceIndex.json` 和资产对应的 `*_Logic.json`。
- 资产详情可展示入口点、执行线、分支路径、函数调用参数、注释框、风险提示和部分 GameMode 默认值。
- 选择资产和图表后可以创建本地画布草稿：优先使用节点级复原，缺少完整节点数据时回落到执行线摘要图。
- 导入结果是只读参考数据；在本工具中整理草稿不会改变 GetTheMeaning 源文件或 Unreal 资产。

### 草稿画布

- 支持右键平移、左键框选、节点拖拽与删除、缩放、连线拖拽，以及输入引脚断开、替换和重连。
- 支持创建和调整 `Comment` 注释框；移动注释框时可以带动内部节点，也可以自动贴合内部节点。
- 节点目录提供 Unreal 风格的节点分类和搜索；从连线拖到空白处时可以继续选择兼容节点。
- 右侧面板提供成员列表、节点搜索、节点细节、变量细节、事件细节和函数细节。
- 变量支持创建、重命名、类型和复制选项，并可拖到画布生成 Get / Set 节点。
- 事件支持自定义事件、事件调用节点、RPC 类型与 Reliable 信息。
- 函数支持创建、重命名、输入输出参数和纯函数标记；当前独立函数视图仍是草稿编辑入口，不等同于 Unreal 函数图表写回。
- 画布变更会自动保存到当前工作区，也可以把当前草稿导出为 JSON 后再次导入。

### AI 图例协作

- 工作区页可复制完整的 AI 图包提示词，其中包含工作区名称、输出目录、协议要求和安全边界。
- 通用草稿工作区生成的是“触发入口”提示词；在用户给出具体需求前，AI 不应提前创建图包。
- Unreal 资产页可填写“图例需求”，选择具体函数或事件后复制提示词。提示词会带上资产名、资产路径、父类、图表名和最多 16 条执行线摘要。
- 应用可从 `GraphIndex.json` 导入一个或多个 `GraphDocument` 图文件，也可生成一份已知可用的示例图包作为格式参考。
- AI 图包只用于视觉说明和结构草稿，不会执行逻辑，也不会修改 `.uasset`。

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

## Unreal 项目阅读流程

1. 在 Unreal 项目中使用 GetTheMeaning 插件导出数据。
2. 打开本工具，选择“绑定虚幻项目”并选择 `.uproject`。
3. 如果项目下存在 `Saved/GetTheMeaningExports`，工具会识别蓝图资产、C++ 索引和项目配置。
4. 在蓝图资产页选择蓝图和图表，创建草稿。
5. 草稿会优先使用节点级复原；如果导出数据缺少节点图表，会回落到执行线摘要图。
6. 可以在画布中查看、注释、整理、重命名、删除本地草稿。

## AI 图例生成流程

1. 绑定 Unreal 项目，或者创建一个通用草稿项目。
2. 在工作区页复制完整提示词；如果要针对已有蓝图，可在蓝图资产页选择资产和图表，再填写“图例需求”。
3. 把提示词发送给 AI，并给出明确需求，例如“生成一个带权限检查的开门逻辑”。
4. AI 按 [AI_GRAPH_PACKAGE_GUIDE.md](AI_GRAPH_PACKAGE_GUIDE.md) 在提示词指定的输出目录生成 `GraphIndex.json` 和 `Graphs/*.json`。
5. 回到应用，从“草稿”菜单选择“导入 GraphIndex 图包”。也可以先选择“生成示例图包”查看已知可用的目录结构。
6. 在画布中检查节点、引脚和连线，并继续做本地注释与整理。

## 本地数据与 Windows 更新

- Windows 默认把应用状态、导入缓存、画布工作区和通用草稿保存在 `%APPDATA%\UnrealBlueprintBridge`。
- Unreal 项目的工作区路径设为 `Saved\BlueprintBridge\<ProjectName>.ubbridge`；AI 图包输出到同一个 `Saved\BlueprintBridge` 目录。
- “整体设置”提供 Windows 更新检查。程序会读取更新清单、比较版本、下载压缩包、校验大小和 SHA-256，再由外部脚本覆盖并重启。
- “制作发布版本”只在调试版本或通过 `ENABLE_RELEASE_TOOLS` 显式启用时出现，属于开发者工具，不是普通用户流程。
- Windows 更新方案详见 [docs/windows_hot_update.md](docs/windows_hot_update.md)。Android 不使用这套 PowerShell 覆盖更新机制。

## 当前限制

- 当前可用成品以 Windows 桌面端为主，Android 仍是后续目标。
- 工具不会运行蓝图逻辑，也不会生成或修改 Unreal `.uasset`。
- GetTheMeaning 复原、AI 图包和手工画布都是结构化草稿，不保证与 Unreal Editor 的节点尺寸和布局 1:1 一致。
- 函数独立视图、Widget UI 视觉布局和 C++ 索引跳转还没有完整接入。
- GraphDocument JSON 是本工具的数据交换格式，不是 Unreal 官方蓝图资产格式。

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

当前画布使用 `GraphDocument` JSON。`.ubbridge` 路径用于标识工作区，图文档的顶层结构类似下面这样：

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

其他工具可以读取这些 JSON，把它们作为蓝图设计草稿、逻辑说明文档或 AI 可读的节点参考数据；它们不能直接作为 Unreal 蓝图资产使用。

## 本地辅助节点规范

- `Comment` 注释框只用于本地阅读、整理和给 AI/协作者解释蓝图区域。
- 注释框可以包住节点、拖动时带动内部节点，也可以手动拉伸或自动贴合内部节点。
- 后续如果把图同步或转换到 Unreal 蓝图，默认不把 `Comment` 当作正式逻辑节点同步；除非单独实现“同步注释框”选项，否则导出时应跳过注释框及其本地显示信息。
- 注释框的标题、说明、尺寸和颜色等信息都属于本地可视化信息，不应影响蓝图逻辑判断、连线合法性或运行行为。
