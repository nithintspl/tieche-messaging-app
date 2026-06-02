import '../../core/constants/app_constants.dart';

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
    String imageUrl = '';
    if (json.containsKey('path')) {
      final path = json['path'] as String;
      imageUrl = path.startsWith('/')
          ? '${AppConstants.baseApiUrl}$path'
          : '${AppConstants.baseApiUrl}/$path';
    } else {
      imageUrl = json['imageUrl'] as String? ?? '';
    }

    return CarouselItem(
      id: json['id']?.toString() ?? '',
      imageUrl: imageUrl,
      title: json['title'] as String? ?? '',
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
