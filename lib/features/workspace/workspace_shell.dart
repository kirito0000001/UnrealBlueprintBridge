import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/graph_document.dart';
import '../../core/update/app_update_models.dart';
import '../../core/update/app_update_service.dart';
import '../../core/workspace/ai_graph_prompt_builder.dart';
import '../../core/workspace/blueprint_bridge_graph_package_service.dart';
import '../../core/workspace/blueprint_flow_graph_builder.dart';
import '../../core/workspace/blueprint_logic_graph_document_builder.dart';
import '../../core/workspace/blueprint_logic_detail_service.dart';
import '../../core/workspace/canvas_autosave_controller.dart';
import '../../core/workspace/canvas_workspace.dart';
import '../../core/workspace/get_the_meaning_import_service.dart';
import '../../core/workspace/workspace_app_data.dart';
import '../../core/workspace/workspace_models.dart';
import '../../core/workspace/workspace_storage_service.dart';
import 'ai_graph_prompt_panel.dart';
import '../editor/editor_page.dart';
import '../editor/catalog/unreal_node_catalog.dart';
import 'blueprint_assets_view.dart';

enum WorkspaceSection {
  overview('概览', Icons.space_dashboard_outlined),
  blueprints('蓝图', Icons.account_tree_outlined),
  cpp('C++', Icons.code),
  data('数据', Icons.table_chart_outlined),
  risks('风险', Icons.report_gmailerrorred_outlined),
  canvas('画布', Icons.polyline_outlined);

