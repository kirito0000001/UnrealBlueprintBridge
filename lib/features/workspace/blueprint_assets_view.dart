import 'package:flutter/material.dart';

import '../../core/workspace/ai_graph_prompt_builder.dart';
import '../../core/workspace/blueprint_logic_detail_service.dart';
import '../../core/workspace/canvas_workspace.dart';
import '../../core/workspace/get_the_meaning_import_service.dart';
import 'ai_graph_prompt_panel.dart';

class BlueprintAssetsView extends StatefulWidget {
  const BlueprintAssetsView({
    super.key,
    required this.summary,
    required this.selectedAsset,
    this.logicDetail,
    this.isLoadingLogicDetail = false,
    this.isImporting = false,
    this.canvasDrafts = const <CanvasDraft>[],
    this.activeCanvasKey,
    this.graphPackagePath = '',
    required this.onSelectedAssetChanged,
    required this.onImportRequested,
    required this.onCreateCanvasFromFlows,
    this.onCanvasDraftSelected,
  });

  final GetTheMeaningImportSummary? summary;
  final GetTheMeaningAssetSummary? selectedAsset;
  final BlueprintLogicDetail? logicDetail;
  final bool isLoadingLogicDetail;
  final bool isImporting;
  final List<CanvasDraft> canvasDrafts;
  final String? activeCanvasKey;
  final String graphPackagePath;
  final ValueChanged<GetTheMeaningAssetSummary> onSelectedAssetChanged;
  final VoidCallback onImportRequested;
  final void Function(String graphName, List<BlueprintControlFlow> flows)
  onCreateCanvasFromFlows;
  final ValueChanged<String>? onCanvasDraftSelected;

  @override
  State<BlueprintAssetsView> createState() => _BlueprintAssetsViewState();
}

class _BlueprintAssetsViewState extends State<BlueprintAssetsView> {
  String _query = '';
  _AssetTypeFilter _filter = _AssetTypeFilter.all;

