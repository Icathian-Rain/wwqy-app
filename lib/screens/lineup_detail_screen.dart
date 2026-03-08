import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import '../providers/lineup_provider.dart';

class LineupDetailScreen extends StatefulWidget {
  final Lineup lineup;

  const LineupDetailScreen({super.key, required this.lineup});

  @override
  State<LineupDetailScreen> createState() => _LineupDetailScreenState();
}

class _LineupDetailScreenState extends State<LineupDetailScreen> {
  List<LineupImage> _images = [];
  String _agentName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<LineupProvider>();
    final images = await provider.getLineupImages(widget.lineup.id);
    final agent = await provider.getAgentById(widget.lineup.agentId);
    setState(() {
      _images = images;
      _agentName = agent?.name ?? '';
      _loading = false;
    });
  }

  Future<void> _deleteLineup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个点位记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<LineupProvider>().deleteLineup(widget.lineup.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('点位详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lineup = widget.lineup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('点位详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteLineup,
          ),
        ],
      ),
      body: ListView(
        children: [
          // Image carousel
          if (_images.isNotEmpty)
            SizedBox(
              height: 300,
              child: PageView.builder(
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _showFullImage(context, _images[index].imagePath),
                    child: Image.file(
                      File(_images[index].imagePath),
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ),
          if (_images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '左右滑动查看 ${_images.length} 张图片',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),

          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lineup.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(_agentName)),
                    Chip(
                      label: Text(
                          lineup.side == 'attack' ? '进攻' : '防守'),
                    ),
                    Chip(label: Text('${lineup.site}点')),
                  ],
                ),
                const SizedBox(height: 16),
                if (lineup.description.isNotEmpty) ...[
                  Text(
                    '说明',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(lineup.description),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }
}
