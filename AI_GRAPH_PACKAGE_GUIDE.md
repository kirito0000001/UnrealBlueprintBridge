# AI Graph Package Guide

## 中文快速说明

这份文件是“虚幻：蓝图连结”的 AI 图包生成协议。应用本身不会调用 AI API；它会根据当前工作区、资产和图表整理提示词并复制到剪贴板，再由用户发送给外部 AI。AI 最终写入的是可导入本应用的视觉 / 结构草稿，不是可执行蓝图，也不是 Unreal 资产。

### 三种提示词入口

1. **Unreal 项目工作区提示词**：包含项目名称、`.uproject` 路径、图包输出目录、文件要求和安全边界，适合从项目层级开始讨论蓝图逻辑。
2. **通用草稿工作区提示词**：只建立生成协议和触发方式。它是给后续对话使用的入口；在用户给出具体需求前，不应创建 `GraphIndex.json` 或 `Graphs/*.json`。
3. **资产 / 图表提示词**：针对选中的蓝图资产和函数、事件或图表，包含 `assetName`、`assetPath`、`parentClass`、`graphName`、用户填写的“图例需求”，以及最多 16 条可用的执行线摘要。

### 从提示词到画布

1. 在应用中创建草稿项目或绑定 Unreal 项目。
2. 复制工作区提示词；如果目标是已有蓝图，则在蓝图资产页选择具体图表、填写“图例需求”，再点击“复制此图例提示词”。
3. 把提示词和明确需求发送给 AI，并要求 AI 先阅读本文件。
4. AI 在提示词指定的目录生成 `GraphIndex.json` 和一个或多个 `Graphs/*.json`，然后校验 JSON、节点、引脚和连线引用。
5. 回到应用，从“草稿”菜单选择“导入 GraphIndex 图包”。如果需要格式参考，可先选择“生成示例图包”。

### 必须遵守的边界

- 只生成 `GraphIndex.json` 和 `Graphs/*.json` 图包文件。
- 生成结果只用于视觉说明、结构讨论和本地草稿编辑。
- 不执行蓝图逻辑，不启动 Unreal，不生成或修改 `.uasset`。
- 不把推测的运行行为伪装成已经存在的 Unreal 实现；缺少信息时，应在说明中明确标注假设。
- 面向用户的名称、标题和说明使用中文；必须与 Unreal / C++ 源数据匹配的标识符可以保留原文，并补充中文解释。

项目功能与完整使用流程见 [README.md](README.md)。下面的英文正文是 AI 需要遵守的字段和文件协议。

This file is the first place an AI agent should read when it needs to generate
BlueprintBridge graph packages for `虚幻：蓝图连结`.

The app does not execute graph logic and does not modify Unreal `.uasset` files.
Generated files are visual / structural drafts that the app can import and show
on the node canvas.

## Trigger Workflow

Some prompts copied from the app are trigger entries for another AI
conversation. If a copied prompt says it is only a trigger entry, do not create
`GraphIndex.json` or `Graphs/*.json` yet. Wait until the user sends a concrete
request, usually in this form:

```text
触发图例生成：目标工作区「<WorkspaceName>」，需求：<写清楚要画的蓝图逻辑>。
```

After the trigger request is clear, generate only the BlueprintBridge graph
package files described below. Do not modify Unreal assets and do not run game
logic.

## Chinese Naming And Description Rules

User-facing names and descriptions must be written in Chinese.

- Names may be short or abbreviated, but they must remain understandable in the
  current graph context.
- Descriptions must clearly explain the purpose, trigger condition, important
  state changes, side effects, and network / authority notes when relevant.
- Use Chinese for `title`, `description`, `purpose`, graph titles, node titles,
  pin titles, link titles, variable display names, and function display names.
- Stable internal ids such as graph ids, node ids, pin ids, link ids, and file
  names may stay ASCII / English to keep imports stable.
- Preserve exact Unreal, C++, Blueprint, enum, class, function, variable, and
  pin identifiers when they must match source data or engine behavior, but add
  a clear Chinese explanation in `description`.

## Output Location

For a desktop Unreal project, write the package beside the `.ubbridge` workspace
file:

```text
<UnrealProject>\Saved\BlueprintBridge\
  GraphIndex.json
  Graphs\
    <AssetName>_<GraphName>.json
```

Example:

```text
D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\
  GraphIndex.json
  Graphs\
    GM_MainMode_UserLogin.json
```

The app imports this from `草稿 -> 导入 GraphIndex 图包`.

## Required Files

Every package must contain:

- `GraphIndex.json`
- one or more graph files under `Graphs/`

`GraphIndex.json` lists graph files. Each graph file uses the app's
`GraphDocument` JSON format.

## GraphIndex.json

```json
{
  "schemaVersion": 1,
  "graphs": [
    {
      "id": "gm_mainmode_userlogin",
      "title": "GM_MainMode / UserLogin",
      "assetName": "GM_MainMode",
      "assetPath": "/Game/BaseC/Mode/GM_MainMode.GM_MainMode",
      "graphName": "UserLogin",
      "source": "ai-generated",
      "purpose": "explain-blueprint-flow",
      "file": "Graphs/GM_MainMode_UserLogin.json"
    }
  ]
}
```

Required fields per graph:

