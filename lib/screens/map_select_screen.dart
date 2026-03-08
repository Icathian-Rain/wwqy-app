import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lineup_provider.dart';
import 'lineup_list_screen.dart';

class MapSelectScreen extends StatefulWidget {
  final String gameId;
  final String gameName;

  const MapSelectScreen({
    super.key,
    required this.gameId,
    required this.gameName,
  });

  @override
  State<MapSelectScreen> createState() => _MapSelectScreenState();
}

class _MapSelectScreenState extends State<MapSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LineupProvider>().loadMaps(widget.gameId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.gameName} - 选择地图'),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          final maps = provider.maps;
          if (maps.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: maps.length,
              itemBuilder: (context, index) {
                final map = maps[index];
                return Card(
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LineupListScreen(
                            gameId: widget.gameId,
                            gameName: widget.gameName,
                            mapId: map.id,
                            mapName: map.name,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            map.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
