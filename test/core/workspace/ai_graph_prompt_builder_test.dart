import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/ai_graph_prompt_builder.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_logic_detail_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/workspace_models.dart';

void main() {
  test('AiGraphPromptBuilder includes protocol, output path, and safeguards', () {
    const workspace = WorkspaceSummary(
      id: 'fantasy_project',
      name: 'FantasyProject',
      workspacePath:
          r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge\FantasyProject.ubbridge',
      unrealProjectPath: r'D:\UnrealMap\FantasyProject\FantasyProject.uproject',
      getTheMeaningExportPath:
          r'D:\UnrealMap\FantasyProject\Saved\GetTheMeaningExports',
      lastOpenedAt: '2026-07-07T14:00:00+08:00',
    );

    final prompt = const AiGraphPromptBuilder().build(
      workspace: workspace,
      graphPackagePath: r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge',
    );

    expect(prompt, contains('AI_GRAPH_PACKAGE_GUIDE.md'));
    expect(prompt, contains('FantasyProject'));
    expect(
      prompt,
      contains(r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge'),
    );
    expect(prompt, contains('GraphIndex.json'));
    expect(prompt, contains('Graphs/<AssetName>_<GraphName>.json'));
    expect(prompt, contains('不要修改 Unreal .uasset 文件'));
    expect(prompt, contains('node id 和 pin id'));
    expect(prompt, contains('名称可以简写'));
    expect(prompt, contains('description 必须讲清用途'));
  });

  test(
    'AiGraphPromptBuilder builds draft workspace prompt without Unreal project',
    () {
      const workspace = WorkspaceSummary(
        id: 'draft_skill',
        name: '角色技能草稿',
        workspacePath:
            r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\Drafts/角色技能草稿.ubbridge',
        unrealProjectPath: '',
        getTheMeaningExportPath: '',
        lastOpenedAt: '2026-07-08T13:00:00+08:00',
      );

      final prompt = const AiGraphPromptBuilder().build(
        workspace: workspace,
        graphPackagePath:
            r'C:\Users\liuyu\AppData\Roaming\UnrealBlueprintBridge\Drafts',
      );

      expect(prompt, contains('通用草稿图'));
      expect(prompt, contains('不依赖 Unreal 项目'));
      expect(prompt, contains('GraphIndex.json'));
      expect(prompt, contains('不要生成可执行逻辑'));
      expect(prompt, contains('触发语'));
      expect(prompt, contains('没有收到具体蓝图需求前，不要生成 GraphIndex.json'));
      expect(prompt, contains('触发图例生成：目标工作区「角色技能草稿」'));
      expect(prompt, contains('需求：<写清楚要画的蓝图逻辑>'));
      expect(prompt, contains('名称可以简写'));
      expect(prompt, contains('description 必须讲清用途'));
    },
  );

  test('AiGraphPromptBuilder builds asset graph prompt with flow summary', () {
    const asset = GetTheMeaningAssetSummary(
      name: 'GM_MainMode',
      displayName: 'GM_MainMode (/Game/BaseC/Mode)',
      type: 'Blueprint',
      assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
      packagePath: '/Game/BaseC/Mode',
      parentClass: 'GameModeBase',
      readablePath: 'GM_MainMode_ReadableCode.txt',
      logicJsonPath: 'GM_MainMode_Logic.json',
      variables: ['PlayerMaps'],
      functions: ['UserLogin'],
      events: ['ReceiveBeginPlay'],
      rpcs: ['ROS_Login'],
      calls: ['Map_Find'],
    );

    final prompt = const AiGraphPromptBuilder().buildForAssetGraph(
      asset: asset,
      graphName: 'UserLogin',
      graphPackagePath: r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge',
      userRequest: '生成一个开门逻辑',
      flows: const [
        BlueprintControlFlow(
          graphName: 'UserLogin',
          fromNodeTitle: 'UserLogin',
          toNodeTitle: 'Branch',
          kind: 'then',
          depth: 0,
        ),
        BlueprintControlFlow(
          graphName: 'UserLogin',
          fromNodeTitle: 'Branch',
          toNodeTitle: 'LoginSuccess',
          kind: 'True',
          depth: 1,
        ),
      ],
    );

    expect(prompt, contains('GM_MainMode'));
    expect(prompt, contains('/Game/BaseC/Mode/GM_MainMode.GM_MainMode'));
    expect(prompt, contains('UserLogin'));
    expect(
      prompt,
      contains(r'D:\UnrealMap\FantasyProject\Saved\BlueprintBridge'),
    );
    expect(prompt, contains('UserLogin -> Branch'));
    expect(prompt, contains('Branch -- True -> LoginSuccess'));
    expect(prompt, contains('只为这个资产和这个函数'));
    expect(prompt, contains('用户需求：生成一个开门逻辑'));
    expect(prompt, contains('名称可以简写'));
    expect(prompt, contains('description 必须讲清用途'));
  });
}