  @override
  Widget build(BuildContext context) {
    final currentSummary = widget.summary;
    if (currentSummary == null) {
      return _ImportPrompt(
        title: '先导入 GetTheMeaning',
        message: '点击顶部导入按钮，或在这里直接读取当前项目的导出目录，然后就能查看蓝图资产索引。',
        buttonLabel: widget.isImporting ? '正在导入' : '导入 GetTheMeaning',
        isLoading: widget.isImporting,
        onPressed: widget.onImportRequested,
      );
    }

    if (!currentSummary.available) {
      return _ImportPrompt(
        title: '没有可用的导出索引',
        message: currentSummary.message,
        buttonLabel: widget.isImporting ? '正在导入' : '重新导入',
        isLoading: widget.isImporting,
        onPressed: widget.onImportRequested,
      );
    }

    final assets = _blueprintAssets(currentSummary.assets);
    if (assets.isEmpty) {
      return _ImportPrompt(
        title: '没有蓝图资产',
        message: '导出索引存在，但还没有识别到 Blueprint 或 WidgetBlueprint。可以重新导出项目后再导入。',
        buttonLabel: widget.isImporting ? '正在导入' : '重新导入',
        isLoading: widget.isImporting,
        onPressed: widget.onImportRequested,
      );
    }

    final visibleAssets = _filterAssets(assets);
    final selected = _effectiveSelection(
      visibleAssets.isEmpty ? assets : visibleAssets,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final list = _AssetListPane(
          allAssetCount: assets.length,
          visibleAssets: visibleAssets,
          selectedAsset: selected,
          query: _query,
          filter: _filter,
          onQueryChanged: (value) => setState(() => _query = value),
          onFilterChanged: (value) => setState(() => _filter = value),
          onSelectedAssetChanged: widget.onSelectedAssetChanged,
        );
        final detail = _AssetDetailPane(
          asset: selected,
          logicDetail: widget.logicDetail,
          isLoadingLogicDetail: widget.isLoadingLogicDetail,
          canvasDrafts: widget.canvasDrafts,
          activeCanvasKey: widget.activeCanvasKey,
          graphPackagePath: widget.graphPackagePath,
          onCreateCanvasFromFlows: widget.onCreateCanvasFromFlows,
          onCanvasDraftSelected: widget.onCanvasDraftSelected,
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(height: 260, child: list),
              const SizedBox(height: 14),
              Expanded(child: detail),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 330, child: list),
            const SizedBox(width: 16),
            Expanded(child: detail),
          ],
        );
      },
    );
  }

  List<GetTheMeaningAssetSummary> _blueprintAssets(
    List<GetTheMeaningAssetSummary> assets,
  ) {
    return assets
        .where(
          (asset) =>
              asset.type == 'Blueprint' || asset.type == 'WidgetBlueprint',
        )
        .toList(growable: false);
  }

  GetTheMeaningAssetSummary _effectiveSelection(
    List<GetTheMeaningAssetSummary> assets,
  ) {
    final selected = widget.selectedAsset;
    if (selected == null) {
      return assets.first;
    }

    for (final asset in assets) {
      if (asset.assetPath == selected.assetPath &&
          asset.name == selected.name) {
        return asset;
      }
    }

    return assets.first;
  }

  List<GetTheMeaningAssetSummary> _filterAssets(
    List<GetTheMeaningAssetSummary> assets,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();

    return assets
        .where((asset) {
          if (!_matchesTypeFilter(asset)) {
            return false;
          }

          if (normalizedQuery.isEmpty) {
            return true;
          }

          return _searchText(asset).contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  bool _matchesTypeFilter(GetTheMeaningAssetSummary asset) {
    return switch (_filter) {
      _AssetTypeFilter.all => true,
      _AssetTypeFilter.blueprint => asset.type == 'Blueprint',
      _AssetTypeFilter.widget => _isWidgetAsset(asset),
      _AssetTypeFilter.gameMode => asset.parentClass.toLowerCase().contains(
        'gamemode',
      ),
    };
  }

  String _searchText(GetTheMeaningAssetSummary asset) {
    return [
      asset.name,
      asset.displayName,
      asset.type,
      asset.assetPath,
      asset.packagePath,
      asset.parentClass,
    ].join('\n').toLowerCase();
  }
}

bool _isWidgetAsset(GetTheMeaningAssetSummary asset) {
  return asset.type == 'WidgetBlueprint' ||
      asset.parentClass.toLowerCase().contains('userwidget');
}

enum _AssetTypeFilter {
  all('全部'),
  blueprint('Blueprint'),
  widget('Widget'),
  gameMode('GameMode');

  const _AssetTypeFilter(this.label);

  final String label;
}

class _AssetListPane extends StatelessWidget {
  const _AssetListPane({
    required this.allAssetCount,
    required this.visibleAssets,
    required this.selectedAsset,
    required this.query,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSelectedAssetChanged,
  });

  final int allAssetCount;
  final List<GetTheMeaningAssetSummary> visibleAssets;
  final GetTheMeaningAssetSummary selectedAsset;
  final String query;
  final _AssetTypeFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_AssetTypeFilter> onFilterChanged;
  final ValueChanged<GetTheMeaningAssetSummary> onSelectedAssetChanged;

  @override
  Widget build(BuildContext context) {
    final tree = AssetFolderTree.fromAssets(visibleAssets);

    return _AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '蓝图资产',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF102033),
                    ),
                  ),
                ),
                _CountPill(label: visibleAssets.length.toString()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索名称、路径、父类',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () => onQueryChanged(''),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.72),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7E7F8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD7E7F8)),
                ),
              ),
              controller: TextEditingController(text: query)
                ..selection = TextSelection.collapsed(offset: query.length),
              onChanged: onQueryChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final filter in _AssetTypeFilter.values)
                  _FilterChipButton(
                    label: filter.label,
                    selected: this.filter == filter,
                    onTap: () => onFilterChanged(filter),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFD7E7F8)),
          Expanded(
            child: visibleAssets.isEmpty
                ? const _EmptyFilteredAssets()
                : Scrollbar(
                    child: ListView(
                      padding: const EdgeInsets.all(10),
                      children: [
                        for (final folder in tree.rootFolders)
                          _FolderTreeNodeView(
                            folder: folder,
                            depth: 0,
                            selectedAsset: selectedAsset,
                            onSelectedAssetChanged: onSelectedAssetChanged,
                          ),
                        for (final asset in tree.rootAssets)
                          _AssetListTile(
                            asset: asset,
                            depth: 0,
                            selected:
                                asset.assetPath == selectedAsset.assetPath &&
                                asset.name == selectedAsset.name,
                            onTap: () => onSelectedAssetChanged(asset),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFDBEAFE),
      backgroundColor: Colors.white.withValues(alpha: 0.68),
      side: const BorderSide(color: Color(0xFFD7E7F8)),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF526276),
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

class _EmptyFilteredAssets extends StatelessWidget {
  const _EmptyFilteredAssets();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          '没有匹配资产',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AssetListTile extends StatelessWidget {
  const _AssetListTile({
    required this.asset,
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  final GetTheMeaningAssetSummary asset;
  final int depth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWidgetAsset = _isWidgetAsset(asset);

    return Material(
      color: selected
          ? const Color(0xFFDBEAFE)
          : Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + depth * 18, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: isWidgetAsset
                        ? const [Color(0xFF2563EB), Color(0xFF06B6D4)]
                        : const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  ),
                ),
                child: Icon(
                  isWidgetAsset ? Icons.widgets_outlined : Icons.account_tree,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF102033),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      asset.packagePath.isEmpty
                          ? asset.type
                          : asset.packagePath,
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
        ),
      ),
    );
  }
}

class _AssetDetailPane extends StatefulWidget {
  const _AssetDetailPane({
    required this.asset,
    required this.logicDetail,
    required this.isLoadingLogicDetail,
    required this.canvasDrafts,
    required this.activeCanvasKey,
    required this.graphPackagePath,
    required this.onCreateCanvasFromFlows,
    required this.onCanvasDraftSelected,
  });

  final GetTheMeaningAssetSummary asset;
  final BlueprintLogicDetail? logicDetail;
  final bool isLoadingLogicDetail;
  final List<CanvasDraft> canvasDrafts;
  final String? activeCanvasKey;
  final String graphPackagePath;
  final void Function(String graphName, List<BlueprintControlFlow> flows)
  onCreateCanvasFromFlows;
  final ValueChanged<String>? onCanvasDraftSelected;

  @override
  State<_AssetDetailPane> createState() => _AssetDetailPaneState();
}

class _AssetDetailPaneState extends State<_AssetDetailPane> {
  String? _selectedGraphName;
  String _graphPromptRequest = '';
  final _canvasActionKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _AssetDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.assetPath != widget.asset.assetPath ||
        oldWidget.logicDetail != widget.logicDetail) {
      _selectedGraphName = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFlows = _activeControlFlows();
    final activeGraphName = _selectedGraphName ?? '全部';
    final assetDrafts = _assetCanvasDrafts();
    final activeDraft = _canvasDraftForGraphName(assetDrafts, activeGraphName);
    final canvasAction = activeFlows.isEmpty
        ? null
        : _CanvasActionButton(
            existingDraft: activeDraft,
            onOpenDraft: widget.onCanvasDraftSelected,
            onCreateCanvas: () =>
                widget.onCreateCanvasFromFlows(activeGraphName, activeFlows),
          );
    final graphPrompt = const AiGraphPromptBuilder().buildForAssetGraph(
      asset: widget.asset,
      graphName: activeGraphName,
      graphPackagePath: widget.graphPackagePath,
      flows: activeFlows,
      userRequest: _graphPromptRequest,
    );

    return _AssetPanel(
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                      ),
                    ),
                    child: const Icon(
                      Icons.schema_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.asset.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFF102033),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.asset.displayName.isEmpty
                              ? widget.asset.type
                              : widget.asset.displayName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF526276)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(label: widget.asset.type),
                  _MetaPill(
                    label: widget.asset.parentClass.isEmpty
                        ? 'Parent 未记录'
                        : widget.asset.parentClass,
                  ),
                  _MetaPill(label: '${widget.asset.functions.length} 函数'),
                  _MetaPill(label: '${widget.asset.variables.length} 变量'),
                ],
              ),
              const SizedBox(height: 20),
              _InfoLine(label: 'AssetPath', value: widget.asset.assetPath),
              _InfoLine(label: 'Package', value: widget.asset.packagePath),
              _InfoLine(label: 'Parent', value: widget.asset.parentClass),
              _InfoLine(label: 'Readable', value: widget.asset.readablePath),
              _InfoLine(label: 'Logic JSON', value: widget.asset.logicJsonPath),
              const SizedBox(height: 16),
              _AssetCanvasDraftSection(
                drafts: assetDrafts,
                activeCanvasKey: widget.activeCanvasKey,
                onSelected: widget.onCanvasDraftSelected,
              ),
              _TagSection(title: 'Variables', values: widget.asset.variables),
              _TagSection(title: 'Events', values: widget.asset.events),
              _TagSection(title: 'RPC', values: widget.asset.rpcs),
              _TagSection(title: 'Functions', values: widget.asset.functions),
              _TagSection(title: 'Calls', values: widget.asset.calls),
              const SizedBox(height: 4),
              _LogicDetailSection(
                detail: widget.logicDetail,
                isLoading: widget.isLoadingLogicDetail,
                selectedGraphName: _selectedGraphName,
                canvasAction: canvasAction,
                graphPrompt: graphPrompt,
                graphPromptRequest: _graphPromptRequest,
                canvasActionKey: _canvasActionKey,
                onSelectedGraphChanged: (graphName) =>
                    _selectGraphName(graphName),
                onGraphPromptRequestChanged: (value) =>
                    setState(() => _graphPromptRequest = value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<BlueprintControlFlow> _activeControlFlows() {
    final detail = widget.logicDetail;
    if (detail == null || !detail.available) {
      return const <BlueprintControlFlow>[];
    }

    final graphName = _selectedGraphName;
    if (graphName == null) {
      return detail.controlFlows;
    }

    return detail.controlFlows
        .where((flow) => flow.graphName == graphName)
        .toList(growable: false);
  }

  List<CanvasDraft> _assetCanvasDrafts() {
    return widget.canvasDrafts
        .where((draft) => draft.assetPath == widget.asset.assetPath)
        .toList(growable: false)
      ..sort((a, b) => a.graphName.compareTo(b.graphName));
  }

  CanvasDraft? _canvasDraftForGraphName(
    List<CanvasDraft> drafts,
    String graphName,
  ) {
    final draftGraphName = graphName == '全部' ? '全部执行线' : graphName;

    for (final draft in drafts) {
      if (draft.graphName == draftGraphName) {
        return draft;
      }
    }

    return null;
  }

  void _selectGraphName(String? graphName) {
    setState(() => _selectedGraphName = graphName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCanvasAction());
  }

  void _revealCanvasAction() {
    final context = _canvasActionKey.currentContext;
    if (context == null) {
      return;
    }

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }
}

class _LogicDetailSection extends StatefulWidget {
  const _LogicDetailSection({
    required this.detail,
    required this.isLoading,
    required this.selectedGraphName,
    required this.canvasAction,
    required this.graphPrompt,
    required this.graphPromptRequest,
    required this.canvasActionKey,
    required this.onSelectedGraphChanged,
    required this.onGraphPromptRequestChanged,
  });

  final BlueprintLogicDetail? detail;
  final bool isLoading;
  final String? selectedGraphName;
  final Widget? canvasAction;
  final String graphPrompt;
  final String graphPromptRequest;
  final GlobalKey canvasActionKey;
  final ValueChanged<String?> onSelectedGraphChanged;
  final ValueChanged<String> onGraphPromptRequestChanged;

  @override
  State<_LogicDetailSection> createState() => _LogicDetailSectionState();
}

class _LogicDetailSectionState extends State<_LogicDetailSection> {
  @override
  Widget build(BuildContext context) {
    final current = widget.detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '逻辑深读',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF102033),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            if (widget.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.isLoading)
          _LogicStatusBanner(message: '正在读取 Logic JSON...')
        else if (current == null)
          _LogicStatusBanner(message: '选择资产后会在这里读取 Logic JSON。')
        else if (!current.available)
          _LogicStatusBanner(message: current.message)
        else ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SmallMetric(label: '入口', value: current.entryPoints.length),
              _SmallMetric(label: '执行线', value: current.controlFlowCount),
              _SmallMetric(label: '调用', value: current.callCount),
              _SmallMetric(label: '风险', value: current.warnings.length),
            ],
          ),
          const SizedBox(height: 14),
          if (current.gameModeDefaults.isNotEmpty)
            _MapSection(
              title: 'GameMode Defaults',
              values: current.gameModeDefaults,
            ),
          _LogicSlicePicker(
            entryPoints: current.entryPoints,
            selectedGraphName: _effectiveGraphName(current),
            onSelected: widget.onSelectedGraphChanged,
          ),
          _GraphPromptRequestField(
            value: widget.graphPromptRequest,
            onChanged: widget.onGraphPromptRequestChanged,
          ),
          if (widget.canvasAction != null)
            Padding(
              key: widget.canvasActionKey,
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  widget.canvasAction!,
                  CopyAiGraphPromptButton(
                    prompt: widget.graphPrompt,
                    label: '复制此图例提示词',
                    icon: Icons.auto_awesome,
                  ),
                ],
              ),
            ),
          _ControlFlowPreviewSection(
            flows: _filterByGraph(
              current.controlFlows,
              (flow) => flow.graphName,
              current,
            ),
          ),
          _EntryPointSection(
            entryPoints: _filterByGraph(
              current.entryPoints,
              (entry) => entry.graphName,
              current,
            ),
          ),
          _WarningSection(
            warnings: _filterByGraph(
              current.warnings,
              (warning) => warning.graphName,
              current,
            ),
          ),
          _BranchRouteSection(
            routes: _filterByGraph(
              current.branchRoutes,
              (route) => route.graphName,
              current,
            ),
          ),
          _CallParameterSection(
            calls: _filterByGraph(
              current.callParameters,
              (call) => call.graphName,
              current,
            ),
          ),
          _CommentBoxSection(
            commentBoxes: _filterByGraph(
              current.commentBoxes,
              (comment) => comment.graphName,
              current,
            ),
          ),
        ],
      ],
    );
  }

  String? _effectiveGraphName(BlueprintLogicDetail detail) {
    final selected = widget.selectedGraphName;
    if (selected == null) {
      return null;
    }

    for (final entry in detail.entryPoints) {
      if (entry.graphName == selected) {
        return selected;
      }
    }

    return null;
  }

  List<T> _filterByGraph<T>(
    List<T> values,
    String Function(T value) graphNameOf,
    BlueprintLogicDetail detail,
  ) {
    final graphName = _effectiveGraphName(detail);
    if (graphName == null) {
      return values;
    }

    return values
        .where((value) => graphNameOf(value) == graphName)
        .toList(growable: false);
  }
}

