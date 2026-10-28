import 'package:flutter/material.dart';

import '../services/study_abroad_service.dart';
import '../theme/app_colors.dart';
import 'study_abroad_universities_screen.dart';

/// Real Study Abroad countries (GET /api/study-abroad/countries) - the
/// first step of the real drill-down the web app uses
/// (client/src/pages/StudyAbroad.jsx): Country -> University -> Course.
class StudyAbroadScreen extends StatefulWidget {
  const StudyAbroadScreen({super.key});

  @override
  State<StudyAbroadScreen> createState() => _StudyAbroadScreenState();
}

class _StudyAbroadScreenState extends State<StudyAbroadScreen> {
  List<StudyAbroadCountry>? _countries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final countries = await StudyAbroadService.instance.fetchCountries();
    if (!mounted) return;
    setState(() => _countries = countries);
  }

  @override
  Widget build(BuildContext context) {
    final countries = _countries;

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
                  const Text(
                    'Study Abroad',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Choose a country to see partner universities and their programmes.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
            Expanded(
              child: countries == null
                  ? const Center(child: CircularProgressIndicator())
                  : countries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No Study Abroad destinations are published yet.',
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
                        itemCount: countries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final country = countries[index];
                          return _CountryCard(
                            country: country,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StudyAbroadUniversitiesScreen(country: country),
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

class _CountryCard extends StatelessWidget {
  const _CountryCard({required this.country, required this.onTap});

  final StudyAbroadCountry country;
  final VoidCallback onTap;

  Widget _buildImage() {
    final effectiveUrl = country.effectiveImageUrl;
    final fallbackUrl = country.fallbackImageUrl;

    Widget placeholder() => Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 40),
    );

    return Image.network(
      effectiveUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return placeholder();
      },
      errorBuilder: (context, error, stackTrace) {
        if (effectiveUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder(),
          );
        }
        return placeholder();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFECE7FA), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4C1D95).withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Thumbnail with top rounding and floating overlays
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: _buildImage(),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.38, 1.0],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_rounded, size: 11.5, color: Color(0xFFFBBF24)),
                            SizedBox(width: 4),
                            Text(
                              'Partner Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Country Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (country.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        country.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.school_outlined,
                          label: 'Global Degrees',
                          color: Color(0xFF2563EB),
                          bgColor: Color(0xFFEFF6FF),
                        ),
                        _MetaChip(
                          icon: Icons.work_outline_rounded,
                          label: 'Work Rights',
                          color: Color(0xFF0D9488),
                          bgColor: Color(0xFFF0FDFA),
                        ),
                        _MetaChip(
                          icon: Icons.verified_outlined,
                          label: 'Visa Guidance',
                          color: Color(0xFF6D28D9),
                          bgColor: Color(0xFFF5F3FF),
                        ),
                      ],
                    ),
                    Container(
                      height: 1,
                      color: const Color(0xFFF1F5F9),
                      margin: const EdgeInsets.only(top: 14, bottom: 12),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.public_rounded, size: 16, color: AppColors.primaryLight),
                            SizedBox(width: 5),
                            Text(
                              'International Admission',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explore',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 13.5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
