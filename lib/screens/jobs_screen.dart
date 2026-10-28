import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../services/jobs_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/auto_hide_bottom_nav_scaffold.dart';

/// Real job/internship vacancies and applications - replaces the previous
/// "Jobs is coming soon" snackbar with the actual career portal data
/// (GET /api/career/vacancies, GET /api/career/my-applications).
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.token, this.courses = const []});

  final String token;
  final List<EnrolledCourse> courses;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Vacancy>? _vacancies;
  Set<String> _appliedIds = {};
  String? _applyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      JobsService.instance.fetchVacancies(),
      JobsService.instance.fetchAppliedVacancyIds(widget.token),
    ]);
    if (!mounted) return;
    setState(() {
      _vacancies = results[0] as List<Vacancy>;
      _appliedIds = results[1] as Set<String>;
    });
  }

  Future<void> _apply(Vacancy vacancy) async {
    setState(() => _applyingId = vacancy.id);
    try {
      await JobsService.instance.applyToVacancy(vacancy.id, widget.token);
      if (!mounted) return;
      setState(() => _appliedIds = {..._appliedIds, vacancy.id});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted')),
      );
    } on JobsApplyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit your application. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vacancies = _vacancies;
    final openVacancies = vacancies?.where((v) => v.isOpen && !v.isExpired).toList();

    return AutoHideBottomNavScaffold(
      backgroundColor: AppColors.background,
      bottomNav: AppBottomNav(courses: widget.courses, token: widget.token, currentLabel: 'Jobs'),
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
                    'Job Alerts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: vacancies == null
                  ? const Center(child: CircularProgressIndicator())
                  : openVacancies!.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No open job or internship postings right now. Check back soon.',
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                        itemCount: openVacancies.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final vacancy = openVacancies[index];
                          return _VacancyCard(
                            vacancy: vacancy,
                            applied: _appliedIds.contains(vacancy.id),
                            applying: _applyingId == vacancy.id,
                            onApply: () => _apply(vacancy),
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

class _VacancyCard extends StatelessWidget {
  const _VacancyCard({
    required this.vacancy,
    required this.applied,
    required this.applying,
    required this.onApply,
  });

  final Vacancy vacancy;
  final bool applied;
  final bool applying;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  vacancy.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vacancy.jobType,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ),
          if (vacancy.company.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              vacancy.company,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
          if (vacancy.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              vacancy.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (vacancy.location.isNotEmpty) _InfoChip(icon: Icons.location_on_outlined, label: vacancy.location),
              if (vacancy.salaryRange.isNotEmpty)
                _InfoChip(icon: Icons.payments_outlined, label: vacancy.salaryRange),
              if (vacancy.deadline != null)
                _InfoChip(
                  icon: Icons.event_outlined,
                  label: 'Apply by ${vacancy.deadline!.day}/${vacancy.deadline!.month}/${vacancy.deadline!.year}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: applied || applying ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: applied ? AppColors.fieldBorder : AppColors.primary,
                foregroundColor: applied ? AppColors.textMuted : Colors.white,
                disabledBackgroundColor: applied ? AppColors.fieldBorder : AppColors.primary.withValues(alpha: 0.6),
                disabledForegroundColor: applied ? AppColors.textMuted : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(applied ? 'Applied' : 'Apply Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ],
    );
  }
}
