import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_colors.dart';

/// One leadership card: circular photo, name and title chip. `director`
/// comes from the live platform (GET /api/public/directors) or, if that
/// call fails, the same real fallback names/photos the production website
/// itself falls back to.
class DirectorCard extends StatelessWidget {
  const DirectorCard({super.key, required this.director});

  final RemoteDirector director;

  Widget _initialsAvatar() {
    final initials = director.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = director.imageUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: director.imageUrl.isEmpty
                  ? _initialsAvatar()
                  : isNetworkImage
                  ? Image.network(
                      director.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _initialsAvatar(),
                    )
                  : Image.asset(
                      director.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _initialsAvatar(),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            director.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              director.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
