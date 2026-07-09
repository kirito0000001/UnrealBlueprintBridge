import 'blueprint_logic_detail_service.dart';
import 'get_the_meaning_import_service.dart';
import 'workspace_models.dart';

class AiGraphPromptBuilder {
  const AiGraphPromptBuilder();

  String build({
    required WorkspaceSummary workspace,
    required String graphPackagePath,
  }) {
    if (workspace.unrealProjectPath.trim().isEmpty) {
      return _buildDraftPrompt(
        workspace: workspace,
        graphPackagePath: graphPackagePath,
      );
    }

    final buffer = StringBuffer()
      ..writeln('请为「虚幻：蓝图连结」生成 BlueprintBridge 图包。')
      ..writeln()
      ..writeln('先阅读项目根目录 AI_GRAPH_PACKAGE_GUIDE.md，并严格遵守里面的协议。')
      ..writeln()
      ..writeln('当前项目：${workspace.name}')
      ..writeln('Unreal 项目路径：${workspace.unrealProjectPath}')
      ..writeln('图包输出目录：$graphPackagePath')
      ..writeln()
      ..writeln('必须输出：')
      ..writeln('- GraphIndex.json')
      ..writeln('- Graphs/<AssetName>_<GraphName>.json')
      ..writeln()
      ..writeln('要求：')
      ..writeln('- 使用 schemaVersion 1。')
      ..writeln('- 每个图文件使用 GraphDocument JSON。')
      ..writeln('- 节点从左到右布局，Branch 的 True / False 分支上下分开。')
      ..writeln(
        '- 名称、标题和说明必须使用中文；名称可以简写，但 description 必须讲清用途、触发条件、状态变化、副作用以及相关网络权限注意事项。',
      )
      ..writeln(
        '- 必须匹配 Unreal / C++ 源数据的类名、函数名、变量名和引脚名可以保留原文，但 description 要补充中文解释。',
      )
      ..writeln('- 所有 link 必须引用真实存在的 node id 和 pin id。')
      ..writeln('- 不要修改 Unreal .uasset 文件。')
      ..writeln('- 不要生成可执行逻辑，只生成用于说明和演示的视觉草稿。')
      ..writeln()
      ..writeln('生成后请检查 JSON 是否有效，并确认每条连线都能对应到已有节点和引脚。');

    return buffer.toString().trim();
  }

  String _buildDraftPrompt({
    required WorkspaceSummary workspace,
    required String graphPackagePath,
  }) {
    final buffer = StringBuffer()
      ..writeln('请为「虚幻：蓝图连结」生成通用草稿图 BlueprintBridge 图包。')
      ..writeln()
      ..writeln('这是一个不依赖 Unreal 项目的草稿工作区，通常用于让 AI 画流程图、规则图、系统设计图或蓝图逻辑草稿。')
      ..writeln()
      ..writeln('先阅读项目根目录 AI_GRAPH_PACKAGE_GUIDE.md，并严格遵守里面的协议。')
      ..writeln()
      ..writeln('草稿项目：${workspace.name}')
      ..writeln('图包输出目录：$graphPackagePath')
      ..writeln()
      ..writeln('触发工作流：')
      ..writeln('- 这段提示词是给其他 AI 使用的触发入口，不代表现在就要生成图包。')
      ..writeln('- 没有收到具体蓝图需求前，不要生成 GraphIndex.json，也不要生成 Graphs/*.json。')
      ..writeln('- 收到触发语并且需求明确后，再按下面协议生成 BlueprintBridge 图包。')
      ..writeln('- 推荐触发语：触发图例生成：目标工作区「${workspace.name}」，需求：<写清楚要画的蓝图逻辑>。')
      ..writeln()
      ..writeln('必须输出：')
      ..writeln('- GraphIndex.json')
      ..writeln('- Graphs/<DraftName>_<GraphName>.json')
      ..writeln()
      ..writeln('要求：')
      ..writeln('- 使用 schemaVersion 1。')
      ..writeln('- 每个图文件使用 GraphDocument JSON。')
      ..writeln('- 节点从左到右布局，Branch 的 True / False 分支上下分开。')
      ..writeln(
        '- 名称、标题和说明必须使用中文；名称可以简写，但 description 必须讲清用途、触发条件、状态变化、副作用以及相关网络权限注意事项。',
      )
      ..writeln(
        '- 必须匹配 Unreal / C++ 源数据的类名、函数名、变量名和引脚名可以保留原文，但 description 要补充中文解释。',
      )
      ..writeln('- 所有 link 必须引用真实存在的 node id 和 pin id。')
      ..writeln('- 不要生成可执行逻辑，只生成用于说明和演示的视觉草稿。')
      ..writeln('- 如果用户没有给具体节点，请先按“输入 / 判断 / 处理 / 输出”的结构组织草稿图。')
      ..writeln()
      ..writeln('生成后请检查 JSON 是否有效，并确认每条连线都能对应到已有节点和引脚。');

    return buffer.toString().trim();
  }

