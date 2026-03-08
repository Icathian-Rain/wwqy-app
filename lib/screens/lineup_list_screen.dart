import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent.dart';
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
        title: Text('${widget.mapName} - 点位'),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Filter bar
              _buildFilterBar(context, provider),
              const Divider(height: 1),
              // Lineup list
              Expanded(
                child: provider.lineups.isEmpty
                    ? const Center(
                        child: Text('暂无点位记录，点击右下角添加'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.lineups.length,
                        itemBuilder: (context, index) {
                          final lineup = provider.lineups[index];
                          return FutureBuilder<Agent?>(
                            future: provider.getAgentById(lineup.agentId),
                            builder: (context, snapshot) {
                              final agentName = snapshot.data?.name ?? '';
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  title: Text(lineup.title),
                                  subtitle: Text(
                                    '$agentName · ${lineup.side == 'attack' ? '进攻' : '防守'} · ${lineup.site}点',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LineupDetailScreen(
                                          lineup: lineup,
                                        ),
                                      ),
                                    );
                                    _loadLineups();
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, LineupProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Agent filter
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
          // Side filter
          _buildDropdown<String?>(
            value: provider.selectedSide,
            hint: '攻防',
            items: const [
              DropdownMenuItem(value: null, child: Text('全部')),
              DropdownMenuItem(value: 'attack', child: Text('进攻')),
              DropdownMenuItem(value: 'defense', child: Text('防守')),
            ],
            onChanged: (val) {
              provider.setSideFilter(val);
              _loadLineups();
            },
          ),
          // Site filter
          _buildDropdown<String?>(
            value: provider.selectedSite,
            hint: '包点',
            items: const [
              DropdownMenuItem(value: null, child: Text('全部')),
              DropdownMenuItem(value: 'A', child: Text('A点')),
              DropdownMenuItem(value: 'B', child: Text('B点')),
              DropdownMenuItem(value: 'C', child: Text('C点')),
            ],
            onChanged: (val) {
              provider.setSiteFilter(val);
              _loadLineups();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
          isDense: true,
        ),
      ),
    );
  }
}
