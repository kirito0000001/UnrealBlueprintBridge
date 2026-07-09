# GetTheMeaning 蓝图复原方向标

## 目标

从 `Saved/GetTheMeaningExports` 读取 Unreal 蓝图导出数据，在 UnrealBlueprintBridge 中生成可查看、可整理、可供 AI 讨论的本地图表草稿。

第一阶段目标是“只读复原”：尽量还原蓝图图表中的节点、坐标、引脚、执行线、数据线、变量、事件、函数和网络复制信息。它不负责写回 `.uasset`，也不承诺 1:1 还原 Unreal 内部节点行为。

## 当前导出数据判断

`*_Logic.json` 已经包含第一版复原所需的主要信息：

- 资产信息：蓝图名、路径、蓝图类型、父类、生成类。
- 图表信息：`EventGraph`、函数图表、构造脚本等。
- 节点信息：节点 id、UE 节点 class、标题、摘要、坐标。
- 引脚信息：pin id、名称、方向、是否执行引脚、类型、默认值、连接目标。
- 连线信息：执行线和数据线。
- 成员信息：变量、事件、函数、RPC、网络复制、RepNotify。
- 辅助信息：GameMode 默认类、WidgetTree、DataTable、Struct、AssetReference、C++ 索引。

因此，缺口主要在 Flutter 工具侧：之前只读取 `logicSummary.controlFlows` 生成执行线摘要图，没有直接把 `graphs[].nodes` 和 `graphs[].links` 转成 `GraphDocument`。

## 第一阶段实现范围

- 新增节点级转换器：`BlueprintLogicGraphDocumentBuilder`。
- 从 `graphs[].nodes` 生成画布节点。
- 从 `graphs[].links` 生成画布连线。
- 从 `variables / events / functions` 写入右侧成员面板。
- 保留原始 UE class、summary、变量复制、事件 RPC、函数输入输出等可读信息。
- 没有节点级 graph 数据时，回落到旧的执行线摘要生成。

## 暂不做

- 不写回 Unreal `.uasset`。
- 不把注释框当作必须同步到 Unreal 的数据。注释框只作为本地查看和整理用途。
- 不做 Widget 蓝图可视布局 1:1 复原。WidgetTree 后续单独做 UI 树/布局预览。
- 不强行模拟所有 UE 节点的动态引脚规则。只保留导出时已有的引脚和连线。

## 后续路线

1. 节点级只读复原。
2. 细节面板显示 UE 原始 class、summary、导出来源、网络复制、变量类型等信息。
3. WidgetTree 独立视图。
4. C++ 索引接入，节点/函数可跳到 C++ 定义或蓝图暴露函数说明。
5. AI 生成图包时优先参考节点级复原数据，而不是只参考文字摘要。