class _CanvasActionButton extends StatelessWidget {
  const _CanvasActionButton({
    required this.existingDraft,
    required this.onOpenDraft,
    required this.onCreateCanvas,
  });

  final CanvasDraft? existingDraft;
  final ValueChanged<String>? onOpenDraft;
  final VoidCallback onCreateCanvas;

  @override
  Widget build(BuildContext context) {
    final draft = existingDraft;
    final canOpenExisting = draft != null && onOpenDraft != null;

    return FilledButton.tonalIcon(
      onPressed: canOpenExisting
          ? () => onOpenDraft?.call(draft.key)
          : onCreateCanvas,
      icon: Icon(
        canOpenExisting ? Icons.open_in_new : Icons.account_tree_outlined,
        size: 18,
      ),
      label: Text(canOpenExisting ? '查看画布' : '创建画布'),
    );
  }
}

class _GraphPromptRequestField extends StatelessWidget {
  const _GraphPromptRequestField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: '图例需求',
          hintText: '例如：生成一个开门逻辑',
          prefixIcon: const Icon(Icons.edit_note),
          isDense: true,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7E7F8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD7E7F8)),
          ),
        ),
      ),
    );
  }
}

class _AssetCanvasDraftSection extends StatelessWidget {
  const _AssetCanvasDraftSection({
    required this.drafts,
    required this.activeCanvasKey,
    required this.onSelected,
  });

