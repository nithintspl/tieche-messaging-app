class CarouselItem {
  final String id;
  final String imageUrl;
  final String title;

  CarouselItem({
    required this.id,
    required this.imageUrl,
    required this.title,
  });

  factory CarouselItem.fromJson(Map<String, dynamic> json) {
    return CarouselItem(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'title': title,
    };
  }
}
