import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_logic_detail_service.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';

void main() {
  test('BlueprintLogicDetailService reads logic json summary', () async {
    final tempDir = await Directory.systemTemp.createTemp('logic_detail_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final logicFile = File('${tempDir.path}/Game/BaseC/Mode/GM_Logic.json');
    await logicFile.parent.create(recursive: true);
    await logicFile.writeAsString('''
{
  "asset": {
    "name": "GM_MainMode",
    "parentClass": "GameModeBase"
  },
  "gameModeClassDefaults": {
    "isGameMode": true,
    "PlayerControllerClass": {
      "display": "/Game/BaseC/PC/PC_Main.PC_Main"
    }
  },
  "logicSummary": {
    "entryPoints": [
      {
        "graphName": "EventGraph",
        "name": "ReceiveBeginPlay",
        "type": "Event",
        "replication": "Local",
        "reliable": false
      },
      {
        "graphName": "UserLogin",
        "name": "UserLogin",
        "type": "Function",
        "replication": "Local",
        "reliable": false
      }
    ],
    "controlFlows": [
      {
        "graphName": "EventGraph",
        "fromNodeTitle": "事件开始运行",
        "toNodeTitle": "Initialize",
        "kind": "then",
        "depth": 0
      },
      {
        "graphName": "UserLogin",
        "fromNodeTitle": "UserLogin",
        "toNodeTitle": "分支",
        "kind": "then",
        "depth": 0
      },
      {
        "graphName": "UserLogin",
        "fromNodeTitle": "分支",
        "toNodeTitle": "LoginSuccess",
        "kind": "Branch",
        "depth": 1
      }
    ],
    "callGraph": [
      {
        "graphName": "EventGraph",
        "nodeTitle": "游戏存档存在",
        "functionName": "DoesSaveGameExist",
        "ownerClass": "GameplayStatics",
        "replication": "Local",
        "parameters": [
          {"name": "SlotName", "value": "ServerData", "defaultValue": "ServerData", "linked": false}
        ]
      }
    ]
  },
  "riskSummary": {
    "branchRoutes": [
      {
        "graphName": "EventGraph",
        "nodeTitle": "分支",
        "condition": "Call DoesSaveGameExist.ReturnValue",
        "trueTarget": "LoadGame",
        "falseTarget": "CreateSave"
      }
    ],
    "callParameterTable": [
      {
        "graphName": "EventGraph",
        "nodeTitle": "游戏存档存在",
        "functionName": "DoesSaveGameExist",
        "ownerClass": "GameplayStatics",
        "replication": "Local",
        "parameters": [
          {"name": "SlotName", "value": "ServerData", "defaultValue": "ServerData", "linked": false}
        ]
      }
    ],
    "warnings": [
      {
        "severity": "Warning",
        "category": "UnusedReturnValue",
        "graphName": "ServerSave",
        "nodeTitle": "将游戏保存到插槽",
        "message": "Bool output pin is not connected.",
        "details": "Pin: ReturnValue"
      }
    ]
  },
  "commentBoxes": [
    {
      "graphName": "EventGraph",
      "text": "检查玩家账号数据是否存在"
    }
  ]
}
''');

    const service = BlueprintLogicDetailService();
    final detail = await service.load(
      exportPath: tempDir.path,
      asset: _asset(
        logicJsonPath: 'GetTheMeaningExports/Game/BaseC/Mode/GM_Logic.json',
      ),
    );

    expect(detail.available, isTrue);
    expect(detail.entryPoints, hasLength(2));
    expect(detail.entryPoints.first.name, 'ReceiveBeginPlay');
    expect(detail.controlFlowCount, 3);
    expect(detail.controlFlows, hasLength(3));
    expect(detail.controlFlows.last.graphName, 'UserLogin');
    expect(detail.controlFlows.last.kind, 'Branch');
    expect(detail.controlFlows.last.toNodeTitle, 'LoginSuccess');
    expect(detail.callCount, 1);
    expect(detail.branchRoutes.single.trueTarget, 'LoadGame');
    expect(
      detail.callParameters.single.parameters.single.defaultValue,
      'ServerData',
    );
    expect(detail.warnings.single.category, 'UnusedReturnValue');
    expect(detail.commentBoxes.single.text, '检查玩家账号数据是否存在');
    expect(
      detail.gameModeDefaults['PlayerControllerClass'],
      '/Game/BaseC/PC/PC_Main.PC_Main',
    );
  });

  test('BlueprintLogicDetailService reports missing logic json', () async {
    final tempDir = await Directory.systemTemp.createTemp('logic_missing_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const service = BlueprintLogicDetailService();
    final detail = await service.load(
      exportPath: tempDir.path,
      asset: _asset(logicJsonPath: 'GetTheMeaningExports/Game/Missing.json'),
    );

    expect(detail.available, isFalse);
    expect(detail.message, contains('没有找到'));
  });
}

GetTheMeaningAssetSummary _asset({required String logicJsonPath}) {
  return GetTheMeaningAssetSummary(
    name: 'GM_MainMode',
    displayName: 'GM_MainMode (/Game/BaseC/Mode)',
    type: 'Blueprint',
    assetPath: '/Game/BaseC/Mode/GM_MainMode.GM_MainMode',
    packagePath: '/Game/BaseC/Mode',
    parentClass: 'GameModeBase',
    readablePath: 'GetTheMeaningExports/Game/BaseC/Mode/GM_ReadableCode.txt',
    logicJsonPath: logicJsonPath,
    variables: const [],
    events: const [],
    rpcs: const [],
    functions: const [],
    calls: const [],
  );
}