  final List<CanvasDraft> drafts;
  final String? activeCanvasKey;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (drafts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7E7F8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Color(0xFF2563EB),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '画布草稿',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF102033),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _CountPill(label: '${drafts.length} 张'),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final draft in drafts)
                    _AssetCanvasDraftChip(
                      draft: draft,
                      selected: draft.key == activeCanvasKey,
                      onTap: onSelected == null
                          ? null
                          : () => onSelected?.call(draft.key),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCanvasDraftChip extends StatelessWidget {
  const _AssetCanvasDraftChip({
    required this.draft,
    required this.selected,
    required this.onTap,
  });

  final CanvasDraft draft;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFDBEAFE)
          : Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: selected ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF526276),
              ),
              const SizedBox(width: 6),
              Text(
                draft.graphName,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? const Color(0xFF1E3A8A)
                      : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Text(
                  '当前',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogicSlicePicker extends StatelessWidget {
  const _LogicSlicePicker({
    required this.entryPoints,
    required this.selectedGraphName,
    required this.onSelected,
  });

  final List<BlueprintEntryPoint> entryPoints;
  final String? selectedGraphName;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (entryPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final seen = <String>{};
    final slices = <BlueprintEntryPoint>[];
    for (final entry in entryPoints) {
      if (entry.graphName.isEmpty) {
        continue;
      }
      if (seen.add(entry.graphName)) {
        slices.add(entry);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: selectedGraphName == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final entry in slices)
            ChoiceChip(
              label: Text(entry.graphName),
              selected: selectedGraphName == entry.graphName,
              onSelected: (_) => onSelected(entry.graphName),
            ),
        ],
      ),
    );
  }
}

