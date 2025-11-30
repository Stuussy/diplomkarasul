import 'user.dart';

class RoleProfileSummary {
  RoleProfileSummary({
    required this.user,
    required this.metrics,
    required this.infoCards,
    required this.timeline,
    this.highlight,
  });

  final AppUser user;
  final List<ProfileMetric> metrics;
  final ProfileHighlight? highlight;
  final List<ProfileInfoCard> infoCards;
  final List<ProfileTimelineEntry> timeline;

  factory RoleProfileSummary.fromJson(Map<String, dynamic> json) {
    final metrics = (json['metrics'] as List<dynamic>?)
            ?.map((item) => ProfileMetric.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <ProfileMetric>[];
    final infoCards = (json['infoCards'] as List<dynamic>?)
            ?.map((item) => ProfileInfoCard.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <ProfileInfoCard>[];
    final timeline = (json['timeline'] as List<dynamic>?)
            ?.map((item) => ProfileTimelineEntry.fromJson(item as Map<String, dynamic>))
            .toList() ??
        const <ProfileTimelineEntry>[];

    return RoleProfileSummary(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      metrics: metrics,
      infoCards: infoCards,
      timeline: timeline,
      highlight: json['highlight'] != null
          ? ProfileHighlight.fromJson(json['highlight'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProfileMetric {
  ProfileMetric({
    required this.label,
    required this.value,
    this.caption,
    this.trend,
  });

  final String label;
  final String value;
  final String? caption;
  final String? trend;

  factory ProfileMetric.fromJson(Map<String, dynamic> json) => ProfileMetric(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '0',
        caption: json['caption']?.toString(),
        trend: json['trend']?.toString(),
      );
}

class ProfileHighlight {
  ProfileHighlight({
    required this.title,
    this.subtitle,
    this.meta,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final String? meta;
  final String? badge;

  factory ProfileHighlight.fromJson(Map<String, dynamic> json) => ProfileHighlight(
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        meta: json['meta']?.toString(),
        badge: json['badge']?.toString(),
      );
}

class ProfileInfoCard {
  ProfileInfoCard({required this.title, required this.rows});

  final String title;
  final List<ProfileInfoRow> rows;

  factory ProfileInfoCard.fromJson(Map<String, dynamic> json) => ProfileInfoCard(
        title: json['title']?.toString() ?? '',
        rows: (json['rows'] as List<dynamic>?)
                ?.map((item) => ProfileInfoRow.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const <ProfileInfoRow>[],
      );
}

class ProfileInfoRow {
  ProfileInfoRow({required this.label, required this.value, this.meta});

  final String label;
  final String value;
  final String? meta;

  factory ProfileInfoRow.fromJson(Map<String, dynamic> json) => ProfileInfoRow(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        meta: json['meta']?.toString(),
      );
}

class ProfileTimelineEntry {
  ProfileTimelineEntry({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.status,
  });

  final String title;
  final String? subtitle;
  final String? timestamp;
  final String? status;

  factory ProfileTimelineEntry.fromJson(Map<String, dynamic> json) => ProfileTimelineEntry(
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        timestamp: json['timestamp']?.toString(),
        status: json['status']?.toString(),
      );
}
