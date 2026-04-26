import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/profile_summary.dart';
import '../models/user.dart';
import '../theme/clinic_theme.dart';
import 'dent_badge.dart';
import 'dent_card.dart';

class RoleProfileOverview extends StatelessWidget {
  const RoleProfileOverview({super.key, required this.summary});

  final RoleProfileSummary summary;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _ProfileHero(user: summary.user),
    ];

    if (summary.metrics.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 16),
        _MetricsGrid(metrics: summary.metrics),
      ]);
    }

    if (summary.highlight != null) {
      sections.addAll([
        const SizedBox(height: 16),
        _HighlightCard(highlight: summary.highlight!),
      ]);
    }

    if (summary.infoCards.isNotEmpty) {
      for (final card in summary.infoCards) {
        sections.addAll([
          const SizedBox(height: 16),
          _InfoCard(card: card),
        ]);
      }
    }

    if (summary.timeline.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 16),
        _TimelineCard(entries: summary.timeline),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);
    final theme = Theme.of(context);
    final roleLabel = _roleLabel(user.role);
    final chips = <String>[];
    if (user.specialties.isNotEmpty) {
      chips.addAll(user.specialties.take(3));
    } else if (user.clinics.isNotEmpty) {
      chips.addAll(user.clinics.take(2));
    }

    return DentCard(
      gradient: ClinicTheme.heroGradient,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: chips
                        .map(
                          (chip) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              chip,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(AppUser user) {
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final combined = '$first$last'.trim();
    return combined.isNotEmpty ? combined.toUpperCase() : '·';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'doctor':
        return 'Врач';
      case 'admin':
        return 'Администратор';
      case 'director':
        return 'Директор';
      default:
        return role;
    }
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<ProfileMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final ProfileMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(metric.label, style: theme.textTheme.bodySmall),
          if (metric.caption != null) ...[
            const SizedBox(height: 2),
            Text(
              metric.caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ClinicTheme.slate,
                fontSize: 11,
              ),
            ),
          ],
          if (metric.trend != null) ...[
            const SizedBox(height: 2),
            Text(
              metric.trend!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ClinicTheme.mint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.highlight});

  final ProfileHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DentCard(
      color: ClinicTheme.azureSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight.badge != null)
            DentBadge(label: highlight.badge!, variant: DentBadgeVariant.info),
          const SizedBox(height: 8),
          Text(
            highlight.title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (highlight.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(highlight.subtitle!, style: theme.textTheme.bodyMedium),
          ],
          if (highlight.meta != null) ...[
            const SizedBox(height: 4),
            Text(
              highlight.meta!,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.card});

  final ProfileInfoCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...card.rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ClinicTheme.slate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(row.value, style: theme.textTheme.bodyMedium),
                  if (row.meta != null)
                    Text(
                      row.meta!,
                      style: theme.textTheme.bodySmall,
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entries});

  final List<ProfileTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Недавние события',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClinicTheme.azureSoft,
                  borderRadius: BorderRadius.circular(ClinicTheme.radiusS),
                ),
                child: const Icon(
                  LucideIcons.activity,
                  color: ClinicTheme.azure,
                  size: 20,
                ),
              ),
              title: Text(entry.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.subtitle != null) Text(entry.subtitle!),
                  if (entry.timestamp != null)
                    Text(
                      entry.timestamp!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              trailing: entry.status != null
                  ? DentBadge(label: _statusLabel(entry.status!))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Запланировано';
      case 'confirmed':
        return 'Подтверждено';
      case 'completed':
        return 'Завершено';
      case 'cancelled':
        return 'Отменено';
      case 'in_progress':
        return 'В работе';
      case 'resolved':
        return 'Закрыто';
      case 'new_hire':
        return 'Новый сотрудник';
      default:
        return status;
    }
  }
}