class _LogicStatusBanner extends StatelessWidget {
  const _LogicStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF526276)),
        ),
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF526276),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({required this.title, required this.values});

  final String title;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return _DetailBlock(
      title: title,
      children: [
        for (final entry in values.entries)
          _InfoLine(label: entry.key, value: entry.value),
      ],
    );
  }
}

class _ControlFlowPreviewSection extends StatelessWidget {
  const _ControlFlowPreviewSection({required this.flows});

  final List<BlueprintControlFlow> flows;

  @override
  Widget build(BuildContext context) {
    if (flows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '执行线预览',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF102033),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7E7F8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final flow in flows.take(18))
                    _ControlFlowLine(flow: flow),
                  if (flows.length > 18)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+${flows.length - 18} 条执行线',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlFlowLine extends StatelessWidget {
  const _ControlFlowLine({required this.flow});

  final BlueprintControlFlow flow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: flow.depth.clamp(0, 8) * 14, bottom: 7),
      child: SelectableText(
        _formatFlow(flow),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF1E293B),
          height: 1.35,
          fontWeight: flow.kind == 'then' ? FontWeight.w600 : FontWeight.w800,
        ),
      ),
    );
  }

  String _formatFlow(BlueprintControlFlow flow) {
    final from = _compactNodeTitle(flow.fromNodeTitle);
    final to = _compactNodeTitle(flow.toNodeTitle);
    final kind = flow.kind.trim();
    if (kind.isEmpty || kind == 'then') {
      return '$from -> $to';
    }

    return '$from -- $kind -> $to';
  }

  String _compactNodeTitle(String title) {
    final normalized = title
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' / ');
    if (normalized.isEmpty) {
      return '未命名节点';
    }

    return normalized;
  }
}

