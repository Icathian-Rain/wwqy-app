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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LineupProvider>();
      provider.clearFilters();
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mapName),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          final agentNameById = {
            for (final agent in provider.agents) agent.id: agent.name,
          };

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final content = _buildLineupContent(
                context,
                provider,
                agentNameById,
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
                                child: _buildFilterPanel(context, provider),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: content),
                            ],
                          )
                        : Column(
                            children: [
                              _buildFilterPanel(context, provider),
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

  Widget _buildFilterPanel(BuildContext context, LineupProvider provider) {
    final theme = Theme.of(context);
    final activeFilters = [
      provider.selectedAgentId,
      provider.selectedSide,
      provider.selectedSite,
    ].where((e) => e != null).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  '筛选条件',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              activeFilters == 0 ? '当前显示全部点位。' : '已启用 $activeFilters 个筛选条件。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _buildDropdown<String?>(
              value: provider.selectedAgentId,
              hint: '特工',
              items: [
                const DropdownMenuItem(value: null, child: Text('全部特工')),
                ...provider.agents.map(
                  (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                ),
              ],
              onChanged: (val) {
                provider.setAgentFilter(val);
                _loadLineups();
              },
            ),
            const SizedBox(height: 12),
            _buildDropdown<String?>(
              value: provider.selectedSide,
              hint: '攻防',
              items: const [
                DropdownMenuItem(value: null, child: Text('全部阵营')),
                DropdownMenuItem(value: 'attack', child: Text('进攻')),
                DropdownMenuItem(value: 'defense', child: Text('防守')),
              ],
              onChanged: (val) {
                provider.setSideFilter(val);
                _loadLineups();
              },
            ),
            const SizedBox(height: 12),
            _buildDropdown<String?>(
              value: provider.selectedSite,
              hint: '包点',
              items: const [
                DropdownMenuItem(value: null, child: Text('全部包点')),
                DropdownMenuItem(value: 'A', child: Text('A点')),
                DropdownMenuItem(value: 'B', child: Text('B点')),
                DropdownMenuItem(value: 'C', child: Text('C点')),
              ],
              onChanged: (val) {
                provider.setSiteFilter(val);
                _loadLineups();
              },
            ),
            const SizedBox(height: 16),
            if (activeFilters > 0)
              TextButton.icon(
                onPressed: () {
                  provider.clearFilters();
                  _loadLineups();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('清空筛选'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineupContent(
    BuildContext context,
    LineupProvider provider,
    Map<String, String> agentNameById,
  ) {
    final theme = Theme.of(context);

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
                  '暂无点位记录',
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

    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: provider.lineups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final lineup = provider.lineups[index];
          final agentName = agentNameById[lineup.agentId] ?? '未知特工';

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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lineup.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(agentName)),
                      Chip(
                        label:
                            Text(lineup.side == 'attack' ? '进攻' : '防守'),
                      ),
                      Chip(label: Text('${lineup.site}点')),
                    ],
                  ),
                  if (lineup.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      lineup.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: hint,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
