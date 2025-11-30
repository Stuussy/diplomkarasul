import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import '../models/user.dart';

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
        const SizedBox(height: 12),
        _MetricsGrid(metrics: summary.metrics),
      ]);
    }

    if (summary.highlight != null) {
      sections.addAll([
        const SizedBox(height: 12),
        _HighlightCard(highlight: summary.highlight!),
      ]);
    }

    if (summary.infoCards.isNotEmpty) {
      for (final card in summary.infoCards) {
        sections.addAll([
          const SizedBox(height: 12),
          _InfoCard(card: card),
        ]);
      }
    }

    if (summary.timeline.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 12),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Text(
                initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: chips
                        .map((chip) => Chip(
                              label: Text(chip),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        childAspectRatio: 3,
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
    final surface = theme.colorScheme.surfaceContainerHighest;
    return Card(
      color: surface.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              metric.label,
              style: theme.textTheme.labelLarge,
            ),
            if (metric.caption != null) ...[
              const SizedBox(height: 4),
              Text(
                metric.caption!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
            if (metric.trend != null) ...[
              const SizedBox(height: 4),
              Text(
                metric.trend!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.green[700]),
              ),
            ],
          ],
        ),
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
    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (highlight.badge != null)
              Chip(
                label: Text(highlight.badge!),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(height: 8),
            Text(
              highlight.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (highlight.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(highlight.subtitle!, style: theme.textTheme.bodyMedium),
            ],
            if (highlight.meta != null) ...[
              const SizedBox(height: 4),
              Text(
                highlight.meta!,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...card.rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label, style: theme.textTheme.labelLarge),
                    Text(row.value, style: theme.textTheme.bodyMedium),
                    if (row.meta != null)
                      Text(
                        row.meta!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Недавние события',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timeline),
                title: Text(entry.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.subtitle != null) Text(entry.subtitle!),
                    if (entry.timestamp != null)
                      Text(
                        entry.timestamp!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: entry.status != null
                    ? Chip(label: Text(_statusLabel(entry.status!)))
                    : null,
              ),
            ),
          ],
        ),
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
