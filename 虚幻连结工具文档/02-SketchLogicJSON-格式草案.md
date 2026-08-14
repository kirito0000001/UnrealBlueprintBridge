# SketchLogic.json 格式草案

版本：0.1  
日期：2026-07-07  
用途：虚幻蓝图连结工具的机器可读草图格式

## 1. 设计目标

`SketchLogic.json` 是虚幻蓝图连结工具的核心中间格式。

它要同时服务三类对象：

- WinUI 工具：保存、打开、显示画布。
- Codex / AI：稳定读取蓝图意图、连线、参数、风险提示。
- GetTheMeaning：把导出的蓝图 JSON 转成简化草图。

它不是 Unreal `.uasset` 的替代格式，也不是完整 Blueprint AST。它只保存“读懂逻辑和沟通实现”需要的信息。

## 2. 顶层结构

```json
{
  "schemaVersion": 1,
  "documentId": "sketch_20260707_001",
  "sketchName": "GM_PtoP_LoginFlow",
  "createdAt": "2026-07-07T10:30:00+08:00",
  "updatedAt": "2026-07-07T10:45:00+08:00",
  "source": {},
  "canvas": {},
  "nodes": [],
  "links": [],
  "commentGroups": [],
  "riskHints": [],
  "exports": {}
}
```

## 3. Source

`source` 记录草图来源。手动画布可以为空，GetTheMeaning 导入时应尽量填充。

```json
{
  "sourceKind": "GetTheMeaning",
  "unrealProjectName": "FantasyProject",
  "unrealProjectPath": "D:/UnrealMap/FantasyProject/FantasyProject.uproject",
  "assetPath": "/Game/BaseC/Mode/GM_MainMode",
  "assetName": "GM_MainMode",
  "assetClass": "Blueprint",
  "parentClass": "GameModeBase",
  "blueprintType": "Blueprint",
  "sourceFile": "D:/UnrealMap/FantasyProject/Saved/GetTheMeaningExports/Blueprints/GM_MainMode_Logic.json",
  "exportTime": "2026-07-07T09:58:00+08:00",
  "importedAt": "2026-07-07T10:30:00+08:00"
}
```

建议值：

- `sourceKind`: `Manual` / `GetTheMeaning` / `CodexGenerated` / `Clipboard` / `Unknown`
- `assetPath`: Unreal 资产路径。
- `sourceFile`: 被导入文件的原始路径。

## 4. Canvas

`canvas` 保存画布状态。它属于用户工作状态，但为了打开草图后恢复视图，可以保存在草图文件里。

```json
{
  "zoom": 0.92,
  "offset": { "x": -120.0, "y": 48.0 },
  "gridSize": 24,
  "layoutKind": "Manual",
  "selectedNodeId": "n_roc_anyone_login"
}
```

建议值：

- `layoutKind`: `Manual` / `ImportedAuto` / `LayeredExecFlow`

## 5. Node

节点是最重要的数据单元。

```json
{
  "id": "n_ros_login",
  "type": "rpc_event",
  "title": "ROS_Login",
  "subtitle": "RunOnServer / Reliable",
  "graphName": "EventGraph",
  "position": { "x": 120.0, "y": 80.0 },
  "size": { "width": 260.0, "height": 120.0 },
  "ports": [],
  "parameters": [],
  "metadata": {},
  "source": {},
  "notes": "客户端请求登录。"
}
```

### 5.1 Node.type

第一版建议支持：

```text
event
rpc_event
function_entry
function_call
rpc_call
branch
sequence
get_variable
set_variable
for_each_loop
for_each_loop_with_break
return
create_widget
add_to_viewport
data_table_lookup
struct_make
struct_break
enum_switch
comment
note
unknown
```

### 5.2 Node.metadata

`metadata` 用于 Unreal 语义。

```json
{
  "replication": "RunOnServer",
  "reliable": true,
  "isPure": false,
  "isLatent": false,
  "category": "Login",
  "memberParent": "GM_PtoP_C",
  "functionName": "JudgeRoom"
}
```