  const WorkspaceSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key});

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  late final WorkspaceStorageService _storageService = WorkspaceStorageService(
    appDataDirectory: defaultWorkspaceAppDataDirectory(),
  );
  final GetTheMeaningImportService _importService =
      const GetTheMeaningImportService();
  final BlueprintLogicDetailService _logicDetailService =
      const BlueprintLogicDetailService();
  final BlueprintFlowGraphBuilder _flowGraphBuilder =
      const BlueprintFlowGraphBuilder();
  final BlueprintLogicGraphDocumentBuilder _logicGraphDocumentBuilder =
      const BlueprintLogicGraphDocumentBuilder();
  final BlueprintBridgeGraphPackageService _graphPackageService =
      const BlueprintBridgeGraphPackageService();
  final AiGraphPromptBuilder _aiGraphPromptBuilder =
      const AiGraphPromptBuilder();
  final AppUpdateService _updateService = const AppUpdateService();
  late final CanvasAutosaveController<CanvasWorkspace>
  _canvasAutosaveController = CanvasAutosaveController<CanvasWorkspace>(
    delay: const Duration(milliseconds: 500),
    save: _saveCanvasWorkspace,
  );
  BridgeAppState? _appState;
  WorkspaceSummary? _activeWorkspace;
  GetTheMeaningImportSummary? _importSummary;
  GetTheMeaningAssetSummary? _selectedAsset;
  BlueprintLogicDetail? _logicDetail;
  CanvasWorkspace _canvasWorkspace = CanvasWorkspace.empty();
  bool _isImporting = false;
  bool _isLoadingLogicDetail = false;
  WorkspaceSection _section = WorkspaceSection.overview;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadAppState();
  }

  @override
  void dispose() {
    _canvasAutosaveController.flush();
    _canvasAutosaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState;
    if (appState == null) {
      return const _WorkspaceLoadingPage();
    }

    final activeWorkspace = _activeWorkspace;
    if (activeWorkspace == null) {
      return _WorkspaceHomePage(
        appState: appState,
        onOpenWorkspace: _openWorkspace,
        onBindUnrealProject: _bindUnrealProject,
        onCreateDraftProject: _createDraftProject,
        onOpenSettings: _openSettings,
      );
    }

    final graphPackagePath = _graphPackageDirectory(activeWorkspace).path;
    return _ProjectWorkspacePage(
      appState: appState,
      workspace: activeWorkspace,
      section: _section,
      onSectionChanged: (section) => setState(() => _section = section),
      isSidebarCollapsed: _isSidebarCollapsed,
      onSidebarCollapsedChanged: (value) {
        setState(() => _isSidebarCollapsed = value);
      },
      onSwitchWorkspace: _openWorkspace,
      importSummary: _importSummary,
      selectedAsset: _selectedAsset,
      logicDetail: _logicDetail,
      isImporting: _isImporting,
      isLoadingLogicDetail: _isLoadingLogicDetail,
      canvasWorkspace: _canvasWorkspace,
      onSelectedAssetChanged: _selectAsset,
      onImportGetTheMeaning: _importCurrentWorkspace,
      onCreateCanvasFromFlows: _createCanvasFromFlows,
      onCanvasDocumentChanged: _updateCanvasDocument,
      engineNodeBookId: appState.settings.engineNodeBookId,
      onCanvasDraftSelected: _selectCanvasDraft,
      onResetActiveCanvas: _resetActiveCanvas,
      onResetCanvasDraft: _resetCanvasDraft,
      onRenameCanvasDraft: _renameCanvasDraft,
      onDeleteCanvasDraft: _deleteCanvasDraft,
      onOpenCanvasDraftFolder: _openCanvasDraftFolder,
      onCreateBlankCanvasDraft: _createBlankCanvasDraft,
      onExportActiveCanvasDraft: _exportActiveCanvasDraft,
      onImportLatestCanvasDraft: _importLatestCanvasDraft,
      onImportGraphPackage: _importGraphPackage,
      onWriteExampleGraphPackage: _writeExampleGraphPackage,
      graphPackagePath: graphPackagePath,
      graphExportPath: _storageService
          .graphExportDirectory(activeWorkspace.id)
          .path,
      aiGraphPrompt: _aiGraphPromptBuilder.build(
        workspace: activeWorkspace,
        graphPackagePath: graphPackagePath,
      ),
      onBackToHome: _backToHome,
    );
  }

  Future<void> _loadAppState() async {
    final loaded = await _storageService.loadOrCreateInitialState();
    if (!mounted) {
      return;
    }

    setState(() {
      _appState = loaded;
      _activeWorkspace = loaded.currentWorkspace;
    });
    final currentWorkspace = loaded.currentWorkspace;
    if (currentWorkspace != null) {
      _loadCachedImportForWorkspace(currentWorkspace);
      _loadCachedCanvasForWorkspace(currentWorkspace);
    }
  }

  Future<void> _openWorkspace(WorkspaceSummary workspace) async {
    final appState = _appState;
    if (appState == null) {
      return;
    }

    await _canvasAutosaveController.flush();
    final updated = BridgeAppState(
      lastWorkspaceId: workspace.id,
      recentWorkspaces: appState.recentWorkspaces,
    );

    setState(() {
      _activeWorkspace = workspace;
      _importSummary = null;
      _selectedAsset = null;
      _logicDetail = null;
      _canvasWorkspace = CanvasWorkspace.empty();
      _isImporting = false;
      _isLoadingLogicDetail = false;
      _section = WorkspaceSection.overview;
      _appState = updated;
    });
    _storageService.saveAppState(updated);
    _loadCachedImportForWorkspace(workspace);
    _loadCachedCanvasForWorkspace(workspace);
  }

  Future<void> _bindUnrealProject() async {
    final appState = _appState;
    if (appState == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 Unreal 项目文件',
      type: FileType.custom,
      allowedExtensions: const ['uproject'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      _showMessage('没有读取到项目文件路径');
      return;
    }

    final trimmedPath = selectedPath.trim();
    if (!trimmedPath.toLowerCase().endsWith('.uproject')) {
      _showMessage('请选择 .uproject 文件路径');
      return;
    }

    final projectFile = File(trimmedPath);
    if (!await projectFile.exists()) {
      _showMessage('没有找到项目文件：$trimmedPath');
      return;
    }

    await _canvasAutosaveController.flush();
    final updated = appState.bindDesktopUnrealProject(
      unrealProjectPath: trimmedPath,
      openedAt: DateTime.now(),
    );
    final workspace = updated.currentWorkspace;
    if (workspace == null) {
      _showMessage('绑定虚幻项目失败');
      return;
    }

    setState(() {
      _appState = updated;
      _activeWorkspace = workspace;
      _importSummary = null;
      _selectedAsset = null;
      _logicDetail = null;
      _canvasWorkspace = CanvasWorkspace.empty();
      _isImporting = false;
      _isLoadingLogicDetail = false;
      _section = WorkspaceSection.overview;
    });

    await _storageService.saveAppState(updated);
    _restoreImportFromExportDirectory(workspace);
    _loadCachedCanvasForWorkspace(workspace);
    _showMessage('已绑定：${workspace.name}');
  }

  Future<void> _createDraftProject() async {
    final appState = _appState;
    if (appState == null) {
      return;
    }

    final projectName = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateDraftProjectDialog(),
    );
    if (!mounted || projectName == null) {
      return;
    }

    await _canvasAutosaveController.flush();
    final draftsRoot =
        '${_storageService.appDataDirectory.path}${Platform.pathSeparator}Drafts';
    final updated = appState.createDraftWorkspace(
      projectName: projectName,
      appWorkspaceRoot: draftsRoot,
      openedAt: DateTime.now(),
    );
    final workspace = updated.currentWorkspace;
    if (workspace == null) {
      _showMessage('创建草稿项目失败');
      return;
    }

    setState(() {
      _appState = updated;
      _activeWorkspace = workspace;
      _importSummary = null;
      _selectedAsset = null;
      _logicDetail = null;
      _canvasWorkspace = CanvasWorkspace.empty();
      _isImporting = false;
      _isLoadingLogicDetail = false;
      _section = WorkspaceSection.overview;
    });

    await _storageService.saveAppState(updated);
    _loadCachedCanvasForWorkspace(workspace);
    _showMessage('已创建草稿项目：${workspace.name}');
  }

  Future<void> _openSettings() async {
    final appState = _appState;
    if (appState == null) {
      return;
    }

    final settings = await showDialog<BridgeAppSettings>(
      context: context,
      builder: (context) => _GlobalSettingsDialog(
        settings: appState.settings,
        updateService: _updateService,
      ),
    );
    if (!mounted || settings == null) {
      return;
    }

    final updated = appState.copyWith(settings: settings);
    setState(() => _appState = updated);
    await _storageService.saveAppState(updated);
    _showMessage('已更新整体设置');
  }

  Future<void> _loadCachedCanvasForWorkspace(WorkspaceSummary workspace) async {
    final canvasWorkspace = await _storageService.loadCanvasWorkspace(
      workspace.id,
    );
    if (!mounted) {
      return;
    }

    final activeWorkspace = _activeWorkspace;
    if (activeWorkspace == null || activeWorkspace.id != workspace.id) {
      return;
    }

    setState(() {
      _canvasWorkspace = canvasWorkspace;
    });
  }

  Future<void> _importCurrentWorkspace() async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }
    if (_isImporting) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final summary = await _importService.inspectDirectory(
      workspace.getTheMeaningExportPath,
    );
    if (!mounted) {
      return;
    }

    final firstAsset = _firstBlueprintAsset(summary);
    setState(() {
      _importSummary = summary;
      _selectedAsset = firstAsset;
      _logicDetail = null;
      _isImporting = false;
    });
    await _storageService.saveImportSummary(workspace.id, summary);
    if (firstAsset != null) {
      _loadLogicDetail(firstAsset);
    }
  }

  Future<void> _loadCachedImportForWorkspace(WorkspaceSummary workspace) async {
    final summary = await _storageService.loadImportSummary(workspace.id);
    if (!mounted) {
      return;
    }

    if (summary == null) {
      _restoreImportFromExportDirectory(workspace);
      return;
    }

    final activeWorkspace = _activeWorkspace;
    if (activeWorkspace == null || activeWorkspace.id != workspace.id) {
      return;
    }

    final firstAsset = _firstBlueprintAsset(summary);
    setState(() {
      _importSummary = summary;
      _selectedAsset = firstAsset;
      _logicDetail = null;
      _isImporting = false;
      _isLoadingLogicDetail = false;
    });
    if (firstAsset != null) {
      _loadLogicDetail(firstAsset);
    }
  }

  Future<void> _restoreImportFromExportDirectory(
    WorkspaceSummary workspace,
  ) async {
    if (workspace.getTheMeaningExportPath.trim().isEmpty || _isImporting) {
      return;
    }

    final activeWorkspace = _activeWorkspace;
    if (activeWorkspace == null || activeWorkspace.id != workspace.id) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final summary = await _importService.inspectDirectory(
      workspace.getTheMeaningExportPath,
    );
    if (!mounted) {
      return;
    }

    final currentWorkspace = _activeWorkspace;
    if (currentWorkspace == null || currentWorkspace.id != workspace.id) {
      return;
    }

    final firstAsset = _firstBlueprintAsset(summary);
    setState(() {
      _importSummary = summary;
      _selectedAsset = firstAsset;
      _logicDetail = null;
      _isImporting = false;
      _isLoadingLogicDetail = false;
    });
    await _storageService.saveImportSummary(workspace.id, summary);
    if (firstAsset != null) {
      _loadLogicDetail(firstAsset);
    }
  }

  void _selectAsset(GetTheMeaningAssetSummary asset) {
    setState(() {
      _selectedAsset = asset;
      _logicDetail = null;
      _isLoadingLogicDetail = true;
    });
    _loadLogicDetail(asset);
  }

  Future<void> _loadLogicDetail(GetTheMeaningAssetSummary asset) async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    if (!_isLoadingLogicDetail) {
      setState(() {
        _isLoadingLogicDetail = true;
      });
    }

    final detail = await _logicDetailService.load(
      exportPath: workspace.getTheMeaningExportPath,
      asset: asset,
    );
    if (!mounted) {
      return;
    }

    final selected = _selectedAsset;
    if (selected == null || selected.assetPath != asset.assetPath) {
      return;
    }

    setState(() {
      _logicDetail = detail;
      _isLoadingLogicDetail = false;
    });
  }

  Future<void> _createCanvasFromFlows(
    String graphName,
    List<BlueprintControlFlow> flows,
  ) async {
    final selectedAsset = _selectedAsset;
    if (selectedAsset == null || flows.isEmpty) {
      return;
    }
    final workspace = _activeWorkspace;

    final canvasGraphName = graphName == '全部' ? '全部执行线' : graphName;
    final key = canvasDraftKey(
      assetPath: selectedAsset.assetPath,
      graphName: canvasGraphName,
    );
    if (_canvasWorkspace.drafts.containsKey(key)) {
      setState(() {
        _canvasWorkspace = _canvasWorkspace.activate(key);
        _section = WorkspaceSection.canvas;
      });
      return;
    }

    final nodeLevelDocument = workspace == null
        ? null
        : await _logicGraphDocumentBuilder.buildFromAsset(
            exportPath: workspace.getTheMeaningExportPath,
            asset: selectedAsset,
            graphName: graphName == '全部' ? 'EventGraph' : graphName,
          );
    if (!mounted) {
      return;
    }

    final document =
        nodeLevelDocument ??
        _flowGraphBuilder.build(
          assetName: selectedAsset.name,
          graphName: canvasGraphName,
          flows: flows,
          blueprintType: selectedAsset.type,
          parentClass: selectedAsset.parentClass,
        );

    final draft = CanvasDraft(
      key: key,
      assetName: selectedAsset.name,
      assetPath: selectedAsset.assetPath,
      graphName: canvasGraphName,
      document: document,
    );
    final updatedWorkspace = _canvasWorkspace.upsert(draft);

    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    _saveCanvasWorkspace(updatedWorkspace);
  }

  Future<void> _backToHome() async {
    await _canvasAutosaveController.flush();
    if (!mounted) {
      return;
    }

    setState(() => _activeWorkspace = null);
  }

  Future<void> _saveCanvasWorkspace(CanvasWorkspace canvasWorkspace) async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    await _storageService.saveCanvasWorkspace(workspace.id, canvasWorkspace);
  }

  void _updateCanvasDocument(GraphDocument document) {
    final updatedWorkspace = _canvasWorkspace.updateActiveDocument(document);
    _canvasWorkspace = updatedWorkspace;
    _canvasAutosaveController.schedule(updatedWorkspace);
  }

  void _selectCanvasDraft(String key) {
    final updatedWorkspace = _canvasWorkspace.activate(key);
    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    _canvasAutosaveController.schedule(updatedWorkspace);
  }

  Future<void> _createBlankCanvasDraft() async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    final now = DateTime.now();
    final graphName = '空白草稿 ${_canvasWorkspace.drafts.length + 1}';
    final emptyDocument = GraphDocument.empty();
    final document = emptyDocument.copyWith(
      graph: emptyDocument.graph.copyWith(
        id: 'manual_${now.microsecondsSinceEpoch}',
        title: '${workspace.name} / $graphName',
        description: '手工创建的空白节点图草稿。',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final draft = CanvasDraft(
      key: canvasDraftKey(
        assetPath: 'manual:${workspace.id}:${now.microsecondsSinceEpoch}',
        graphName: graphName,
      ),
      assetName: workspace.name,
      assetPath: 'manual:${workspace.id}',
      graphName: graphName,
      document: document,
    );
    final updatedWorkspace = _canvasWorkspace.upsert(draft);

    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);
    _showMessage('已创建空白草稿：$graphName');
  }

  Future<void> _exportActiveCanvasDraft() async {
    final workspace = _activeWorkspace;
    final draft = _canvasWorkspace.activeDraft;
    if (workspace == null || draft == null) {
      _showMessage('没有可导出的当前画布');
      return;
    }

    final file = await _storageService.exportGraphDocument(
      workspaceId: workspace.id,
      fileName: '${draft.assetName}_${draft.graphName}.json',
      document: draft.document,
    );
    _showMessage('已导出：${file.path}');
  }

  Future<void> _importLatestCanvasDraft() async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    final directory = _storageService.graphExportDirectory(workspace.id);
    if (!await directory.exists()) {
      _showMessage('没有找到可导入的 JSON 目录');
      return;
    }

    final files =
        await directory
              .list()
              .where(
                (entity) => entity is File && entity.path.endsWith('.json'),
              )
              .cast<File>()
              .toList()
          ..sort((a, b) {
            final aTime = a.statSync().modified;
            final bTime = b.statSync().modified;
            return bTime.compareTo(aTime);
          });
    if (files.isEmpty) {
      _showMessage('没有找到可导入的 JSON 文件');
      return;
    }

    final file = files.first;
    final document = await _storageService.importGraphDocument(file);
    final graphName = _graphNameFromDocument(document, file);
    final draft = CanvasDraft(
      key: canvasDraftKey(
        assetPath: 'import:${workspace.id}:${file.path}',
        graphName: graphName,
      ),
      assetName: workspace.name,
      assetPath: 'import:${file.path}',
      graphName: graphName,
      document: document,
    );
    final updatedWorkspace = _canvasWorkspace.upsert(draft);

    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);
    _showMessage('已导入：${file.path}');
  }

  Future<void> _importGraphPackage() async {
    if (_activeWorkspace == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择 GraphIndex.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      _showMessage('没有读取到 GraphIndex.json 路径');
      return;
    }

    final indexFile = File(selectedPath.trim());
    if (indexFile.uri.pathSegments.last.toLowerCase() != 'graphindex.json') {
      _showMessage('请选择 GraphIndex.json 文件');
      return;
    }

    final importResult = await _graphPackageService.loadPackageFromIndexFile(
      indexFile,
    );
    await _applyGraphPackageImportResult(importResult);
  }

  Future<void> _importGraphPackageFromDirectory(Directory directory) async {
    final result = await _graphPackageService.loadPackage(directory);
    await _applyGraphPackageImportResult(result);
  }

  Future<void> _applyGraphPackageImportResult(
    BlueprintBridgeGraphPackageResult result,
  ) async {
    if (!mounted) {
      return;
    }

    if (result.importedCount == 0) {
      final detail = result.warnings.isEmpty ? '' : '：${result.warnings.first}';
      _showMessage('${result.message}$detail');
      return;
    }

    var updatedWorkspace = _canvasWorkspace;
    for (final draft in result.workspace.orderedDrafts) {
      updatedWorkspace = updatedWorkspace.upsert(draft, activateDraft: false);
    }
    final activeImportedKey = result.workspace.activeKey;
    if (activeImportedKey != null) {
      updatedWorkspace = updatedWorkspace.activate(activeImportedKey);
    }

    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);

    final warningSuffix = result.warnings.isEmpty
        ? ''
        : '，${result.warnings.length} 个提示';
    _showMessage('${result.message}$warningSuffix');
  }

  Future<void> _writeExampleGraphPackage() async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    final directory = _graphPackageDirectory(workspace);
    await _graphPackageService.writeExamplePackage(directory);
    if (!mounted) {
      return;
    }

    await _importGraphPackageFromDirectory(directory);
  }

  String _graphNameFromDocument(GraphDocument document, File file) {
    final title = document.graph.title.trim();
    if (title.contains('/')) {
      final graphName = title.split('/').last.trim();
      if (graphName.isNotEmpty) {
        return graphName;
      }
    }
    if (title.isNotEmpty) {
      return title;
    }

    final separator = Platform.pathSeparator;
    final fileName = file.path.split(separator).last;
    return fileName.toLowerCase().endsWith('.json')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
  }

  Directory _graphPackageDirectory(WorkspaceSummary workspace) {
    final workspacePath = workspace.workspacePath.trim();
    if (workspacePath.isEmpty) {
      return _storageService.graphExportDirectory(workspace.id);
    }

    return File(workspacePath).parent;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _resetActiveCanvas() async {
    final activeKey = _canvasWorkspace.activeKey;
    if (activeKey == null) {
      return;
    }

    await _resetCanvasDraft(activeKey);
  }

  Future<void> _resetCanvasDraft(String draftKey) async {
    final workspace = _activeWorkspace;
    final activeDraft = _canvasWorkspace.drafts[draftKey];
    final importSummary = _importSummary;
    if (workspace == null || activeDraft == null) {
      return;
    }
    if (activeDraft.assetPath.startsWith('legacy:')) {
      _showMessage('旧单画布缓存暂不支持重置');
      return;
    }

    await _canvasAutosaveController.flush();

    final graphPackageDocument = await _graphPackageService
        .loadOriginalDocumentForDraft(
          root: _graphPackageDirectory(workspace),
          draft: activeDraft,
        );
    if (!mounted) {
      return;
    }
    if (graphPackageDocument != null) {
      await _replaceCanvasDraftDocument(
        activeDraft: activeDraft,
        document: graphPackageDocument,
        message: '已重置蓝图：${activeDraft.graphName}',
      );
      return;
    }

    if (importSummary == null) {
      _showMessage('没有可用于重置的 GetTheMeaning 识别数据');
      return;
    }

    final asset = importSummary.assets
        .where((asset) => asset.assetPath == activeDraft.assetPath)
        .firstOrNull;
    if (asset == null) {
      _showMessage('没有找到这张草稿对应的识别资产');
      return;
    }

    final detail = await _logicDetailService.load(
      exportPath: workspace.getTheMeaningExportPath,
      asset: asset,
    );
    if (!mounted || !detail.available) {
      _showMessage('没有读取到这张蓝图的逻辑识别文件');
      return;
    }

    final flows = _flowsForDraft(activeDraft, detail.controlFlows);
    if (flows.isEmpty) {
      _showMessage('没有找到这张草稿对应的初始执行线');
      return;
    }

    final document =
        await _logicGraphDocumentBuilder.buildFromAsset(
          exportPath: workspace.getTheMeaningExportPath,
          asset: asset,
          graphName: activeDraft.graphName == '全部执行线'
              ? 'EventGraph'
              : activeDraft.graphName,
        ) ??
        _flowGraphBuilder.build(
          assetName: activeDraft.assetName,
          graphName: activeDraft.graphName,
          flows: flows,
        );
    await _replaceCanvasDraftDocument(
      activeDraft: activeDraft,
      document: document,
      message: '已重置蓝图：${activeDraft.graphName}',
    );
  }

  Future<void> _replaceCanvasDraftDocument({
    required CanvasDraft activeDraft,
    required GraphDocument document,
    required String message,
  }) async {
    final updatedWorkspace = _canvasWorkspace.upsert(
      activeDraft.copyWith(document: document),
    );

    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);
    _showMessage(message);
  }

  Future<void> _renameCanvasDraft(String draftKey) async {
    final draft = _canvasWorkspace.drafts[draftKey];
    if (draft == null) {
      return;
    }

    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => _RenameCanvasDraftDialog(draft: draft),
    );
    if (!mounted || nextName == null) {
      return;
    }

    await _canvasAutosaveController.flush();
    final updatedWorkspace = _canvasWorkspace.renameDraft(draftKey, nextName);
    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);
    _showMessage('已重命名草稿：$nextName');
  }

  Future<void> _deleteCanvasDraft(String draftKey) async {
    final draft = _canvasWorkspace.drafts[draftKey];
    if (draft == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteCanvasDraftDialog(draft: draft),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    await _canvasAutosaveController.flush();
    final updatedWorkspace = _canvasWorkspace.removeDraft(draftKey);
    setState(() {
      _canvasWorkspace = updatedWorkspace;
      _section = updatedWorkspace.activeDraft == null
          ? WorkspaceSection.overview
          : WorkspaceSection.canvas;
    });
    await _saveCanvasWorkspace(updatedWorkspace);
    _showMessage('已删除本地草稿：${draft.graphName}');
  }

  Future<void> _openCanvasDraftFolder(String draftKey) async {
    final workspace = _activeWorkspace;
    if (workspace == null || !_canvasWorkspace.drafts.containsKey(draftKey)) {
      return;
    }

    final directory = _graphPackageDirectory(workspace);
    if (!await directory.exists()) {
      _showMessage('没有找到草稿文件夹：${directory.path}');
      return;
    }

    await Process.start('explorer.exe', [directory.path]);
  }

  List<BlueprintControlFlow> _flowsForDraft(
    CanvasDraft draft,
    List<BlueprintControlFlow> flows,
  ) {
    if (draft.graphName == '全部执行线') {
      return flows;
    }

    return flows
        .where((flow) => flow.graphName == draft.graphName)
        .toList(growable: false);
  }

  GetTheMeaningAssetSummary? _firstBlueprintAsset(
    GetTheMeaningImportSummary summary,
  ) {
    for (final asset in summary.assets) {
      if (asset.type == 'Blueprint' || asset.type == 'WidgetBlueprint') {
        return asset;
      }
    }

    return null;
  }
}

