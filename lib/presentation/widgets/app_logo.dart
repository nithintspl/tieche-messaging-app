import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.circular = false,
    this.borderRadius,
  });

  final double size;
  final bool circular;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      AppConstants.appIconAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );

    if (circular) {
      return ClipOval(child: image);
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