- `assetName`: readable Unreal asset name.
- `assetPath`: Unreal asset path. Use this to distinguish same-name assets.
- `graphName`: function, event, macro, or slice name.
- `file`: path to the graph JSON file relative to the package root.

Recommended fields:

- `id`: stable lowercase id, using letters, numbers, and underscores.
- `title`: readable title, usually `<AssetName> / <GraphName>`.
- `source`: `ai-generated`, `get-the-meaning`, `manual`, or `app-template`.
- `purpose`: short reason for this graph.

## GraphDocument File

```json
{
  "schemaVersion": 1,
  "graph": {
    "id": "gm_mainmode_userlogin",
    "title": "GM_MainMode / UserLogin",
    "description": "UserLogin execution-flow explanation.",
    "blueprintType": "ActorBlueprint",
    "parentClass": "Actor",
    "createdAt": "2026-07-07T12:00:00+08:00",
    "updatedAt": "2026-07-07T12:00:00+08:00",
    "viewport": {
      "offsetX": 48,
      "offsetY": 48,
      "zoom": 0.9
    }
  },
  "nodes": [
    {
      "id": "node_event_userlogin",
      "nodeType": "Event",
      "title": "Event: UserLogin",
      "description": "Entry point.",
      "position": {
        "x": 80,
        "y": 140
      },
      "size": {
        "width": 260,
        "height": 150
      },
      "pins": [
        {
          "id": "then",
          "direction": "output",
          "title": "Then",
          "dataType": "exec",
          "allowMultipleLinks": false
        }
      ]
    }
  ],
  "links": []
}
```

Recommended `graph.blueprintType` values:

- `ActorBlueprint`
- `WidgetBlueprint`
- `FunctionLibrary`
- `ComponentBlueprint`
- `ObjectBlueprint`

Use `graph.parentClass` for the Unreal parent class, such as `Actor`,
`UserWidget`, `ActorComponent`, or `Object`.

## Node Rules

Each node must contain:

- `id`: unique inside this graph.
- `nodeType`: short category, for example `Event`, `FunctionCall`, `Branch`,
  `Variable`, `Widget`, `Comment`, `DataTable`, `Struct`, or `RPC`.
- `title`: human-readable node title.
- `description`: explain what this node does and why it matters.
- `position`: `{ "x": number, "y": number }`.
- `size`: `{ "width": number, "height": number }`.
- `pins`: list of input and output pins.

Recommended layout:

- Use left-to-right execution flow.
- Start at `x = 80`.
- Increase `x` by about `320` to `380` for each execution step.
- Split Branch True / False paths vertically.
- Keep important labels in `title`; put details in `description`.

## Pin Rules

Pin format:

```json
{
  "id": "exec_in",
  "direction": "input",
  "title": "Exec",
  "dataType": "exec",
  "allowMultipleLinks": false
}
```

Rules:

- `direction` must be `input` or `output`.
- Execution pins should use `dataType: "exec"`.
- Data pins can use Unreal-like names such as `bool`, `int`, `float`,
  `string`, `text`, `object`, `class`, `struct`, or `enum`.
- Pin ids must be unique inside their node.

## Link Rules

Link format:

```json
{
  "id": "link_branch_true",
  "fromNodeId": "node_branch",
  "fromPinId": "true",
  "toNodeId": "node_success",
  "toPinId": "exec_in",
  "title": "True",
  "description": "Condition passed.",
  "linkType": "exec"
}
```

Rules:

- Every link must connect an output pin to an input pin.
- `fromNodeId` and `toNodeId` must reference existing node ids.
- `fromPinId` and `toPinId` must reference existing pin ids.
- Execution links should use `linkType: "exec"`.
- Data links should use `linkType: "data"`.
- Branch links should set `title` to `True` or `False`.

## AI Generation Checklist

Before finishing, verify:

- `GraphIndex.json` is valid JSON.
- Every `graphs[].file` exists.
- Every graph file is valid JSON.
- Every node id is unique inside its graph.
- Every pin id is unique inside its node.
- Every link references existing nodes and pins.
- Execution links go from output exec pins to input exec pins.
- Branch nodes have clearly labeled `True` and `False` output pins.
- Asset identity is clear through `assetName` and `assetPath`.
- The graph is readable left-to-right without overlapping nodes.

## Copyable AI Prompt

Use this prompt when asking an AI agent to generate a graph package:

```text
Generate a BlueprintBridge graph package for 虚幻：蓝图连结.

Read AI_GRAPH_PACKAGE_GUIDE.md first and obey it exactly.

Output:
- GraphIndex.json
- Graphs/<AssetName>_<GraphName>.json

Requirements:
- Use schemaVersion 1.
- Use GraphDocument JSON for every graph file.
- Use stable node ids, pin ids, and link ids.
- Use left-to-right layout.
- Use Branch nodes with True and False output pins when needed.
- User-facing names, titles, and descriptions must be Chinese; names may be
  abbreviated, but description must clearly explain purpose, trigger condition,
  state changes, side effects, and relevant network / authority notes.
- Do not modify Unreal .uasset files.
- Do not invent executable behavior; this is only a visual draft.

After writing files, check that every link references existing nodes and pins.
```

## App Test Shortcut

Inside the app, use:

```text
草稿 -> 生成示例图包
```

This writes a small known-good package and imports it immediately. Use it as the
reference shape when generating new packages.