class _WorkspaceLoadingPage extends StatelessWidget {
  const _WorkspaceLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
          ),
        ),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _WorkspaceHomePage extends StatelessWidget {
  const _WorkspaceHomePage({
    required this.appState,
    required this.onOpenWorkspace,
    required this.onBindUnrealProject,
    required this.onCreateDraftProject,
    required this.onOpenSettings,
  });

  final BridgeAppState appState;
  final ValueChanged<WorkspaceSummary> onOpenWorkspace;
  final VoidCallback onBindUnrealProject;
  final VoidCallback onCreateDraftProject;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF), Color(0xFFF8FBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _RecentWorkspacesPanel(
                        workspaces: appState.recentWorkspaces,
                        onOpenWorkspace: onOpenWorkspace,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 2,
                      child: _WorkspaceActionsPanel(
                        onBindUnrealProject: onBindUnrealProject,
                        onCreateDraftProject: onCreateDraftProject,
                        onOpenSettings: onOpenSettings,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentWorkspacesPanel extends StatelessWidget {
  const _RecentWorkspacesPanel({
    required this.workspaces,
    required this.onOpenWorkspace,
  });

  final List<WorkspaceSummary> workspaces;
  final ValueChanged<WorkspaceSummary> onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_mosaic, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Text(
                  '虚幻：蓝图连结',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF102033),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '多项目蓝图知识工作台',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF526276)),
            ),
            const SizedBox(height: 26),
            Text(
              '最近项目',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: workspaces.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final workspace = workspaces[index];

                  return _WorkspaceListItem(
                    workspace: workspace,
                    onTap: () => onOpenWorkspace(workspace),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceListItem extends StatelessWidget {
  const _WorkspaceListItem({required this.workspace, required this.onTap});

  final WorkspaceSummary workspace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDraft = workspace.unrealProjectPath.trim().isEmpty;

    return Material(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                  ),
                ),
                child: Icon(
                  isDraft ? Icons.note_alt_outlined : Icons.account_tree,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDraft ? '草稿项目' : workspace.unrealProjectPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF526276),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceActionsPanel extends StatelessWidget {
  const _WorkspaceActionsPanel({
    required this.onBindUnrealProject,
    required this.onCreateDraftProject,
    required this.onOpenSettings,
  });

  final VoidCallback onBindUnrealProject;
  final VoidCallback onCreateDraftProject;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '项目入口',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _ActionTile(
              icon: Icons.link_outlined,
              title: '绑定虚幻项目',
              subtitle: '选择 .uproject 并建立工作区',
              onTap: onBindUnrealProject,
            ),
            _ActionTile(
              icon: Icons.note_add_outlined,
              title: '创建草稿项目',
              subtitle: '创建不绑定 Unreal 的独立草稿工作区',
              onTap: onCreateDraftProject,
            ),
            _ActionTile(
              icon: Icons.tune_outlined,
              title: '整体设置',
              subtitle: '配置工作区、导入路径和通用偏好',
              onTap: onOpenSettings,
            ),
            const Spacer(),
            Text(
              'PC: Saved/BlueprintBridge\nAndroid: 应用私有工作区',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF526276),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2563EB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF526276),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateDraftProjectDialog extends StatefulWidget {
  const _CreateDraftProjectDialog();

  @override
  State<_CreateDraftProjectDialog> createState() =>
      _CreateDraftProjectDialogState();
}

class _CreateDraftProjectDialogState extends State<_CreateDraftProjectDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: 'AI 图例草稿',
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建草稿项目'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '草稿项目不绑定 Unreal，适合让 AI 生成流程图、规则图、系统设计图，再导入为 BlueprintBridge 图包。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526276)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '草稿项目名称',
                hintText: '例如：选人流程草稿',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.note_add_outlined),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('创建'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入草稿项目名称');
      return;
    }

    Navigator.of(context).pop(name);
  }
}