class _EntryPointSection extends StatelessWidget {
  const _EntryPointSection({required this.entryPoints});

  final List<BlueprintEntryPoint> entryPoints;

  @override
  Widget build(BuildContext context) {
    return _DetailBlock(
      title: '入口点',
      children: [
        for (final entry in entryPoints.take(12))
          _CompactLine(
            title: entry.name,
            subtitle:
                '${entry.graphName} / ${entry.type} / ${entry.replication}${entry.reliable ? ' / Reliable' : ''}',
          ),
      ],
    );
  }
}

class _WarningSection extends StatelessWidget {
  const _WarningSection({required this.warnings});

  final List<BlueprintLogicWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DetailBlock(
      title: '风险提示',
      children: [
        for (final warning in warnings.take(8))
          _CompactLine(
            title: warning.category,
            subtitle:
                '${warning.graphName} / ${warning.nodeTitle}\n${warning.message}${warning.details.isEmpty ? '' : '\n${warning.details}'}',
          ),
      ],
    );
  }
}

class _BranchRouteSection extends StatelessWidget {
  const _BranchRouteSection({required this.routes});

  final List<BlueprintBranchRoute> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DetailBlock(
      title: 'Branch 路由',
      children: [
        for (final route in routes.take(8))
          _CompactLine(
            title: route.condition.isEmpty ? route.nodeTitle : route.condition,
            subtitle:
                '${route.graphName}\nTrue -> ${_empty(route.trueTarget)}\nFalse -> ${_empty(route.falseTarget)}',
          ),
      ],
    );
  }
}

