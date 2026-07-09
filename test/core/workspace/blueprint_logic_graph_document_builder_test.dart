import 'package:flutter_test/flutter_test.dart';
import 'package:unreal_blueprint_bridge/core/models/graph_pin.dart';
import 'package:unreal_blueprint_bridge/core/workspace/blueprint_logic_graph_document_builder.dart';
import 'package:unreal_blueprint_bridge/core/workspace/get_the_meaning_import_service.dart';

void main() {
  test('BlueprintLogicGraphDocumentBuilder restores node level graph', () {
    const builder = BlueprintLogicGraphDocumentBuilder();
    final document = builder.build(
      asset: _asset(),
      graphName: 'EventGraph',
      logicJson: {
        'asset': {
          'path': '/Game/BaseC/Mode/GM_PtoP.GM_PtoP',
          'parentClass': 'GameModeBase',
        },
        'variables': [
          {
            'name': 'GameStage',
            'guid': 'var_stage',
            'friendlyName': 'Game Stage',
            'category': 'State',
            'type': {'display': 'byte<EGameStateStage>', 'category': 'byte'},
            'network': {
              'replication': 'RepNotify',
              'replicated': true,
              'usesRepNotify': true,
            },
            'flags': {
              'private': false,
              'editable': true,
              'exposeOnSpawn': false,
            },
          },
        ],
        'events': [
          {
            'graph': 'EventGraph',
            'nodeId': 'event_begin',
            'name': 'ReceiveBeginPlay',
            'replication': 'Local',
            'reliable': false,
          },
        ],
        'functions': [
          {
            'name': 'Initialize',
            'inputs': [
              {
                'id': 'input_mode',
                'name': 'GameMode',
                'type': {'display': 'byte<EPlayMode>', 'category': 'byte'},
              },
            ],
            'outputs': [],
          },
        ],
        'graphs': [
          {
            'name': 'EventGraph',
            'kind': 'Ubergraph',
            'nodes': [
              {
                'id': 'event_begin',
                'class': 'K2Node_Event',
                'name': 'K2Node_Event_0',
                'title': '事件开始运行',
                'summary': 'Event: ReceiveBeginPlay',
                'position': {'x': 0, 'y': 0},
                'pins': [
                  {
                    'id': 'then',
                    'name': 'then',
                    'direction': 'Output',
                    'isExec': true,
                    'type': {'display': 'exec', 'category': 'exec'},
                    'defaultValue': '',
                  },
                ],
              },
              {
                'id': 'call_init',
                'class': 'K2Node_CallFunction',
                'name': 'K2Node_CallFunction_0',
                'title': 'Initialize\n目标是GM Pto P',
                'summary': 'Call: Initialize',
                'position': {'x': 360, 'y': 0},
                'pins': [
                  {
                    'id': 'execute',
                    'name': 'execute',
                    'direction': 'Input',
                    'isExec': true,
                    'type': {'display': 'exec', 'category': 'exec'},
                    'defaultValue': '',
                  },
                  {
                    'id': 'mode',
                    'name': 'GameMode',
                    'direction': 'Input',
                    'isExec': false,
                    'type': {'display': 'byte<EPlayMode>', 'category': 'byte'},
                    'defaultValue': 'PtoP',
                  },
                ],
              },
            ],
            'links': [
              {
                'fromNodeId': 'event_begin',
                'fromPinId': 'then',
                'fromPinName': 'then',
                'toNodeId': 'call_init',
                'toPinId': 'execute',
                'toPinName': 'execute',
                'isExec': true,
              },
              {
                'fromNodeId': 'event_begin',
                'fromPinId': 'then',
                'fromPinName': 'then',
                'toNodeId': 'call_init',
                'toPinId': 'mode',
                'toPinName': 'GameMode',
                'isExec': false,
              },
            ],
          },
        ],
      },
    );

    expect(document, isNotNull);
    expect(document!.graph.title, 'GM_PtoP / EventGraph');
    expect(document.graph.parentClass, 'GameModeBase');
    expect(document.nodes, hasLength(2));
    expect(document.nodes.first.id, 'event_begin');
    expect(document.nodes.first.nodeType, 'Event');
    expect(document.nodes.last.position.x, 360);
    expect(document.nodes.last.pins.last.defaultValue, 'PtoP');
    expect(document.nodes.last.pins.last.dataType, 'enum');
    expect(document.nodes.last.pins.last.direction, GraphPinDirection.input);
    expect(document.links, hasLength(2));
    expect(document.links.first.linkType, 'exec');
    expect(document.links.last.linkType, 'data');
    expect(document.variables.single.name, 'GameStage');
    expect(document.variables.single.dataType, 'enum');
    expect(document.variables.single.replication, 'RepNotify');
    expect(document.events.single.name, 'ReceiveBeginPlay');
    expect(document.functions.single.name, 'Initialize');
    expect(document.functions.single.inputs.single.name, 'GameMode');
  });
}

GetTheMeaningAssetSummary _asset() {
  return const GetTheMeaningAssetSummary(
    name: 'GM_PtoP',
    displayName: 'GM_PtoP (/Game/BaseC/Mode)',
    type: 'Blueprint',
    assetPath: '/Game/BaseC/Mode/GM_PtoP.GM_PtoP',
    packagePath: '/Game/BaseC/Mode',
    parentClass: 'GameModeBase',
    readablePath:
        'GetTheMeaningExports/Game/BaseC/Mode/GM_PtoP_ReadableCode.txt',
    logicJsonPath: 'GetTheMeaningExports/Game/BaseC/Mode/GM_PtoP_Logic.json',
    variables: [],
    events: [],
    rpcs: [],
    functions: [],
    calls: [],
  );
}