class _RenameCanvasDraftDialog extends StatefulWidget {
  const _RenameCanvasDraftDialog({required this.draft});

  final CanvasDraft draft;

  @override
  State<_RenameCanvasDraftDialog> createState() =>
      _RenameCanvasDraftDialogState();
}

class _RenameCanvasDraftDialogState extends State<_RenameCanvasDraftDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.draft.graphName,
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名草稿'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.draft.assetName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '草稿名称',
                hintText: '例如：门交互开关逻辑',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.drive_file_rename_outline),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: const Text('确定'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入草稿名称');
      return;
    }

    Navigator.of(context).pop(name);
  }
}

class _DeleteCanvasDraftDialog extends StatelessWidget {
  const _DeleteCanvasDraftDialog({required this.draft});

  final CanvasDraft draft;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除蓝图草稿'),
      content: SizedBox(
        width: 440,
        child: Text(
          '确定删除「${draft.graphName}」吗？这只会删除本地草稿缓存，不会删除 GraphIndex.json、Graphs 文件或 Unreal 资源。',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526276)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

class _GlobalSettingsDialog extends StatefulWidget {
  const _GlobalSettingsDialog({
    required this.settings,
    required this.updateService,
  });

  final BridgeAppSettings settings;
  final AppUpdateService updateService;

  @override
  State<_GlobalSettingsDialog> createState() => _GlobalSettingsDialogState();
}

class _GlobalSettingsDialogState extends State<_GlobalSettingsDialog> {
  late String _engineNodeBookId = widget.settings.engineNodeBookId;
  AppUpdateCheckResult? _updateResult;
  double? _updateProgress;
  bool _isCheckingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final selectedNodeBook = UnrealNodeCatalog.findNodeBook(_engineNodeBookId);

    return AlertDialog(
      title: const Text('整体设置'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '节点目录',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const ValueKey('engine-node-book-dropdown'),
              initialValue: selectedNodeBook.id,
              decoration: const InputDecoration(
                labelText: '引擎节点本',
                helperText: '当前用于画布右侧节点目录。后续可扩展 UE 版本或项目节点本。',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final nodeBook in UnrealNodeCatalog.nodeBooks)
                  DropdownMenuItem(
                    value: nodeBook.id,
                    child: Text(
                      '${nodeBook.displayName} · ${nodeBook.engineVersion}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _engineNodeBookId = value);
              },
            ),
            const SizedBox(height: 12),
            _SettingsInfoTile(
              label: '当前节点本',
              value: selectedNodeBook.description,
            ),
            const SizedBox(height: 18),
            Text(
              'Windows 更新',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _SettingsInfoTile(
              icon: Icons.system_update_alt,
              label: '更新源',
              value: '默认使用 GitHub Release。平时不需要填写地址，直接点击检查更新即可。',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isCheckingUpdate ? null : _checkUpdate,
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(_isCheckingUpdate ? '检查中' : '检查更新'),
                ),
                const SizedBox(width: 10),
                if (_updateResult?.hasUpdate == true)
                  FilledButton.icon(
                    onPressed: _isCheckingUpdate ? null : _downloadAndUpdate,
                    icon: const Icon(Icons.download),
                    label: const Text('下载并更新'),
                  ),
              ],
            ),
            if (_updateProgress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _updateProgress),
            ],
            if (_updateResult != null) ...[
              const SizedBox(height: 10),
              _SettingsInfoTile(label: '更新状态', value: _updateResult!.message),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(BridgeAppSettings(engineNodeBookId: _engineNodeBookId));
          },
          icon: const Icon(Icons.check),
          label: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
      _updateProgress = null;
      _updateResult = null;
    });
    try {
      final result = await widget.updateService.check(
        manifestUrl: AppUpdateService.defaultManifestUrl,
        currentVersion: _currentAppVersion(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _updateResult = result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _updateResult = AppUpdateCheckResult(
          hasUpdate: false,
          currentVersion: _currentAppVersion(),
          message: '检查更新失败：$error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _downloadAndUpdate() async {
    final result = _updateResult;
    final manifest = result?.manifest;
    final asset = result?.asset;
    if (manifest == null || asset == null) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
      _updateProgress = 0;
    });
    try {
      final download = await widget.updateService.downloadAndVerify(
        manifest: manifest,
        asset: asset,
        onProgress: (progress, message) {
          if (!mounted) {
            return;
          }
          setState(() {
            _updateProgress = progress;
            _updateResult = AppUpdateCheckResult(
              hasUpdate: true,
              currentVersion: _currentAppVersion(),
              manifest: manifest,
              asset: asset,
              message: message,
            );
          });
        },
      );
      await widget.updateService.launchWindowsUpdater(download: download);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(
        () => _updateResult = AppUpdateCheckResult(
          hasUpdate: false,
          currentVersion: _currentAppVersion(),
          manifest: manifest,
          asset: asset,
          message: '更新失败：$error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  String _currentAppVersion() {
    return AppUpdateService.currentVersion;
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.label,
    required this.value,
    this.icon = Icons.menu_book_outlined,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF102033),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF526276),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectWorkspacePage extends StatelessWidget {
  const _ProjectWorkspacePage({
    required this.appState,
    required this.workspace,
    required this.section,
    required this.onSectionChanged,
    required this.isSidebarCollapsed,
    required this.onSidebarCollapsedChanged,
    required this.onSwitchWorkspace,
    required this.importSummary,
    required this.selectedAsset,
    required this.logicDetail,
    required this.isImporting,
    required this.isLoadingLogicDetail,
    required this.canvasWorkspace,
    required this.onSelectedAssetChanged,
    required this.onImportGetTheMeaning,
    required this.onCreateCanvasFromFlows,
    required this.onCanvasDocumentChanged,
    required this.engineNodeBookId,
    required this.onCanvasDraftSelected,
    required this.onResetActiveCanvas,
    required this.onResetCanvasDraft,
    required this.onRenameCanvasDraft,
    required this.onDeleteCanvasDraft,
    required this.onOpenCanvasDraftFolder,
    required this.onCreateBlankCanvasDraft,
    required this.onExportActiveCanvasDraft,
    required this.onImportLatestCanvasDraft,
    required this.onImportGraphPackage,
    required this.onWriteExampleGraphPackage,
    required this.graphPackagePath,
    required this.graphExportPath,
    required this.aiGraphPrompt,
    required this.onBackToHome,
  });

  final BridgeAppState appState;
  final WorkspaceSummary workspace;
  final WorkspaceSection section;
  final ValueChanged<WorkspaceSection> onSectionChanged;
  final bool isSidebarCollapsed;
  final ValueChanged<bool> onSidebarCollapsedChanged;
  final ValueChanged<WorkspaceSummary> onSwitchWorkspace;
  final GetTheMeaningImportSummary? importSummary;
  final GetTheMeaningAssetSummary? selectedAsset;
  final BlueprintLogicDetail? logicDetail;
  final bool isImporting;
  final bool isLoadingLogicDetail;
  final CanvasWorkspace canvasWorkspace;
  final ValueChanged<GetTheMeaningAssetSummary> onSelectedAssetChanged;
  final VoidCallback onImportGetTheMeaning;
  final void Function(String graphName, List<BlueprintControlFlow> flows)
  onCreateCanvasFromFlows;
  final ValueChanged<GraphDocument> onCanvasDocumentChanged;
  final String engineNodeBookId;
  final ValueChanged<String> onCanvasDraftSelected;
  final VoidCallback onResetActiveCanvas;
  final ValueChanged<String> onResetCanvasDraft;
  final ValueChanged<String> onRenameCanvasDraft;
  final ValueChanged<String> onDeleteCanvasDraft;
  final ValueChanged<String> onOpenCanvasDraftFolder;
  final Future<void> Function() onCreateBlankCanvasDraft;
  final Future<void> Function() onExportActiveCanvasDraft;
  final Future<void> Function() onImportLatestCanvasDraft;
  final Future<void> Function() onImportGraphPackage;
  final Future<void> Function() onWriteExampleGraphPackage;
  final String graphPackagePath;
  final String graphExportPath;
  final String aiGraphPrompt;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _WorkspaceTopBar(
                workspace: workspace,
                workspaces: appState.recentWorkspaces,
                onSwitchWorkspace: onSwitchWorkspace,
                isImporting: isImporting,
                onImportGetTheMeaning: onImportGetTheMeaning,
                onCreateBlankCanvasDraft: onCreateBlankCanvasDraft,
                onExportActiveCanvasDraft: onExportActiveCanvasDraft,
                onImportLatestCanvasDraft: onImportLatestCanvasDraft,
                onImportGraphPackage: onImportGraphPackage,
                onWriteExampleGraphPackage: onWriteExampleGraphPackage,
                onBackToHome: onBackToHome,
              ),
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: isSidebarCollapsed ? 72 : 230,
                      child: _WorkspaceSidebar(
                        selected: section,
                        collapsed: isSidebarCollapsed,
                        drafts: canvasWorkspace.orderedDrafts,
                        activeDraftKey: canvasWorkspace.activeKey,
                        onSelected: onSectionChanged,
                        onDraftSelected: onCanvasDraftSelected,
                        onResetDraft: onResetCanvasDraft,
                        onRenameDraft: onRenameCanvasDraft,
                        onDeleteDraft: onDeleteCanvasDraft,
                        onOpenDraftFolder: onOpenCanvasDraftFolder,
                        onCollapsedChanged: onSidebarCollapsedChanged,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _WorkspaceContent(
                              workspace: workspace,
                              section: section,
                              importSummary: importSummary,
                              selectedAsset: selectedAsset,
                              logicDetail: logicDetail,
                              isImporting: isImporting,
                              isLoadingLogicDetail: isLoadingLogicDetail,
                              canvasWorkspace: canvasWorkspace,
                              onCanvasDocumentChanged: onCanvasDocumentChanged,
                              onCanvasDraftSelected: onCanvasDraftSelected,
                              onSelectedAssetChanged: onSelectedAssetChanged,
                              onImportGetTheMeaning: onImportGetTheMeaning,
                              onCreateCanvasFromFlows: onCreateCanvasFromFlows,
                              appStatePath:
                                  '${defaultWorkspaceAppDataDirectory().path}\\app_state.json',
                              engineNodeBookId: engineNodeBookId,
                              graphPackagePath: graphPackagePath,
                              graphExportPath: graphExportPath,
                              aiGraphPrompt: aiGraphPrompt,
                              onResetActiveCanvas: onResetActiveCanvas,
                            ),
                          ),
                          if (section == WorkspaceSection.canvas)
                            const Positioned(
                              top: 0,
                              left: 0,
                              bottom: 0,
                              child: _CanvasEdgeGlow(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.workspace,
    required this.workspaces,
    required this.onSwitchWorkspace,
    required this.isImporting,
    required this.onImportGetTheMeaning,
    required this.onCreateBlankCanvasDraft,
    required this.onExportActiveCanvasDraft,
    required this.onImportLatestCanvasDraft,
    required this.onImportGraphPackage,
    required this.onWriteExampleGraphPackage,
    required this.onBackToHome,
  });

  final WorkspaceSummary workspace;
  final List<WorkspaceSummary> workspaces;
  final ValueChanged<WorkspaceSummary> onSwitchWorkspace;
  final bool isImporting;
  final VoidCallback onImportGetTheMeaning;
  final Future<void> Function() onCreateBlankCanvasDraft;
  final Future<void> Function() onExportActiveCanvasDraft;
  final Future<void> Function() onImportLatestCanvasDraft;
  final Future<void> Function() onImportGraphPackage;
  final Future<void> Function() onWriteExampleGraphPackage;
  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: const BoxDecoration(
        color: Color(0xEFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFD7E7F8))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackToHome,
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: '项目首页',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<WorkspaceSummary>(
            tooltip: '切换项目',
            color: const Color(0xFFF8FBFF),
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD7E7F8)),
            ),
            onSelected: onSwitchWorkspace,
            itemBuilder: (context) {
              return [
                for (final item in workspaces)
                  PopupMenuItem(
                    value: item,
                    padding: EdgeInsets.zero,
                    child: _WorkspaceMenuItem(
                      workspace: item,
                      selected: item.id == workspace.id,
                    ),
                  ),
              ];
            },
            child: Tooltip(
              message: '切换项目',
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD7E7F8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          Icon(
                            workspace.unrealProjectPath.trim().isEmpty
                                ? Icons.note_alt_outlined
                                : Icons.account_tree_outlined,
                            size: 20,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              workspace.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF102033),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Color(0xFF526276),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: isImporting ? null : onImportGetTheMeaning,
            constraints: const BoxConstraints.tightFor(width: 46, height: 46),
            icon: isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            tooltip: isImporting ? '正在导入' : '导入 GetTheMeaning',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_CanvasDraftCommand>(
            tooltip: '草稿操作',
            color: const Color(0xFFF8FBFF),
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            constraints: const BoxConstraints(minWidth: 310, maxWidth: 380),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD7E7F8)),
            ),
            onSelected: (command) {
              switch (command) {
                case _CanvasDraftCommand.createBlank:
                  onCreateBlankCanvasDraft();
                case _CanvasDraftCommand.exportActive:
                  onExportActiveCanvasDraft();
                case _CanvasDraftCommand.importLatest:
                  onImportLatestCanvasDraft();
                case _CanvasDraftCommand.importGraphPackage:
                  onImportGraphPackage();
                case _CanvasDraftCommand.writeExampleGraphPackage:
                  onWriteExampleGraphPackage();
              }
            },
            itemBuilder: (context) {
              return [
                for (final command in _CanvasDraftCommand.values)
                  PopupMenuItem(
                    value: command,
                    padding: EdgeInsets.zero,
                    child: _CanvasDraftMenuItem(command: command),
                  ),
              ];
            },
            child: const _TopBarMenuButton(
              icon: Icons.note_add_outlined,
              label: '草稿',
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存工作区'),
            style: FilledButton.styleFrom(
              fixedSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CanvasDraftCommand {
  createBlank,
  exportActive,
  importLatest,
  importGraphPackage,
  writeExampleGraphPackage,
}

extension _CanvasDraftCommandMeta on _CanvasDraftCommand {
  IconData get icon {
    return switch (this) {
      _CanvasDraftCommand.createBlank => Icons.add_box_outlined,
      _CanvasDraftCommand.exportActive => Icons.upload_file_outlined,
      _CanvasDraftCommand.importLatest => Icons.file_download_outlined,
      _CanvasDraftCommand.importGraphPackage => Icons.account_tree_outlined,
      _CanvasDraftCommand.writeExampleGraphPackage => Icons.auto_awesome_mosaic,
    };
  }

  String get title {
    return switch (this) {
      _CanvasDraftCommand.createBlank => '新建空白草稿',
      _CanvasDraftCommand.exportActive => '导出当前画布 JSON',
      _CanvasDraftCommand.importLatest => '导入最新 JSON 草稿',
      _CanvasDraftCommand.importGraphPackage => '导入 GraphIndex 图包',
      _CanvasDraftCommand.writeExampleGraphPackage => '生成示例图包',
    };
  }

  String get subtitle {
    return switch (this) {
      _CanvasDraftCommand.createBlank => '在当前项目中新建一张空白节点图',
      _CanvasDraftCommand.exportActive => '把当前画布保存为独立 JSON 文件',
      _CanvasDraftCommand.importLatest => '读取最近导出的单张 JSON 草稿',
      _CanvasDraftCommand.importGraphPackage => '导入 AI 生成的 GraphIndex 图包',
      _CanvasDraftCommand.writeExampleGraphPackage => '写入一套协议示例方便检查格式',
    };
  }
}

class _CanvasDraftMenuItem extends StatelessWidget {
  const _CanvasDraftMenuItem({required this.command});

  final _CanvasDraftCommand command;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFEAF4FF),
            ),
            child: Icon(command.icon, size: 19, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF102033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  command.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526276),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceMenuItem extends StatelessWidget {
  const _WorkspaceMenuItem({required this.workspace, required this.selected});

  final WorkspaceSummary workspace;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDraft = workspace.unrealProjectPath.trim().isEmpty;
    final subtitle = isDraft ? '草稿项目' : workspace.unrealProjectPath;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFDBEAFE)
            : Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF93C5FD) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFEAF4FF),
            ),
            child: Icon(
              isDraft ? Icons.note_alt_outlined : Icons.account_tree_outlined,
              size: 19,
              color: selected ? Colors.white : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF102033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526276),
                  ),
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, size: 18, color: Color(0xFF2563EB)),
          ],
        ],
      ),
    );
  }
}

