import 'package:uuid/uuid.dart';

class JournalEntry {
  final String id;
  final String title;
  final String content;
  final String mood;
  final List<String> tags;
  final DateTime entryDate;
  final DateTime createdAt;

  JournalEntry({
    String? id,
    required this.title,
    required this.content,
    required this.mood,
    this.tags = const [],
    DateTime? entryDate,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        entryDate = entryDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'mood': mood,
        'tags': tags,
        'entryDate': entryDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      mood: json['mood'],
      tags: List<String>.from(json['tags'] ?? []),
      entryDate: DateTime.parse(json['entryDate']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

const moodOptions = [
  {'emoji': '😌', 'label': 'Sereno'},
  {'emoji': '😊', 'label': 'Feliz'},
  {'emoji': '🤔', 'label': 'Pensativo'},
  {'emoji': '😰', 'label': 'Ansioso'},
  {'emoji': '😤', 'label': 'Frustrado'},
  {'emoji': '🥳', 'label': 'Orgulhoso'},
  {'emoji': '😔', 'label': 'Preocupado'},
  {'emoji': '🤑', 'label': 'Próspero'},
];

const tagOptions = [
  'Economizei',
  'Gastei demais',
  'Recebi',
  'Investi',
  'Meta batida',
  'Imprevisto',
  'Decisão difícil',
  'Progresso',
];