  String buildForAssetGraph({
    required GetTheMeaningAssetSummary asset,
    required String graphName,
    required String graphPackagePath,
    required List<BlueprintControlFlow> flows,
    String userRequest = '',
  }) {
    final normalizedGraphName = graphName.trim().isEmpty ? '全部执行线' : graphName;
    final normalizedRequest = userRequest.trim();
    final buffer = StringBuffer()
      ..writeln('请为「虚幻：蓝图连结」生成 BlueprintBridge 图包。')
      ..writeln()
      ..writeln('先阅读项目根目录 AI_GRAPH_PACKAGE_GUIDE.md，并严格遵守里面的协议。')
      ..writeln()
      ..writeln('只为这个资产和这个函数 / 事件生成图包：')
      ..writeln('- AssetName: ${asset.name}')
      ..writeln('- AssetPath: ${asset.assetPath}')
      ..writeln('- ParentClass: ${asset.parentClass}')
      ..writeln('- GraphName: $normalizedGraphName')
      ..writeln('- 图包输出目录: $graphPackagePath')
      ..writeln()
      ..writeAll(
        normalizedRequest.isEmpty
            ? const <String>[]
            : <String>['用户需求：$normalizedRequest', '\n'],
        '\n',
      )
      ..writeln('必须输出：')
      ..writeln('- GraphIndex.json')
      ..writeln(
        '- Graphs/${_safeName(asset.name)}_${_safeName(normalizedGraphName)}.json',
      )
      ..writeln()
      ..writeln('要求：')
      ..writeln('- 使用 schemaVersion 1。')
      ..writeln('- 每个图文件使用 GraphDocument JSON。')
      ..writeln('- assetName、assetPath、graphName 必须和上面一致。')
      ..writeln('- 节点从左到右布局，Branch 的 True / False 分支上下分开。')
      ..writeln(
        '- 名称、标题和说明必须使用中文；名称可以简写，但 description 必须讲清用途、触发条件、状态变化、副作用以及相关网络权限注意事项。',
      )
      ..writeln(
        '- 必须匹配 Unreal / C++ 源数据的类名、函数名、变量名和引脚名可以保留原文，但 description 要补充中文解释。',
      )
      ..writeln('- 所有 link 必须引用真实存在的 node id 和 pin id。')
      ..writeln('- 不要修改 Unreal .uasset 文件。')
      ..writeln('- 不要生成可执行逻辑，只生成用于说明和演示的视觉草稿。');

    if (flows.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('可参考的执行线摘要：');
      for (final flow in flows.take(16)) {
        buffer.writeln('- ${_formatFlow(flow)}');
      }
      if (flows.length > 16) {
        buffer.writeln('- 另外还有 ${flows.length - 16} 条执行线，请按同一逻辑压缩整理。');
      }
    }

    buffer
      ..writeln()
      ..writeln('生成后请检查 JSON 是否有效，并确认每条连线都能对应到已有节点和引脚。');

    return buffer.toString().trim();
  }

  String _formatFlow(BlueprintControlFlow flow) {
    final from = _compact(flow.fromNodeTitle);
    final to = _compact(flow.toNodeTitle);
    final kind = flow.kind.trim();
    if (kind.isEmpty || kind == 'then') {
      return '$from -> $to';
    }

    return '$from -- $kind -> $to';
  }

  String _compact(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' / ');
    return normalized.isEmpty ? '未命名节点' : normalized;
  }

  String _safeName(String value) {
    final normalized = value.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9_\-\u4e00-\u9fa5]+'),
      '_',
    );
    return normalized.isEmpty ? 'Graph' : normalized;
  }
}