常见字段：

- `replication`: `None` / `RunOnServer` / `RunOnOwningClient` / `NetMulticast`
- `reliable`: true / false
- `isPure`: 是否纯函数。
- `functionName`: 所属函数。
- `memberParent`: 所属类。

### 5.3 Node.source

导入来源信息。这个字段用于回查原始导出。

```json
{
  "tool": "GetTheMeaning",
  "originalNodeId": "K2Node_CustomEvent_12",
  "originalNodeTitle": "ROS_Login",
  "originalNodeClass": "K2Node_CustomEvent",
  "assetPath": "/Game/BaseC/Mode/GM_MainMode",
  "lineHint": 238
}
```

`lineHint` 只是辅助，不作为权威定位。

## 6. Port

端口保存执行入口、执行出口、数据入口、数据出口。

```json
{
  "id": "then",
  "name": "Then",
  "direction": "Output",
  "kind": "Exec",
  "dataType": "exec"
}
```

字段：

- `id`: 节点内稳定端口 ID。
- `name`: 显示名。
- `direction`: `Input` / `Output`
- `kind`: `Exec` / `Data`
- `dataType`: `bool` / `int` / `float` / `string` / `text` / `object` / `struct:PlayerData` / `enum:EGameStage` 等。

Branch 示例：

```json
[
  { "id": "exec_in", "name": "Exec", "direction": "Input", "kind": "Exec", "dataType": "exec" },
  { "id": "condition", "name": "Condition", "direction": "Input", "kind": "Data", "dataType": "bool" },
  { "id": "true", "name": "True", "direction": "Output", "kind": "Exec", "dataType": "exec" },
  { "id": "false", "name": "False", "direction": "Output", "kind": "Exec", "dataType": "exec" }
]
```

## 7. Parameter

参数用于显示函数调用、RPC 调用、变量设置的输入输出。

```json
{
  "name": "ReturnV",
  "direction": "Input",
  "dataType": "text",
  "isLinked": false,
  "defaultValue": "",
  "displayValue": "空文本",
  "sourcePortId": null,
  "notes": "成功路径应为空。"
}
```

字段：

- `name`: 参数名。
- `direction`: `Input` / `Output`
- `dataType`: 类型。
- `isLinked`: 是否有数据线连接。
- `defaultValue`: 原始默认值。
- `displayValue`: 给人看的值。
- `sourcePortId`: 如果从本节点某个端口映射，可填写。
- `notes`: 备注。

这个结构能解决一个关键问题：即使参数没有连线，也能明确看到默认值。例如 `NowNum = 0` 或 `ReturnV = 未找到UID信息`。

## 8. Link

连线是执行流和数据流的核心。

```json
{
  "id": "l_001",
  "kind": "Exec",
  "from": { "nodeId": "n_ros_login", "portId": "then" },
  "to": { "nodeId": "n_find_uid", "portId": "exec_in" },
  "label": "",
  "source": {}
}
```

字段：

- `kind`: `Exec` / `Data` / `Comment` / `Reference`
- `from.nodeId`
- `from.portId`
- `to.nodeId`
- `to.portId`
- `label`: 可选显示文字。

数据线示例：

```json
{
  "id": "l_condition",
  "kind": "Data",
  "from": { "nodeId": "n_text_is_empty", "portId": "return_value" },
  "to": { "nodeId": "n_branch_login_result", "portId": "condition" },
  "label": "bool"
}
```

多输入执行线不需要特殊结构。只要多个 link 的 `to.nodeId` 和 `to.portId` 相同即可：

```json
[
  {
    "id": "l_eight_to_set_stage",
    "kind": "Exec",
    "from": { "nodeId": "n_set_mode_eight", "portId": "then" },
    "to": { "nodeId": "n_set_game_stage", "portId": "exec_in" }
  },
  {
    "id": "l_ptop_to_set_stage",
    "kind": "Exec",
    "from": { "nodeId": "n_set_mode_ptop", "portId": "then" },
    "to": { "nodeId": "n_set_game_stage", "portId": "exec_in" }
  }
]
```

