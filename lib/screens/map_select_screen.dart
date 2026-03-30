import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lineup_provider.dart';
import '../services/lineup_transfer_service.dart';
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
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LineupProvider>().loadMaps(widget.gameId);
    });
  }

  Future<void> _exportLineups() async {
    setState(() => _processing = true);
    try {
      final provider = context.read<LineupProvider>();
      final result = await provider.exportLineupsForGame(
        widget.gameId,
        widget.gameName,
      );
      await provider.shareExportedBundle(result.zipPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出完成：${result.lineupCount} 条点位，${result.imageCount} 张图片'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _importLineups() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final zipPath = picked?.files.single.path;
    if (zipPath == null || !mounted) return;

    final provider = context.read<LineupProvider>();
    setState(() => _processing = true);

    LineupImportPreview? preview;
    try {
      preview = await provider.previewImportFromZip(zipPath);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _processing = false);

    final skipDuplicates = await _showImportPreviewDialog(preview);
    if (skipDuplicates == null) return;

    setState(() => _processing = true);
    try {
      final result = await provider.importLineupsFromZip(
        zipPath,
        skipDuplicates: skipDuplicates,
      );
      await provider.loadMaps(widget.gameId);
      if (!mounted) return;
      final skippedText = result.skippedLineupCount > 0
          ? '，跳过 ${result.skippedLineupCount} 条重复点位'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入成功：${result.lineupCount} 条点位，${result.imageCount} 张图片$skippedText'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<bool?> _showImportPreviewDialog(LineupImportPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('导入预检结果'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('点位：${preview.lineupCount} 条'),
                  Text('图片：${preview.imageCount} 张'),
                  Text('涉及地图：${preview.mapNames.join('、')}'),
                  if (preview.duplicateCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '检测到 ${preview.duplicateCount} 条可能重复点位',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('提示', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ...preview.warnings.map((warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $warning'),
                        )),
                  ],
                  if (preview.blockingIssues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '以下问题会阻止导入',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...preview.blockingIssues.map((issue) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $issue',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
            if (preview.canImport)
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('跳过重复后导入'),
              ),
            if (preview.canImport)
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续追加导入'),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameName),
        actions: [
          PopupMenuButton<String>(
            enabled: !_processing,
            onSelected: (value) {
              if (value == 'import') {
                _importLineups();
              } else if (value == 'export') {
                _exportLineups();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('导入 ZIP'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('导出当前游戏'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<LineupProvider>(
            builder: (context, provider, _) {
              final maps = provider.maps;
              if (maps.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final counts = provider.mapLineupCounts;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1200
                      ? 4
                      : width >= 840
                          ? 3
                          : 2;

                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.map_rounded,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '选择地图',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '进入地图后可查看点位列表，并按特工、攻防和包点进行筛选。',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '共 ${maps.length} 张地图',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 200,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: maps.length,
                            itemBuilder: (context, index) {
                              final map = maps[index];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary.withOpacity(0.14),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.place_rounded,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          map.name,
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${counts[map.id] ?? 0} 条点位',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Text(
                                              '查看点位',
                                              style: theme.textTheme.labelLarge?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 18,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_processing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(0.18),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
