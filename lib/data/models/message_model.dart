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
    return Message(
      id: json['id'] as String,
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
