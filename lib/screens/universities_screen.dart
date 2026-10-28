import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_colors.dart';
import 'university_detail_screen.dart';

/// Screen displaying all partner and SkillDad-affiliated universities.
/// Supports search filtering, location filtering, and full university details
/// modal with real accreditations, programs, and direct contact options.
class UniversitiesScreen extends StatefulWidget {
  const UniversitiesScreen({super.key});

  @override
  State<UniversitiesScreen> createState() => _UniversitiesScreenState();
}

class _UniversitiesScreenState extends State<UniversitiesScreen> {
  List<RemoteUniversity>? _allUniversities;
  List<RemoteUniversity> _filteredUniversities = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _filters = [
    'All',
    'Accredited',
    'Europe',
    'India',
    'Malaysia',
    'Malta',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ContentService.instance.fetchUniversities();
    if (!mounted) return;
    setState(() {
      _allUniversities = list;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_allUniversities == null) return;
    final query = _searchQuery.toLowerCase().trim();

    _filteredUniversities = _allUniversities!.where((uni) {
      // Search matching
      final matchesSearch = query.isEmpty ||
          uni.name.toLowerCase().contains(query) ||
          uni.location.toLowerCase().contains(query) ||
          uni.description.toLowerCase().contains(query) ||
          uni.courseCategories.any((c) => c.toLowerCase().contains(query)) ||
          uni.courseTitles.any((t) => t.toLowerCase().contains(query));

      if (!matchesSearch) return false;

      // Category / Region matching
      switch (_selectedFilter) {
        case 'Accredited':
          return uni.achievements.isNotEmpty;
        case 'Europe':
          final loc = uni.location.toLowerCase();
          return loc.contains('albania') ||
              loc.contains('bosnia') ||
              loc.contains('greece') ||
              loc.contains('montenegro') ||
              loc.contains('malta') ||
              loc.contains('europe');
        case 'India':
          final loc = uni.location.toLowerCase();
          return loc.contains('india') ||
              loc.contains('karnataka') ||
              loc.contains('bengaluru') ||
              loc.contains('jaipur') ||
              loc.contains('tamil nadu') ||
              loc.contains('uttar pradesh');
        case 'Malaysia':
          return uni.location.toLowerCase().contains('malaysia') ||
              uni.location.toLowerCase().contains('johor') ||
              uni.location.toLowerCase().contains('kuala lumpur');
        case 'Malta':
          return uni.location.toLowerCase().contains('malta');
        case 'All':
        default:
          return true;
      }
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFilter();
    });
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _showUniversityDetails(BuildContext context, RemoteUniversity uni) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UniversityDetailScreen(uni: uni),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _allUniversities;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Partner Universities',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          list != null
                              ? '${list.length} Accredited Institutions Worldwide'
                              : 'Leading Global Academic Partners',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.fieldBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search universities, locations, courses...',
                    hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // Region & Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => _onFilterSelected(filter),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.fieldBorder,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // University List
            Expanded(
              child: list == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredUniversities.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school_outlined, size: 48, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                const Text(
                                  'No universities found matching your search.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try adjusting your search terms or filter selection.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    _onFilterSelected('All');
                                  },
                                  child: const Text('Reset Filters'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                            itemCount: _filteredUniversities.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final uni = _filteredUniversities[index];
                              return _UniversityCard(
                                uni: uni,
                                onTap: () => _showUniversityDetails(context, uni),
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

/// A card displaying university branding, campus photography, structured
/// meta information (accreditation, courses, programs), and direct action,
/// fully redesigned to mirror the desktop university cards.
class _UniversityCard extends StatelessWidget {
  const _UniversityCard({required this.uni, required this.onTap});

  final RemoteUniversity uni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3EDFF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFDDD6FE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Campus Cover Image Banner with overlay & badges (matching desktop card)
              _CampusCoverImage(uni: uni, height: 145),

              // 2. Card Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: University Logo + Name + Location
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _UniversityLogoAvatar(uni: uni, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uni.name,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      uni.location,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (uni.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        uni.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Scholars & Modules Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatChip(
                            icon: Icons.people_outline_rounded,
                            label: 'Scholars',
                            value: uni.studentCount,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStatChip(
                            icon: Icons.menu_book_outlined,
                            label: 'Modules',
                            value: uni.courseCount,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // View Details Button (SkillDad Brand CTA)
                    Container(
                      height: 42,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            Color(0xFF6D28D9),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ],
                      ),
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

/// Campus cover image banner with gradient overlay and floating badges,
/// identical to the desktop card banner.
class _CampusCoverImage extends StatelessWidget {
  const _CampusCoverImage({
    required this.uni,
    this.height = 145,
  });

  final RemoteUniversity uni;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            uni.effectiveCoverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          // Subtle gradient overlay for contrast
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          // Top Left: Partner Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Partner University',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top Right: Rating Chip
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(
                    uni.rating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact pill showing scholars/modules stats.
class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDD6FE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$value $label',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversityLogoAvatar extends StatelessWidget {
  const _UniversityLogoAvatar({required this.uni, required this.size});

  final RemoteUniversity uni;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasLogo = uni.logoUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              uni.logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _FallbackInitial(initials: uni.initials),
            )
          : _FallbackInitial(initials: uni.initials),
    );
  }
}

class _FallbackInitial extends StatelessWidget {
  const _FallbackInitial({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