UI 和 Markdown 应把这种情况显示成：

```text
Incoming Exec:
- Set GameModeType (Eight) -> Exec
- Set GameModeType (PtoP) -> Exec
```

## 9. CommentGroup

注释框用于保留 UE 蓝图里的大段说明。

```json
{
  "id": "cg_c_key_column",
  "title": "C 键位框柱",
  "text": "按 C 时显示框柱相关提示和目标选择流程。",
  "bounds": { "x": 80.0, "y": 40.0, "width": 920.0, "height": 520.0 },
  "nodeIds": ["n_input_c", "n_branch_has_target", "n_show_column"],
  "source": {
    "originalNodeId": "EdGraphNode_Comment_4"
  }
}
```

Markdown 导出时，建议按 CommentGroup 分段：

```text
## 注释组：C 键位框柱
包含节点：
- Input C
- Branch HasTarget
- ShowColumn
```

## 10. RiskHint

风险提示用于把 GetTheMeaning 或 WinUI 工具发现的问题挂到节点、连线或整个草图上。

```json
{
  "id": "risk_returnv_success_non_empty",
  "severity": "Warning",
  "title": "成功路径 ReturnV 非空",
  "message": "ROC_AnyoneLogin 成功路径传入 ReturnV = 未找到UID信息，PC 侧如果用 TextIsEmpty 判断成功，会走失败提示。",
  "target": {
    "kind": "Node",
    "nodeId": "n_roc_anyone_login_call",
    "portId": "ReturnV"
  },
  "confidence": "NeedsReview",
  "source": "GetTheMeaning"
}
```

建议字段：

- `severity`: `Info` / `Warning` / `Error`
- `confidence`: `Certain` / `Likely` / `NeedsReview`
- `target.kind`: `Document` / `Node` / `Link` / `Parameter` / `CommentGroup`

第一版风险提示只提示，不自动修改草图。

## 11. Exports

`exports` 记录最近导出文件，方便 UI 显示和复制路径。

```json
{
  "lastReadableMarkdown": "Exports/Sketch_Readable.md",
  "lastMermaid": "Exports/Sketch.mmd",
  "lastExportedAt": "2026-07-07T10:45:00+08:00"
}
```

这不是核心逻辑，不应被 AI 当作蓝图内容。

## 12. 完整小例子

