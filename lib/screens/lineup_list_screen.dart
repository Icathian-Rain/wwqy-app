import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lineup_provider.dart';
import 'add_lineup_screen.dart';
import 'lineup_detail_screen.dart';

class LineupListScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final String mapId;
  final String mapName;

  const LineupListScreen({
    super.key,
    required this.gameId,
    required this.gameName,
    required this.mapId,
    required this.mapName,
  });

  @override
  State<LineupListScreen> createState() => _LineupListScreenState();
}

class _LineupListScreenState extends State<LineupListScreen> {
  bool _filterExpanded = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LineupProvider>();
      provider.loadAgents(widget.gameId);
      _loadLineups();
    });
  }

  void _loadLineups() {
    context.read<LineupProvider>().loadLineups(
          gameId: widget.gameId,
          mapId: widget.mapId,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mapName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标题或说明…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          final agentNameById = {
            for (final agent in provider.agents) agent.id: agent.name,
          };
          final filtered = provider.lineups.where((lineup) {
            if (_searchQuery.isEmpty) return true;
            final title = lineup.title.toLowerCase();
            final description = lineup.description.toLowerCase();
            final agentName = (agentNameById[lineup.agentId] ?? '').toLowerCase();
            final side = lineup.side == 'attack' ? '进攻' : '防守';
            final site = '${lineup.site}点';
            return title.contains(_searchQuery) ||
                description.contains(_searchQuery) ||
                agentName.contains(_searchQuery) ||
                side.contains(_searchQuery) ||
                site.contains(_searchQuery);
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final content = _buildLineupContent(
                context,
                provider,
                agentNameById,
                filtered,
              );

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 320,
                                child: _buildFilterPanel(context, provider, filtered.length),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: content),
                            ],
                          )
                        : Column(
                            children: [
                              _buildFilterPanel(context, provider, filtered.length),
                              const SizedBox(height: 16),
                              Expanded(child: content),
                            ],
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLineupScreen(
                gameId: widget.gameId,
                mapId: widget.mapId,
                mapName: widget.mapName,
              ),
            ),
          );
          _loadLineups();
        },
        icon: const Icon(Icons.add),
        label: const Text('添加点位'),
      ),
    );
  }

  Widget _buildLineupContent(
    BuildContext context,
    LineupProvider provider,
    Map<String, String> agentNameById,
    List filtered,
  ) {
    final theme = Theme.of(context);

    if (provider.loading) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (provider.error != null) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _loadLineups,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (provider.lineups.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '当前地图暂无点位记录',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角按钮，添加当前地图的首个战术点位。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.manage_search_rounded,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '没有符合条件的点位',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请尝试调整搜索词或清空筛选条件。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    final provider = context.read<LineupProvider>();
                    provider.clearFilters();
                    _loadLineups();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('清空搜索与筛选'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lineup = filtered[index];
          final agentName = agentNameById[lineup.agentId] ?? '未知特工';
          final thumbPath = provider.lineupFirstImages[lineup.id];

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LineupDetailScreen(lineup: lineup),
                ),
              );
              _loadLineups();
            },
            child: Ink(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thumbPath != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                      child: Image.file(
                        File(thumbPath),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        cacheWidth: 180,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 90, height: 90),
                      ),
                    )
                  else
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
                      ),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lineup.title,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Chip(label: Text(agentName)),
                              Chip(label: Text(lineup.side == 'attack' ? '进攻' : '防守')),
                              Chip(label: Text('${lineup.site}点')),
                            ],
                          ),
                          if (lineup.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              lineup.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPanel(
    BuildContext context,
    LineupProvider provider,
    int filteredCount,
  ) {
    final theme = Theme.of(context);
    final activeFilters = [
      provider.selectedAgentId,
      provider.selectedSide,
      provider.selectedSite,
      _searchQuery.isEmpty ? null : _searchQuery,
    ].where((element) => element != null).length;
    final selectedAgentName = provider.selectedAgentId == null
        ? '全部'
        : provider.agents
                .where((agent) => agent.id == provider.selectedAgentId)
                .map((agent) => agent.name)
                .firstOrNull ??
            '全部';

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => setState(() => _filterExpanded = !_filterExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text('筛选', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (activeFilters > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$activeFilters',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _filterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_filterExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '当前结果 $filteredCount 条',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('特工', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showAgentFilterDialog(context, provider),
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text('选择特工：$selectedAgentName'),
                  ),
                  const SizedBox(height: 12),
                  Text('攻防', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(children: [
                    _filterChip(context, label: '全部', selected: provider.selectedSide == null,
                      onTap: () { provider.setSideFilter(null); _loadLineups(); }),
                    _filterChip(context, label: '进攻', selected: provider.selectedSide == 'attack',
                      onTap: () { provider.setSideFilter(provider.selectedSide == 'attack' ? null : 'attack'); _loadLineups(); }),
                    _filterChip(context, label: '防守', selected: provider.selectedSide == 'defense',
                      onTap: () { provider.setSideFilter(provider.selectedSide == 'defense' ? null : 'defense'); _loadLineups(); }),
                  ]),
                  const SizedBox(height: 12),
                  Text('包点', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(children: [
                    _filterChip(context, label: '全部', selected: provider.selectedSite == null,
                      onTap: () { provider.setSiteFilter(null); _loadLineups(); }),
                    for (final site in ['A', 'B', 'C'])
                      _filterChip(context, label: '$site点', selected: provider.selectedSite == site,
                        onTap: () { provider.setSiteFilter(provider.selectedSite == site ? null : site); _loadLineups(); }),
                  ]),
                  if (activeFilters > 0) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _searchController.clear();
                        provider.clearFilters();
                        _loadLineups();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('清空搜索与筛选'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAgentFilterDialog(
    BuildContext context,
    LineupProvider provider,
  ) async {
    final groupedAgents = <String, List<dynamic>>{};
    for (final agent in provider.agents) {
      groupedAgents.putIfAbsent(agent.role, () => []).add(agent);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final dialogWidth = mediaQuery.size.width * 0.92;
        final dialogHeight = mediaQuery.size.height * 0.78;

        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth > 520 ? 520 : dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '选择特工',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _filterChip(
                                context,
                                label: '全部',
                                selected: provider.selectedAgentId == null,
                                onTap: () {
                                  provider.setAgentFilter(null);
                                  Navigator.pop(dialogContext);
                                  _loadLineups();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...groupedAgents.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final agent in entry.value)
                                        _filterChip(
                                          context,
                                          label: agent.name,
                                          selected: provider.selectedAgentId == agent.id,
                                          onTap: () {
                                            provider.setAgentFilter(
                                              provider.selectedAgentId == agent.id ? null : agent.id,
                                            );
                                            Navigator.pop(dialogContext);
                                            _loadLineups();
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primary.withOpacity(0.2),
        checkmarkColor: theme.colorScheme.primary,
      ),
    );
  }
}