class _TopBarMenuButton extends StatelessWidget {
  const _TopBarMenuButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.selected,
    required this.collapsed,
    required this.drafts,
    required this.activeDraftKey,
    required this.onSelected,
    required this.onDraftSelected,
    required this.onResetDraft,
    required this.onRenameDraft,
    required this.onDeleteDraft,
    required this.onOpenDraftFolder,
    required this.onCollapsedChanged,
  });

  final WorkspaceSection selected;
  final bool collapsed;
  final List<CanvasDraft> drafts;
  final String? activeDraftKey;
  final ValueChanged<WorkspaceSection> onSelected;
  final ValueChanged<String> onDraftSelected;
  final ValueChanged<String> onResetDraft;
  final ValueChanged<String> onRenameDraft;
  final ValueChanged<String> onDeleteDraft;
  final ValueChanged<String> onOpenDraftFolder;
  final ValueChanged<bool> onCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEAF3F8FF),
        border: Border(right: BorderSide(color: Color(0xFFD7E7F8))),
      ),
      padding: EdgeInsets.fromLTRB(
        collapsed ? 8 : 12,
        14,
        collapsed ? 8 : 12,
        12,
      ),
      child: Column(
        children: [
          _SidebarCollapseButton(
            collapsed: collapsed,
            onPressed: () => onCollapsedChanged(!collapsed),
          ),
          const SizedBox(height: 6),
          for (final section in WorkspaceSection.values)
            _SidebarItem(
              section: section,
              selected: selected == section,
              collapsed: collapsed,
              onTap: () => onSelected(section),
            ),
          const SizedBox(height: 12),
          _SidebarSectionHeader(collapsed: collapsed, label: '草稿'),
          const SizedBox(height: 6),
          if (drafts.isEmpty)
            _SidebarEmptyDraftItem(collapsed: collapsed)
          else
            for (final draft in drafts.take(8))
              _SidebarDraftItem(
                draft: draft,
                selected:
                    selected == WorkspaceSection.canvas &&
                    draft.key == activeDraftKey,
                collapsed: collapsed,
                onTap: () => onDraftSelected(draft.key),
                onResetBlueprint: () => onResetDraft(draft.key),
                onRename: () => onRenameDraft(draft.key),
                onDelete: () => onDeleteDraft(draft.key),
                onOpenFolder: () => onOpenDraftFolder(draft.key),
              ),
          const Spacer(),
          if (!collapsed) const _SidebarFooter(),
        ],
      ),
    );
  }
}

