import 'package:flutter/material.dart';

import '../services/study_abroad_service.dart';
import '../theme/app_colors.dart';
import 'study_abroad_courses_screen.dart';

/// Real partner universities within a Study Abroad country
/// (GET /api/study-abroad/countries/:id/universities).
class StudyAbroadUniversitiesScreen extends StatefulWidget {
  const StudyAbroadUniversitiesScreen({super.key, required this.country});

  final StudyAbroadCountry country;

  @override
  State<StudyAbroadUniversitiesScreen> createState() => _StudyAbroadUniversitiesScreenState();
}

class _StudyAbroadUniversitiesScreenState extends State<StudyAbroadUniversitiesScreen> {
  List<StudyAbroadUniversity>? _universities;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final universities = await StudyAbroadService.instance.fetchUniversities(widget.country.id);
    if (!mounted) return;
    setState(() => _universities = universities);
  }

  @override
  Widget build(BuildContext context) {
    final universities = _universities;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.fieldBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.country.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: universities == null
                  ? const Center(child: CircularProgressIndicator())
                  : universities.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No partner universities published for this country yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        itemCount: universities.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final uni = universities[index];
                          return _UniversityCard(
                            university: uni,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StudyAbroadCoursesScreen(university: uni),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UniversityCard extends StatelessWidget {
  const _UniversityCard({required this.university, required this.onTap});

  final StudyAbroadUniversity university;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 52,
                child: university.logoUrl.isEmpty
                    ? Container(
                        color: AppColors.fieldBackground,
                        alignment: Alignment.center,
                        child: const Icon(Icons.school_rounded, color: AppColors.primary),
                      )
                    : Image.network(
                        university.logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.fieldBackground,
                          alignment: Alignment.center,
                          child: const Icon(Icons.school_rounded, color: AppColors.primary),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    university.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  if (university.location.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            university.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
