import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/journal_model.dart';
import '../providers/journal_provider.dart';

class JournalFormScreen extends ConsumerStatefulWidget {
  const JournalFormScreen({super.key});

  @override
  ConsumerState<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends ConsumerState<JournalFormScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedMood = '😌';
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um título')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva sua reflexão')),
      );
      return;
    }

    final entry = JournalEntry(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      mood: _selectedMood,
      tags: _selectedTags.toList(),
    );

    await ref.read(journalListProvider.notifier).add(entry);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nova reflexão'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salvar',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Humor
            Text('Como você se sente?', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: moodOptions.map((mood) {
                final active = _selectedMood == mood['emoji'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = mood['emoji']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent.withValues(alpha: 0.15) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? AppColors.accent : theme.colorScheme.outline,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood['emoji']!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(
                          mood['label']!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: active ? AppColors.accent : theme.colorScheme.onSurface,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            // Título
            TextField(
              controller: _titleController,
              autofocus: true,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: 'Título da reflexão',
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Conteúdo
            TextField(
              controller: _contentController,
              maxLines: 8,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'O que aconteceu hoje com suas finanças? Como se sentiu ao gastar ou economizar? O que aprendeu?',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 28),
            // Tags
            Text('Tags (opcional)', style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tagOptions.map((tag) {
                final active = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (active) {
                        _selectedTags.remove(tag);
                      } else {
                        _selectedTags.add(tag);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.accent.withValues(alpha: 0.15) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.accent : theme.colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: active ? AppColors.accent : theme.colorScheme.onSurface,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}