class _CanvasEdgeGlow extends StatelessWidget {
  const _CanvasEdgeGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 36,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.28),
                      const Color(0xFF60A5FA).withValues(alpha: 0.13),
                      const Color(0xFF60A5FA).withValues(alpha: 0.04),
                      const Color(0xFF60A5FA).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.22, 0.58, 1],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.36),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.24),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(4, 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarCollapseButton extends StatelessWidget {
  const _SidebarCollapseButton({
    required this.collapsed,
    required this.onPressed,
  });

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: collapsed ? Alignment.center : Alignment.centerLeft,
        child: Material(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: SizedBox(
              width: collapsed ? 48 : double.infinity,
              height: 48,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!collapsed) const SizedBox(width: 12),
                  Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                    size: 22,
                    color: const Color(0xFF2563EB),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Text(
                      '收起',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF102033),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Tooltip(message: collapsed ? '展开侧栏' : '收起侧栏', child: button);
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final WorkspaceSection section;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: collapsed ? Alignment.center : Alignment.centerLeft,
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: collapsed ? 48 : double.infinity,
              height: 48,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!collapsed) const SizedBox(width: 12),
                  Icon(
                    section.icon,
                    size: 22,
                    color: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF526276),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Text(
                      section.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? const Color(0xFF102033)
                            : const Color(0xFF526276),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (collapsed) {
      return Tooltip(message: section.label, child: item);
    }

    return item;
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.collapsed, required this.label});

  final bool collapsed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Tooltip(
        message: label,
        child: const SizedBox(
          width: 48,
          height: 28,
          child: Icon(
            Icons.horizontal_rule,
            size: 18,
            color: Color(0xFF93A4B8),
          ),
        ),
      );
    }

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarDraftItem extends StatelessWidget {
  const _SidebarDraftItem({
    required this.draft,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    required this.onResetBlueprint,
    required this.onRename,
    required this.onDelete,
    required this.onOpenFolder,
  });

  final CanvasDraft draft;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;
  final VoidCallback onResetBlueprint;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final title = draft.graphName.trim().isEmpty
        ? draft.assetName
        : draft.graphName;
    final subtitle = draft.assetName.trim().isEmpty
        ? '未记录蓝图资产'
        : draft.assetName;
    final item = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context: context, position: details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: collapsed ? Alignment.center : Alignment.centerLeft,
          child: Material(
            color: selected
                ? const Color(0xFFDBEAFE)
                : Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: collapsed ? 48 : double.infinity,
                height: collapsed ? 48 : 54,
                child: Row(
                  mainAxisAlignment: collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    if (!collapsed) const SizedBox(width: 12),
                    Icon(
                      Icons.note_alt_outlined,
                      size: 21,
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF526276),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: selected
                                        ? const Color(0xFF102033)
                                        : const Color(0xFF526276),
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (collapsed) {
      return Tooltip(message: title, child: item);
    }

    return item;
  }

  Future<void> _showContextMenu({
    required BuildContext context,
    required Offset position,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selectedCommand = await showMenu<_SidebarDraftCommand>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final command in _SidebarDraftCommand.values)
          PopupMenuItem(
            value: command,
            padding: EdgeInsets.zero,
            child: _SidebarDraftMenuItem(command: command),
          ),
      ],
    );

    switch (selectedCommand) {
      case _SidebarDraftCommand.resetBlueprint:
        onResetBlueprint();
      case _SidebarDraftCommand.rename:
        onRename();
      case _SidebarDraftCommand.openFolder:
        onOpenFolder();
      case _SidebarDraftCommand.delete:
        onDelete();
      case null:
        return;
    }
  }
}

