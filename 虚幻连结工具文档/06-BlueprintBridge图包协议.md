# BlueprintBridge 图包协议

更新时间：2026-07-08 00:25:00 +08:00

## 1. 目标

这一步先让 `虚幻：蓝图连结` 可以读懂外部生成的节点图包。

图包的定位是通用桥梁：

- GetTheMeaning 插件以后可以生成它。
- Codex / AI 可以生成它。
- 其他项目也可以生成它。
- Flutter 程序读取后会把图包转换成现有画布草稿。
- 第一版只负责“读懂和显示”，不执行逻辑，也不修改 `.uasset`。

## 2. 默认目录

PC 端第一版默认读取当前工作区文件所在目录。

以 FantasyProject 为例：

```text
D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\
  FantasyProject.ubbridge
  GraphIndex.json
  Graphs\
    GM_MainMode_UserLogin.json
```

程序概览页会显示 `图包协议` 路径，方便确认当前默认读取位置。

## 3. 目录结构

```text
Saved\BlueprintBridge\
  GraphIndex.json
  Graphs\
    <GraphFile>.json
```

`GraphIndex.json` 是入口索引。

`Graphs/*.json` 是实际画布文件，继续复用当前程序已经支持的 `GraphDocument` 格式。

## 4. GraphIndex.json 格式

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
      "purpose": "example",
      "file": "Graphs/GM_MainMode_UserLogin.json"
    }
  ]
}
```

当前读取时真正使用的字段：

- `assetName`：画布草稿所属资产名。
- `assetPath`：画布草稿所属资产路径，也是区分同名蓝图的重要字段。
- `graphName`：函数 / 事件 / 切片名称。
- `file`：相对于图包根目录的图文件路径。
- `title`：缺省情况下可辅助推断资产名和图名。

当前会保留但暂不参与逻辑的字段：

- `id`
- `source`
- `purpose`

这些字段以后可以用于区分 AI 生成、插件生成、用户手工整理、教程示例等来源。

## 5. GraphDocument 图文件

每个 `Graphs/*.json` 文件第一版直接使用现有 `GraphDocument`：

```json
{
  "schemaVersion": 1,
  "graph": {
    "id": "graph_userlogin",
    "title": "GM_MainMode / UserLogin",
    "description": "UserLogin 流程示意",
    "createdAt": "2026-07-07T12:00:00+08:00",
    "updatedAt": "2026-07-07T12:10:00+08:00",
    "viewport": {
      "offsetX": 80,
      "offsetY": 64,
      "zoom": 0.9
    }
  },
  "nodes": [],
  "links": []
}
```

节点、引脚、连线字段继续沿用程序内部模型：

- `nodes` 对应节点。
- `nodes[].pins` 对应输入 / 输出引脚。
- `links` 对应连线。
- `position` 和 `size` 控制画布布局。

## 6. 程序读取行为

已实现：

- 顶栏 `草稿` 菜单新增 `导入 GraphIndex 图包`。
- 程序会读取当前工作区 `Saved\BlueprintBridge\GraphIndex.json`。
- 程序会按索引读取 `Graphs/*.json`。
- 每个有效图文件会转换成一个 `CanvasDraft`。
- 导入后会进入 `画布` 页面。
- 导入结果会保存到当前工作区画布缓存。
- 如果 `GraphIndex.json` 不存在，会提示缺少索引。
- 如果某个图文件缺失，会跳过该文件并给出 warning，不会让整个导入崩溃。
- 如果图文件 JSON 格式错误，会跳过该文件并给出 warning。

## 7. 当前限制

- 第一版没有文件选择器，只读当前工作区默认图包目录。
- 第一版没有图包导出器。
- 第一版不会合并 GraphIndex 里的来源、标签、分组等元数据到 UI。
- 第一版同 key 草稿会覆盖旧草稿，这是为了方便重新生成同一张图后刷新。
- Android 端后续要改成读取应用私有目录或系统选择器选择的目录。

## 8. 2026-07-07 进展：示例图包样板

已完成：

- 顶栏 `草稿` 菜单新增 `生成示例图包`。
- 程序会在当前 `图包协议` 目录写入 `GraphIndex.json`。
- 程序会在 `Graphs` 子目录写入 `ExampleBlueprint_ExampleFlow.json`。
- 写完后会自动调用 `导入 GraphIndex 图包`。
- 示例图会进入现有画布草稿系统。
- 示例图包含 4 个节点：
  - `Event: ExampleStart`
  - `Branch: Has Data?`
  - `Call: Build Success Result`
  - `Call: Show Error Message`
- 示例图包含 3 条执行线：
  - 入口到 Branch
  - Branch True 到成功路径
  - Branch False 到失败路径

这一步的用途：

- 给 Codex / AI 一个可复制的图包生成样板。
- 给 GetTheMeaning 插件以后导出 BlueprintBridge 图包提供参考。
- 让用户能在没有外部插件支持时直接测试协议读取和画布显示。

当前实现取舍：

- 示例图会覆盖同名 `GraphIndex.json` 和 `Graphs/ExampleBlueprint_ExampleFlow.json`。
- 示例图只表达节点、引脚、执行线，不包含真实 Unreal 资产引用。
- 第一版没有生成多文件示例，避免样板变复杂。

## 9. 下一步建议

下一步可以做“AI / 插件生成规则提示词”：

- 在程序内提供一个示例 `GraphIndex.json`。
- 提供一个最小 `Graphs/Example.json`。
- 在文档里写明 Codex 生成图包时必须遵守的字段。
- 后续 GetTheMeaning 插件可以按这个协议直接输出图包。

再下一步才继续改善连线可读性：

- 节点按执行链自动布局。
- Branch 的 True / False 出线更直观。
- 函数调用参数表转成节点旁注。
- 多输入执行线在画布上明确显示汇合关系。

## 10. 2026-07-07 进展：AI 图包生成指南

已完成：

- 项目根目录新增 `AI_GRAPH_PACKAGE_GUIDE.md`。
- `README.md` 顶部新增 AI / 插件生成图包指南链接。
- 指南采用英文文件名，方便 AI、脚本、GitHub 和跨平台路径识别。
- 指南内容以“生成规则”为主，而不是普通说明文：
  - 输出目录。
  - 必需文件。
  - `GraphIndex.json` 模板。
  - `GraphDocument` 模板。
  - 节点规则。
  - 引脚规则。
  - 连线规则。
  - AI 生成前检查清单。
  - 可复制 AI Prompt。

这一步的目的：

- 让后续 Codex 对话或其他 AI 一进入仓库就知道该读哪份协议。
- 让 GetTheMeaning 插件以后输出 BlueprintBridge 图包时有稳定参考。
- 让图包生成行为更像“协议执行”，而不是靠聊天上下文猜。

给其他 AI 的最短提示可以是：

```text
请先阅读项目根目录 AI_GRAPH_PACKAGE_GUIDE.md，然后按其中协议生成 BlueprintBridge 图包。
不要修改 Unreal .uasset，只输出 GraphIndex.json 和 Graphs/*.json。
```

## 11. 2026-07-07 进展：程序内可复制 AI 提示词

已完成：

- 概览页新增 `AI 图例生成提示词` 卡片。
- 卡片内会显示当前工作区专属提示词。
- 提示词会包含：
  - 当前项目名。
  - Unreal 项目路径。
  - 当前图包输出目录。
  - `AI_GRAPH_PACKAGE_GUIDE.md` 阅读要求。
  - `GraphIndex.json` 和 `Graphs/*.json` 输出要求。
  - 不修改 `.uasset` 的限制。
  - 检查 node id / pin id / link 引用的要求。
- 卡片提供 `复制提示词` 按钮。
- 复制成功后只提示 `已复制 AI 图例生成提示词`，不会把大段提示词塞进提示条。

实现文件：

- `lib/core/workspace/ai_graph_prompt_builder.dart`
- `lib/features/workspace/ai_graph_prompt_panel.dart`

这一步的意义：

- 用户不用去仓库里找 Markdown，也不用记提示词。
- PC 端可以直接复制给当前 Codex / 其他 AI 对话。
- 以后移动端也可以复用这个卡片，只要能分享 / 复制文本即可。

下一步建议：

- 做“选择资产 / 函数后生成针对性提示词”。
- 现在提示词是工作区级别，适合生成任意图包。
- 后续可以在蓝图资产详情页加一个 `复制此函数图例提示词`，自动带上资产路径、函数名、已有执行线摘要和导出目录。

## 12. 2026-07-08 进展：资产 / 函数级 AI 提示词

已完成：

- 蓝图资产详情页的逻辑切片区域新增 `复制此图例提示词`。
- 当选择 `全部` 时，提示词会面向当前资产的全部执行线。
- 当选择某个函数 / 事件切片时，提示词会面向当前资产的当前切片。
- 提示词会自动带上：
  - AssetName。
  - AssetPath。
  - ParentClass。
  - GraphName。
  - 图包输出目录。
  - 推荐输出文件名。
  - 执行线摘要。
  - 不修改 `.uasset` 的限制。
  - 检查 node id / pin id / link 引用的要求。
- 复制成功后统一提示 `已复制 AI 图例生成提示词`。

实现文件：

- `lib/core/workspace/ai_graph_prompt_builder.dart`
- `lib/features/workspace/ai_graph_prompt_panel.dart`
- `lib/features/workspace/blueprint_assets_view.dart`

这一步的用途：

- 用户不需要手工描述“给哪个蓝图的哪个函数画图”。
- 程序会把当前上下文拼进提示词。
- AI 能更稳定地生成只针对当前函数 / 事件的 `GraphIndex.json` 和 `Graphs/*.json`。

下一步建议：

- 做“从提示词生成结果一键导入”的辅助流程。
- 例如复制提示词后，用户让 AI 生成图包文件，再点 `导入 GraphIndex 图包`。
- 后续可以进一步做“监控图包目录，有新 GraphIndex 自动提示导入”。

## 13. 2026-07-08 进展：轻量自然语言图例需求

已完成：

- 蓝图资产详情页的逻辑切片区域新增 `图例需求` 输入框。
- 用户可以输入自然语言需求，例如：

```text
生成一个开门逻辑
```

- 点击 `复制此图例提示词` 时，提示词会自动包含：
  - 当前资产上下文。
  - 当前函数 / 事件切片。
  - 当前执行线摘要。
  - 用户输入的自然语言需求。
  - 图包输出目录和文件要求。

这一步仍然是轻量版：

- 程序不直接调用 AI。
- 程序不自动生成 JSON。
- 程序只是把当前上下文和用户需求拼成更完整的提示词。

建议使用方式：

1. 在蓝图页选择资产。
2. 选择某个函数 / 事件切片。
3. 在 `图例需求` 输入框写需求。
4. 点击 `复制此图例提示词`。
5. 把提示词发给 AI，让 AI 输出 `GraphIndex.json` 和 `Graphs/*.json`。
6. 把文件放入图包目录，再点 `草稿 -> 导入 GraphIndex 图包`。

下一步建议：

- 做“导入后自动打开最近图包草稿”或“发现新 GraphIndex 时提醒导入”。
- 这样用户从 AI 生成 JSON 到程序查看画布会更顺。