```json
{
  "schemaVersion": 1,
  "documentId": "sketch_login_001",
  "sketchName": "ROC_AnyoneLogin_Result",
  "createdAt": "2026-07-07T10:30:00+08:00",
  "updatedAt": "2026-07-07T10:45:00+08:00",
  "source": {
    "sourceKind": "GetTheMeaning",
    "unrealProjectName": "FantasyProject",
    "assetPath": "/Game/BaseC/Mode/GM_PtoP",
    "assetName": "GM_PtoP",
    "sourceFile": "D:/UnrealMap/FantasyProject/Saved/GetTheMeaningExports/Blueprints/GM_PtoP_Logic.json"
  },
  "canvas": {
    "zoom": 1.0,
    "offset": { "x": 0, "y": 0 },
    "gridSize": 24,
    "layoutKind": "ImportedAuto"
  },
  "nodes": [
    {
      "id": "n_ros_login",
      "type": "rpc_event",
      "title": "ROS_Login",
      "subtitle": "RunOnServer / Reliable",
      "graphName": "EventGraph",
      "position": { "x": 80, "y": 100 },
      "size": { "width": 260, "height": 120 },
      "ports": [
        { "id": "then", "name": "Then", "direction": "Output", "kind": "Exec", "dataType": "exec" }
      ],
      "parameters": [
        { "name": "User", "direction": "Input", "dataType": "string", "isLinked": true },
        { "name": "Password", "direction": "Input", "dataType": "string", "isLinked": true }
      ],
      "metadata": {
        "replication": "RunOnServer",
        "reliable": true
      },
      "source": {
        "tool": "GetTheMeaning",
        "originalNodeId": "K2Node_CustomEvent_12"
      },
      "notes": ""
    },
    {
      "id": "n_call_roc_anyone_login",
      "type": "rpc_call",
      "title": "ROC_AnyoneLogin",
      "subtitle": "Server -> Owning Client",
      "graphName": "EventGraph",
      "position": { "x": 420, "y": 100 },
      "size": { "width": 300, "height": 160 },
      "ports": [
        { "id": "exec_in", "name": "Exec", "direction": "Input", "kind": "Exec", "dataType": "exec" },
        { "id": "then", "name": "Then", "direction": "Output", "kind": "Exec", "dataType": "exec" }
      ],
      "parameters": [
        {
          "name": "ReturnV",
          "direction": "Input",
          "dataType": "text",
          "isLinked": false,
          "defaultValue": "未找到UID信息",
          "displayValue": "未找到UID信息",
          "notes": "如果这是成功路径，应改为空文本。"
        }
      ],
      "metadata": {
        "replication": "RunOnOwningClient",
        "reliable": true
      },
      "source": {
        "tool": "GetTheMeaning",
        "originalNodeId": "K2Node_CallFunction_88"
      },
      "notes": ""
    }
  ],
  "links": [
    {
      "id": "l_login_to_result",
      "kind": "Exec",
      "from": { "nodeId": "n_ros_login", "portId": "then" },
      "to": { "nodeId": "n_call_roc_anyone_login", "portId": "exec_in" }
    }
  ],
  "commentGroups": [],
  "riskHints": [
    {
      "id": "risk_returnv_success_non_empty",
      "severity": "Warning",
      "title": "成功路径 ReturnV 非空",
      "message": "ReturnV 默认值为未找到UID信息。若 PC 侧用 TextIsEmpty 判断成功，会误判为失败。",
      "target": {
        "kind": "Parameter",
        "nodeId": "n_call_roc_anyone_login",
        "portId": "ReturnV"
      },
      "confidence": "NeedsReview",
      "source": "GetTheMeaning"
    }
  ],
  "exports": {}
}
```

## 13. Markdown 导出建议

`Sketch_Readable.md` 可以从同一 JSON 生成。建议结构：

```text
# GM_PtoP - ROC_AnyoneLogin_Result

AssetPath: /Game/BaseC/Mode/GM_PtoP
Source: GetTheMeaning

## Nodes
- ROS_Login [RPC Event] RunOnServer / Reliable
- ROC_AnyoneLogin [RPC Call] RunOnOwningClient / Reliable

## Exec Flow
ROS_Login -> ROC_AnyoneLogin

## Incoming Exec Links
ROC_AnyoneLogin:
- ROS_Login.Then -> Exec

## Call Parameters
ROC_AnyoneLogin
- ReturnV: linked=false, defaultValue=未找到UID信息

## Risks
- Warning: 成功路径 ReturnV 非空
```

## 14. 版本兼容策略

第一版写 `schemaVersion = 1`。

以后字段增加时：

- 不删除旧字段。
- 新字段允许缺省。
- 读取未知 `node.type` 时按 `unknown` 显示。
- 读取未知 `link.kind` 时保留原始值，但 UI 可显示为 Reference。
- 保存时尽量保留 `source` 和未知 metadata。

## 15. 和 GetTheMeaning JSON 的关系

GetTheMeaning JSON 是“蓝图导出事实”。  
SketchLogic JSON 是“用于画布和沟通的简化逻辑模型”。

两者不应该强行合并成一个格式。

导入时：

- GetTheMeaning 的完整节点信息可以放在 `source.rawSummary` 或单独保存在 `Imports`。
- SketchLogic 只保留画布和理解必需字段。
- 如果后续需要回查细节，通过 `sourceFile + originalNodeId` 找回原始导出。

这样可以避免 WinUI 草图文件越来越大，也能避免因为 GetTheMeaning 插件以后升级字段而破坏草图工具。