enum _SidebarDraftCommand { resetBlueprint, rename, openFolder, delete }

extension _SidebarDraftCommandMeta on _SidebarDraftCommand {
  IconData get icon {
    return switch (this) {
      _SidebarDraftCommand.resetBlueprint => Icons.restart_alt,
      _SidebarDraftCommand.rename => Icons.drive_file_rename_outline,
      _SidebarDraftCommand.openFolder => Icons.folder_open_outlined,
      _SidebarDraftCommand.delete => Icons.delete_outline,
    };
  }

  String get title {
    return switch (this) {
      _SidebarDraftCommand.resetBlueprint => '重置蓝图',
      _SidebarDraftCommand.rename => '重命名',
      _SidebarDraftCommand.openFolder => '打开文件夹',
      _SidebarDraftCommand.delete => '删除蓝图',
    };
  }

  String get subtitle {
    return switch (this) {
      _SidebarDraftCommand.resetBlueprint => '回到文件识别的最初状态',
      _SidebarDraftCommand.rename => '修改草稿显示名称',
      _SidebarDraftCommand.openFolder => '打开 GraphIndex 图包目录',
      _SidebarDraftCommand.delete => '仅删除本地草稿缓存',
    };
  }

  Color get iconColor {
    return switch (this) {
      _SidebarDraftCommand.delete => const Color(0xFFDC2626),
      _ => const Color(0xFF2563EB),
    };
  }