class _CallParameterSection extends StatelessWidget {
  const _CallParameterSection({required this.calls});

  final List<BlueprintCallParameterTable> calls;

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DetailBlock(
      title: '调用参数',
      children: [
        for (final call in calls.take(8))
          _CompactLine(
            title: call.functionName,
            subtitle: [
              call.graphName,
              call.ownerClass,
              for (final parameter in call.parameters.take(5))
                '${parameter.name} = ${_empty(parameter.value.isEmpty ? parameter.defaultValue : parameter.value)}${parameter.linked ? ' (linked)' : ''}',
            ].where((value) => value.isNotEmpty).join('\n'),
          ),
      ],
    );
  }
}

class _CommentBoxSection extends StatelessWidget {
  const _CommentBoxSection({required this.commentBoxes});

  final List<BlueprintCommentBox> commentBoxes;

  @override
  Widget build(BuildContext context) {
    if (commentBoxes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DetailBlock(
      title: '注释框',
      children: [
        for (final comment in commentBoxes.take(8))
          _CompactLine(title: comment.text, subtitle: comment.graphName),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFF102033),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E7F8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? '未命名' : title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF102033),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526276),
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _empty(String value) {
  return value.isEmpty ? '<empty>' : value;
}

class _ImportPrompt extends StatelessWidget {
  const _ImportPrompt({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.isLoading,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _AssetPanel(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.file_download_outlined,
                  size: 48,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF102033),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF526276),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: isLoading ? null : onPressed,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderTreeNodeView extends StatelessWidget {
  const _FolderTreeNodeView({
    required this.folder,
    required this.depth,
    required this.selectedAsset,
    required this.onSelectedAssetChanged,
  });

  final AssetFolderNode folder;
  final int depth;
  final GetTheMeaningAssetSummary selectedAsset;
  final ValueChanged<GetTheMeaningAssetSummary> onSelectedAssetChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey<String>(folder.fullPath),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.only(left: 2 + depth * 16, right: 8),
      childrenPadding: EdgeInsets.zero,
      minTileHeight: 38,
      visualDensity: VisualDensity.compact,
      leading: const Icon(
        Icons.folder_open_outlined,
        color: Color(0xFF1D4ED8),
        size: 20,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF102033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CountPill(label: folder.totalAssetCount.toString()),
        ],
      ),
      children: [
        for (final childFolder in folder.folders)
          _FolderTreeNodeView(
            folder: childFolder,
            depth: depth + 1,
            selectedAsset: selectedAsset,
            onSelectedAssetChanged: onSelectedAssetChanged,
          ),
        for (final asset in folder.assets)
          _AssetListTile(
            asset: asset,
            depth: depth + 1,
            selected:
                asset.assetPath == selectedAsset.assetPath &&
                asset.name == selectedAsset.name,
            onTap: () => onSelectedAssetChanged(asset),
          ),
      ],
    );
  }
}

class AssetFolderTree {
  const AssetFolderTree({required this.rootFolders, required this.rootAssets});

