import 'dart:io';
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
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择特工')),
      );
      return;
    }
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一张图片')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('添加点位 - ${widget.mapName}'),
      ),
      body: Consumer<LineupProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Agent selection
                DropdownButtonFormField<String>(
                  value: _selectedAgentId,
                  decoration: const InputDecoration(
                    labelText: '选择特工',
                    border: OutlineInputBorder(),
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

                // Side selection
                Row(
                  children: [
                    const Text('阵营：', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('进攻'),
                      selected: _selectedSide == 'attack',
                      onSelected: (_) =>
                          setState(() => _selectedSide = 'attack'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('防守'),
                      selected: _selectedSide == 'defense',
                      onSelected: (_) =>
                          setState(() => _selectedSide = 'defense'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Site selection
                Row(
                  children: [
                    const Text('包点：', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 16),
                    for (final site in ['A', 'B', 'C']) ...[
                      ChoiceChip(
                        label: Text('$site点'),
                        selected: _selectedSite == site,
                        onSelected: (_) =>
                            setState(() => _selectedSite = site),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '例如：A包烟雾弹点位',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? '请输入标题' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '说明',
                    hintText: '描述该点位的使用方法和注意事项',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Image picker
                const Text('图片', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                _buildImageGrid(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('相册'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('保存', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_selectedImages.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('尚未添加图片', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
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