  Color get iconBackground {
    return switch (this) {
      _SidebarDraftCommand.delete => const Color(0xFFFFEEEE),
      _ => const Color(0xFFEAF4FF),
    };
  }
}

class _SidebarDraftMenuItem extends StatelessWidget {
  const _SidebarDraftMenuItem({required this.command});

  final _SidebarDraftCommand command;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: command.iconBackground,
            ),
            child: Icon(command.icon, size: 19, color: command.iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: command == _SidebarDraftCommand.delete
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF102033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  command.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526276),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarEmptyDraftItem extends StatelessWidget {
  const _SidebarEmptyDraftItem({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const Tooltip(
        message: '暂无草稿',
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.note_add_outlined,
            size: 21,
            color: Color(0xFF93A4B8),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.note_add_outlined,
            size: 20,
            color: Color(0xFF93A4B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '暂无草稿',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Text(
      'BlueprintBridge\nWorkspace v1',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF64748B),
        height: 1.4,
      ),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({
    required this.workspace,
    required this.section,
    required this.importSummary,
    required this.selectedAsset,
    required this.logicDetail,
    required this.isImporting,
    required this.isLoadingLogicDetail,
    required this.canvasWorkspace,
    required this.onSelectedAssetChanged,
    required this.onImportGetTheMeaning,
    required this.onCreateCanvasFromFlows,
    required this.onCanvasDocumentChanged,
    required this.onCanvasDraftSelected,
    required this.onResetActiveCanvas,
    required this.appStatePath,
    required this.engineNodeBookId,
    required this.graphPackagePath,
    required this.graphExportPath,
    required this.aiGraphPrompt,
  });

  final WorkspaceSummary workspace;
  final WorkspaceSection section;
  final GetTheMeaningImportSummary? importSummary;
  final GetTheMeaningAssetSummary? selectedAsset;
  final BlueprintLogicDetail? logicDetail;
  final bool isImporting;
  final bool isLoadingLogicDetail;
  final CanvasWorkspace canvasWorkspace;
  final ValueChanged<GetTheMeaningAssetSummary> onSelectedAssetChanged;
  final VoidCallback onImportGetTheMeaning;
  final void Function(String graphName, List<BlueprintControlFlow> flows)
  onCreateCanvasFromFlows;
  final ValueChanged<GraphDocument> onCanvasDocumentChanged;
  final ValueChanged<String> onCanvasDraftSelected;
  final VoidCallback onResetActiveCanvas;
  final String appStatePath;
  final String engineNodeBookId;
  final String graphPackagePath;
  final String graphExportPath;
  final String aiGraphPrompt;

  @override
  Widget build(BuildContext context) {
    if (section == WorkspaceSection.canvas) {
      return EditorPage(
        showScaffoldChrome: false,
        initialDocument: canvasWorkspace.activeDraft?.document,
        canvasDrafts: canvasWorkspace.orderedDrafts,
        activeCanvasKey: canvasWorkspace.activeKey,
        engineNodeBookId: engineNodeBookId,
        onCanvasDraftSelected: onCanvasDraftSelected,
        onResetActiveCanvas: onResetActiveCanvas,
        onDocumentChanged: onCanvasDocumentChanged,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: switch (section) {
        WorkspaceSection.overview => WorkspaceOverviewView(
          workspace: workspace,
          importSummary: importSummary,
          appStatePath: appStatePath,
          graphPackagePath: graphPackagePath,
          graphExportPath: graphExportPath,
          aiGraphPrompt: aiGraphPrompt,
        ),
        WorkspaceSection.blueprints => BlueprintAssetsView(
          summary: importSummary,
          selectedAsset: selectedAsset,
          logicDetail: logicDetail,
          isLoadingLogicDetail: isLoadingLogicDetail,
          isImporting: isImporting,
          canvasDrafts: canvasWorkspace.orderedDrafts,
          activeCanvasKey: canvasWorkspace.activeKey,
          graphPackagePath: graphPackagePath,
          onSelectedAssetChanged: onSelectedAssetChanged,
          onImportRequested: onImportGetTheMeaning,
          onCreateCanvasFromFlows: onCreateCanvasFromFlows,
          onCanvasDraftSelected: onCanvasDraftSelected,
        ),
        WorkspaceSection.cpp => const _PlaceholderCollectionView(
          title: 'C++ 类型',
          subtitle: '后续会显示 UCLASS、USTRUCT、UENUM、函数签名和引用关系。',
          icon: Icons.code,
        ),
        WorkspaceSection.data => const _PlaceholderCollectionView(
          title: '数据层',
          subtitle: 'DataTable、Struct、Enum 会在这里形成项目数据地图。',
          icon: Icons.table_chart_outlined,
        ),
        WorkspaceSection.risks => const _PlaceholderCollectionView(
          title: '风险摘要',
          subtitle: '未使用返回值、未连接 Break、RPC 默认参数等提示会集中显示。',
          icon: Icons.report_gmailerrorred_outlined,
        ),
        WorkspaceSection.canvas => const SizedBox.shrink(),
      },
    );
  }
}

class WorkspaceOverviewView extends StatelessWidget {
  const WorkspaceOverviewView({
    required this.workspace,
    required this.importSummary,
    required this.appStatePath,
    required this.graphPackagePath,
    required this.graphExportPath,
    required this.aiGraphPrompt,
    super.key,
  });

  final WorkspaceSummary workspace;
  final GetTheMeaningImportSummary? importSummary;
  final String appStatePath;
  final String graphPackagePath;
  final String graphExportPath;
  final String aiGraphPrompt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 18),
      child: _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workspace.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                workspace.unrealProjectPath,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF526276),
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: '资产',
                    value: _formatCount(importSummary?.assetCount),
                  ),
                  _MetricCard(
                    label: '蓝图',
                    value: _formatCount(importSummary?.blueprintCount),
                  ),
                  _MetricCard(
                    label: 'C++ 类',
                    value: _formatCount(importSummary?.cppClassCount),
                  ),
                  _MetricCard(
                    label: '关系边',
                    value: _formatCount(importSummary?.graphEdgeCount),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AiGraphPromptPanel(
                prompt: aiGraphPrompt,
                triggerPrompt: '触发图例生成：目标工作区「幻杀图例草稿」，需求：<写清楚要画的蓝图逻辑>',
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 24),
              _ImportStatusBanner(summary: importSummary),
              const SizedBox(height: 14),
              _InfoRow(label: '工作区', value: workspace.workspacePath),
              _InfoRow(label: '应用状态', value: appStatePath),
              _InfoRow(label: '图包协议', value: graphPackagePath),
              _InfoRow(label: '草稿 JSON', value: graphExportPath),
              _InfoRow(
                label: 'GetTheMeaning',
                value: workspace.getTheMeaningExportPath,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int? value) {
    if (value == null) {
      return '待导入';
    }

    return value.toString();
  }
}

class _ImportStatusBanner extends StatelessWidget {
  const _ImportStatusBanner({required this.summary});

  final GetTheMeaningImportSummary? summary;

  @override
  Widget build(BuildContext context) {
    final current = summary;
    final available = current?.available ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: available ? const Color(0xFFDBEAFE) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: available ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              available ? Icons.check_circle_outline : Icons.info_outline,
              color: available
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFB45309),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                current?.message ??
                    '尚未找到 GetTheMeaning 导出数据，请在虚幻项目中使用 GetTheMeaning 插件导出。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: available
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF7C2D12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7E7F8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: const Color(0xFF526276)),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '未设置' : value)),
        ],
      ),
    );
  }
}

class _PlaceholderCollectionView extends StatelessWidget {
  const _PlaceholderCollectionView({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: const Color(0xFF2563EB)),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF526276),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E7F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}
