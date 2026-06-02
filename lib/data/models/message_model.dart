class Message {
  final String id;
  final String title;
  final String shortDescription;
  final String content;
  final DateTime date;
  final String? imageUrl;

  Message({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.content,
    required this.date,
    this.imageUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('body') && json.containsKey('createdAt')) {
      final body = json['body'] as String;
      final id = json['id'].toString();
      final date = DateTime.parse(json['createdAt'] as String);

      // Infer title based on content
      String title = 'Announcement';
      final bodyUpper = body.toUpperCase();
      if (bodyUpper.contains('TAFSEER')) {
        title = 'Tafseer ul Quran Sessions';
      } else if (bodyUpper.contains('WHATSAPP') || bodyUpper.contains('SMS')) {
        title = 'Masjid WhatsApp Group Signup';
      } else if (bodyUpper.contains('JUMMA') || bodyUpper.contains('IQAMA')) {
        title = 'Jumma Salaat Iqama Notice';
      } else {
        // Fallback: Use the first few words or first sentence
        final firstSentence = body.split(RegExp(r'[.\n]')).first.trim();
        if (firstSentence.isNotEmpty) {
          title = firstSentence.length > 40
              ? '${firstSentence.substring(0, 37)}...'
              : firstSentence;
        }
      }

      return Message(
        id: id,
        title: title,
        shortDescription: body,
        content: body,
        date: date,
        imageUrl: null,
      );
    }

    return Message(
      id: json['id'].toString(),
      title: json['title'] as String,
      shortDescription: json['shortDescription'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'shortDescription': shortDescription,
      'content': content,
      'date': date.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }
}
