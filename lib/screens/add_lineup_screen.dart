import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/lineup.dart';
import '../models/lineup_image.dart';
import '../providers/lineup_provider.dart';
import '../utils/image_helper.dart';

class AddLineupScreen extends StatefulWidget {
  final String gameId;
  final String mapId;
  final String mapName;

  const AddLineupScreen({
    super.key,
    required this.gameId,
    required this.mapId,
    required this.mapName,
  });

  @override
  State<AddLineupScreen> createState() => _AddLineupScreenState();
}

class _AddLineupScreenState extends State<AddLineupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();

  String? _selectedAgentId;
  String _selectedSide = 'attack';
  String _selectedSite = 'A';
  final List<File> _selectedImages = [];
  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LineupProvider>().loadAgents(widget.gameId);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImageHelper.pickImage(source: source);
    if (file != null) {
      setState(() => _selectedImages.add(file));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _save() async {
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgentId == null || _selectedImages.isEmpty) {
      return;
    }

    setState(() => _saving = true);

    final lineupId = _uuid.v4();
    final lineup = Lineup(
      id: lineupId,
      gameId: widget.gameId,
      mapId: widget.mapId,
      agentId: _selectedAgentId!,
      side: _selectedSide,
      site: _selectedSite,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    final images = <LineupImage>[];
    for (var i = 0; i < _selectedImages.length; i++) {
      images.add(LineupImage(
        id: _uuid.v4(),
        lineupId: lineupId,
        imagePath: _selectedImages[i].path,
        sortOrder: i,
      ));
    }

    await context.read<LineupProvider>().addLineup(lineup, images);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('添加点位 · ${widget.mapName}'),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1024;
              final formSection = _buildFormSection(context, provider);
              final imageSection = _buildImageSection(context);

              return Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '录入新的战术点位',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '请先填写基础信息，再补充图片和使用说明。图片会复制到应用本地目录中保存。',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: formSection),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: imageSection),
                            ],
                          )
                        else ...[
                          formSection,
                          const SizedBox(height: 16),
                          imageSection,
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('保存点位'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFormSection(BuildContext context, LineupProvider provider) {
    return Column(
      children: [
        _buildSectionCard(
          context: context,
          title: '基础信息',
          subtitle: '先确定特工和点位标题。带 * 的字段为必填项。',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedAgentId,
                decoration: InputDecoration(
                  labelText: '选择特工 *',
                  errorText:
                      _submitted && _selectedAgentId == null ? '请选择特工' : null,
                ),
                items: provider.agents
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} (${a.role})'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedAgentId = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题 *',
                  hintText: '例如：A包烟雾弹点位',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? '请输入标题' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '说明',
                  hintText: '描述站位位置、瞄准点、释放时机等信息',
                  helperText: '建议写清楚站位、准星位置和适用场景。',
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context: context,
          title: '战术属性',
          subtitle: '选择该点位适用的阵营和包点。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '阵营',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('进攻'),
                    selected: _selectedSide == 'attack',
                    onSelected: (_) => setState(() => _selectedSide = 'attack'),
                  ),
                  ChoiceChip(
                    label: const Text('防守'),
                    selected: _selectedSide == 'defense',
                    onSelected: (_) => setState(() => _selectedSide = 'defense'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '包点',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final site in ['A', 'B', 'C'])
                    ChoiceChip(
                      label: Text('$site点'),
                      selected: _selectedSite == site,
                      onSelected: (_) => setState(() => _selectedSite = site),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    final theme = Theme.of(context);
    final showImageError = _submitted && _selectedImages.isEmpty;

    return _buildSectionCard(
      context: context,
      title: '图片信息',
      subtitle: '至少添加 1 张图片，建议按实际操作顺序上传。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '已添加 ${_selectedImages.length} 张',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '桌面端仅支持从本地选择图片。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildImageGrid(showImageError),
          if (showImageError) ...[
            const SizedBox(height: 8),
            Text(
              '请至少添加一张图片',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('从相册选择'),
              ),
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('拍照'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(bool showError) {
    final theme = Theme.of(context);

    if (_selectedImages.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: showError
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 36,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                '尚未添加图片',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '建议上传展示站位、准星位置和落点结果的图片。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    _selectedImages[index],
                    width: 180,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '第 ${index + 1} 张',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black.withOpacity(0.55),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => _removeImage(index),
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 18,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
