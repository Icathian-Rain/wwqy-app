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
  final String? mapName;
  final Lineup? initialLineup;

  const AddLineupScreen({
    super.key,
    required this.gameId,
    required this.mapId,
    this.mapName,
    this.initialLineup,
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
  final List<_EditableImageItem> _imageItems = [];
  final Set<String> _removedExistingImagePaths = {};
  final Set<String> _pendingNewImagePaths = {};
  List<String> _initialImagePaths = [];
  bool _loadingExistingImages = false;
  bool _saving = false;
  bool _submitted = false;
  bool _saved = false;
  int _previewImageIndex = 0;

  bool get _isEditMode => widget.initialLineup != null;

  @override
  void initState() {
    super.initState();
    final initialLineup = widget.initialLineup;
    if (initialLineup != null) {
      _titleController.text = initialLineup.title;
      _descriptionController.text = initialLineup.description;
      _selectedAgentId = initialLineup.agentId;
      _selectedSide = initialLineup.side;
      _selectedSite = initialLineup.site;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LineupProvider>().loadAgents(widget.gameId);
      if (_isEditMode) {
        await _loadExistingImages();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    if (!_saved) {
      for (final imagePath in _pendingNewImagePaths) {
        try {
          final file = File(imagePath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
    }
    super.dispose();
  }

  Future<void> _loadExistingImages() async {
    setState(() => _loadingExistingImages = true);
    try {
      final images = await context.read<LineupProvider>().getLineupImages(widget.initialLineup!.id);
      if (!mounted) return;
      setState(() {
        _imageItems
          ..clear()
          ..addAll(images.map((image) => _EditableImageItem.existing(
                imageId: image.id,
                imagePath: image.imagePath,
              )));
        _initialImagePaths = images.map((image) => image.imagePath).toList();
        _previewImageIndex = 0;
        _loadingExistingImages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExistingImages = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载点位图片失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImageHelper.pickImage(source: source);
    if (file == null) return;
    setState(() {
      _imageItems.add(_EditableImageItem.newFile(file));
      _pendingNewImagePaths.add(file.path);
      _previewImageIndex = _imageItems.length - 1;
    });
  }

  Future<void> _removeImage(int index) async {
    final item = _imageItems[index];
    setState(() {
      _imageItems.removeAt(index);
      if (item.isExisting) {
        _removedExistingImagePaths.add(item.file.path);
      } else {
        _pendingNewImagePaths.remove(item.file.path);
      }
      if (_previewImageIndex >= _imageItems.length) {
        _previewImageIndex = _imageItems.isEmpty ? 0 : _imageItems.length - 1;
      }
    });

    if (!item.isExisting) {
      await ImageHelper.deleteImage(item.file.path);
    }
  }

  void _setPreviewImage(int index) {
    setState(() => _previewImageIndex = index);
  }

  void _moveImageLeft(int index) {
    if (index == 0) return;
    setState(() {
      final item = _imageItems.removeAt(index);
      _imageItems.insert(index - 1, item);
      _previewImageIndex = index - 1;
    });
  }

  void _moveImageRight(int index) {
    if (index >= _imageItems.length - 1) return;
    setState(() {
      final item = _imageItems.removeAt(index);
      _imageItems.insert(index + 1, item);
      _previewImageIndex = index + 1;
    });
  }

  bool _hasUnsavedChanges() {
    if (!_isEditMode) {
      return _titleController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _selectedAgentId != null ||
          _imageItems.isNotEmpty;
    }

    final initialLineup = widget.initialLineup!;
    final currentImagePaths = _imageItems.map((item) => item.file.path).toList();
    return _titleController.text != initialLineup.title ||
        _descriptionController.text != initialLineup.description ||
        _selectedAgentId != initialLineup.agentId ||
        _selectedSide != initialLineup.side ||
        _selectedSite != initialLineup.site ||
        !_samePathOrder(currentImagePaths, _initialImagePaths);
  }

  bool _samePathOrder(List<String> current, List<String> initial) {
    if (current.length != initial.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != initial[i]) return false;
    }
    return true;
  }

  Future<void> _save() async {
    setState(() => _submitted = true);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgentId == null || _imageItems.isEmpty) {
      return;
    }

    setState(() => _saving = true);

    try {
      final initialLineup = widget.initialLineup;
      final lineupId = initialLineup?.id ?? _uuid.v4();
      final lineup = Lineup(
        id: lineupId,
        gameId: widget.gameId,
        mapId: widget.mapId,
        agentId: _selectedAgentId!,
        side: _selectedSide,
        site: _selectedSite,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: initialLineup?.createdAt ?? DateTime.now(),
      );

      final images = <LineupImage>[];
      for (var i = 0; i < _imageItems.length; i++) {
        final item = _imageItems[i];
        images.add(
          LineupImage(
            id: item.imageId ?? _uuid.v4(),
            lineupId: lineupId,
            imagePath: item.file.path,
            sortOrder: i,
          ),
        );
      }

      final provider = context.read<LineupProvider>();
      if (_isEditMode) {
        await provider.updateLineup(
          lineup,
          images,
          _removedExistingImagePaths.toList(),
        );
      } else {
        await provider.addLineup(lineup, images);
      }

      if (mounted) {
        _saved = true;
        _pendingNewImagePaths.clear();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addTitle = widget.mapName == null || widget.mapName!.isEmpty ? '添加点位' : '添加点位 · ${widget.mapName}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasUnsavedChanges()) {
          Navigator.pop(context);
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃编辑？'),
            content: const Text('当前填写的内容将不会保存。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续编辑')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('放弃')),
            ],
          ),
        );
        if (confirmed == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? '编辑点位' : addTitle),
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
                  autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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
                                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditMode ? '修改当前战术点位' : '录入新的战术点位',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isEditMode
                                      ? '可修改基础信息并增删图片，支持调整图片顺序，第一张图会作为封面图。'
                                      : '请先填写基础信息，再补充图片和使用说明。图片会复制到应用本地目录中保存。',
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
                              onPressed: _saving || _loadingExistingImages ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_isEditMode ? '保存修改' : '保存点位'),
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
              if (_submitted && _selectedAgentId == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '请选择特工',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
              ..._buildAgentRoleGroups(context, provider),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题 *',
                  hintText: '例如：A包烟雾弹点位',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? '请输入标题' : null,
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

  List<Widget> _buildAgentRoleGroups(BuildContext context, LineupProvider provider) {
    final grouped = <String, List<dynamic>>{};
    for (final agent in provider.agents) {
      grouped.putIfAbsent(agent.role, () => []).add(agent);
    }

    return grouped.entries
        .map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.value
                    .map<Widget>(
                      (agent) => ChoiceChip(
                        label: Text(agent.name),
                        selected: _selectedAgentId == agent.id,
                        onSelected: (_) => setState(() => _selectedAgentId = agent.id),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
        .toList();
  }

  Widget _buildImageSection(BuildContext context) {
    final theme = Theme.of(context);
    final showImageError = _submitted && _imageItems.isEmpty;

    return _buildSectionCard(
      context: context,
      title: '图片信息',
      subtitle: _isEditMode ? '可保留旧图、删除旧图，也可继续追加新图片，并可调整顺序。' : '至少添加 1 张图片，建议按实际操作顺序上传。',
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
                  '已添加 ${_imageItems.length} 张',
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
          if (_loadingExistingImages)
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
              child: const CircularProgressIndicator(),
            )
          else
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
                onPressed: _loadingExistingImages ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('从相册选择'),
              ),
              if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                ElevatedButton.icon(
                  onPressed: _loadingExistingImages ? null : () => _pickImage(ImageSource.camera),
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

    if (_imageItems.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          border: Border.all(
            color: showError ? theme.colorScheme.error : theme.colorScheme.outlineVariant.withOpacity(0.5),
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

    final previewItem = _imageItems[_previewImageIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    previewItem.file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _previewImageIndex == 0 ? '封面图 / 第 1 张' : '第 ${_previewImageIndex + 1} 张',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: _previewImageIndex > 0 ? () => _moveImageLeft(_previewImageIndex) : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _previewImageIndex < _imageItems.length - 1
                            ? () => _moveImageRight(_previewImageIndex)
                            : null,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '点击缩略图切换预览，可用左右按钮调整顺序。第一张图会作为列表封面。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imageItems.length,
            itemBuilder: (context, index) {
              final item = _imageItems[index];
              final selected = index == _previewImageIndex;
              return GestureDetector(
                onTap: () => _setPreviewImage(index),
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            item.file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '封面',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withOpacity(0.55),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: () => _removeImage(index),
                            icon: const Icon(Icons.close, color: Colors.white),
                            iconSize: 18,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditableImageItem {
  final String? imageId;
  final File file;
  final bool isExisting;

  const _EditableImageItem({
    required this.imageId,
    required this.file,
    required this.isExisting,
  });

  factory _EditableImageItem.existing({
    required String imageId,
    required String imagePath,
  }) {
    return _EditableImageItem(
      imageId: imageId,
      file: File(imagePath),
      isExisting: true,
    );
  }

  factory _EditableImageItem.newFile(File file) {
    return _EditableImageItem(
      imageId: null,
      file: file,
      isExisting: false,
    );
  }
}