  factory AssetFolderTree.fromAssets(List<GetTheMeaningAssetSummary> assets) {
    final mutableRoot = _MutableAssetFolderNode(name: '', fullPath: '');
    final rootAssets = <GetTheMeaningAssetSummary>[];

    for (final asset in assets) {
      final parts = _packageParts(asset.packagePath);
      if (parts.isEmpty) {
        rootAssets.add(asset);
        continue;
      }

      var current = mutableRoot;
      var currentPath = '';
      for (final part in parts) {
        currentPath = currentPath.isEmpty ? part : '$currentPath/$part';
        current = current.folder(part, currentPath);
      }
      current.assets.add(asset);
    }

    return AssetFolderTree(
      rootFolders: mutableRoot.toImmutable().folders,
      rootAssets: rootAssets,
    );
  }

  final List<AssetFolderNode> rootFolders;
  final List<GetTheMeaningAssetSummary> rootAssets;

  static List<String> _packageParts(String packagePath) {
    final normalized = packagePath.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final parts = normalized
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return const <String>[];
    }

    if (parts.first == 'Game') {
      return ['/Game', ...parts.skip(1)];
    }

    return parts;
  }
}

class AssetFolderNode {
  const AssetFolderNode({
    required this.name,
    required this.fullPath,
    required this.folders,
    required this.assets,
    required this.totalAssetCount,
  });

  final String name;
  final String fullPath;
  final List<AssetFolderNode> folders;
  final List<GetTheMeaningAssetSummary> assets;
  final int totalAssetCount;
}

class _MutableAssetFolderNode {
  _MutableAssetFolderNode({required this.name, required this.fullPath});

  final String name;
  final String fullPath;
  final Map<String, _MutableAssetFolderNode> folders =
      <String, _MutableAssetFolderNode>{};
  final List<GetTheMeaningAssetSummary> assets = <GetTheMeaningAssetSummary>[];

  _MutableAssetFolderNode folder(String name, String fullPath) {
    return folders.putIfAbsent(
      name,
      () => _MutableAssetFolderNode(name: name, fullPath: fullPath),
    );
  }

  AssetFolderNode toImmutable() {
    final childFolders =
        folders.values
            .map((folder) => folder.toImmutable())
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));
    final sortedAssets = [...assets]..sort((a, b) => a.name.compareTo(b.name));
    final totalAssetCount =
        sortedAssets.length +
        childFolders.fold<int>(
          0,
          (total, folder) => total + folder.totalAssetCount,
        );

    return AssetFolderNode(
      name: name,
      fullPath: fullPath,
      folders: childFolders,
      assets: sortedAssets,
      totalAssetCount: totalAssetCount,
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF102033),
                ),
              ),
              const SizedBox(width: 8),
              _CountPill(label: values.length.toString()),
            ],
          ),
          const SizedBox(height: 8),
          if (values.isEmpty)
            Text(
              '未记录',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in values.take(48)) _TagPill(label: value),
                if (values.length > 48)
                  _TagPill(label: '+${values.length - 48}'),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

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
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF526276),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '未记录' : value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF102033)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: label,
      background: const Color(0xFFDBEAFE),
      foreground: const Color(0xFF1E3A8A),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: label,
      background: Colors.white.withValues(alpha: 0.72),
      foreground: const Color(0xFF1E3A8A),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: label,
      background: const Color(0xFFF1F7FF),
      foreground: const Color(0xFF2563EB),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E7F8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AssetPanel extends StatelessWidget {
  const _AssetPanel({required this.child});

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
      child: Material(color: Colors.transparent, child: child),
    );
  }
}
