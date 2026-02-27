class Internship {
  final String id;
  final String title;
  final String organization;
  final String url;
  final bool remote;
  final List<String>? cities;
  final List<String>? countries;
  final List<String>? locationsDerived;
  final String? organizationLogo;
  final DateTime? datePosted;
  final List<double>? latsDerived;
  final List<double>? lngsDerived;

  Internship({
    required this.id,
    required this.title,
    required this.organization,
    required this.url,
    required this.remote,
    this.cities,
    this.countries,
    this.locationsDerived,
    this.organizationLogo,
    this.datePosted,
    this.latsDerived,
    this.lngsDerived,
  });

  factory Internship.fromJson(Map<String, dynamic> json) {
    return Internship(
      id: json['id'] as String,
      title: json['title'] as String,
      organization: json['organization'] as String,
      url: json['url'] as String,
      remote: json['remote_derived'] as bool? ?? false,
      cities: (json['cities_derived'] as List?)?.map((e) => e.toString()).toList(),
      countries: (json['countries_derived'] as List?)?.map((e) => e.toString()).toList(),
      locationsDerived: (json['locations_derived'] as List?)?.map((e) => e.toString()).toList(),
      organizationLogo: json['organization_logo'] as String?,
      datePosted: json['date_posted'] != null ? DateTime.parse(json['date_posted'] as String) : null,
      // RTDB stores numbers as num, so cast carefully
      latsDerived: (json['lats_derived'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      lngsDerived: (json['lngs_derived'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }

  /// Null-safe toJson — RTDB will reject or corrupt writes that contain null
  /// values, so we only include keys that actually have a value.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organization': organization,
      'url': url,
      'remote_derived': remote,
      if (cities != null) 'cities_derived': cities,
      if (countries != null) 'countries_derived': countries,
      if (locationsDerived != null) 'locations_derived': locationsDerived,
      if (organizationLogo != null) 'organization_logo': organizationLogo,
      if (datePosted != null) 'date_posted': datePosted!.toIso8601String(),
      // Convert to List<num> — RTDB does not support List<double> directly
      if (latsDerived != null) 'lats_derived': latsDerived!.map((e) => e).toList(),
      if (lngsDerived != null) 'lngs_derived': lngsDerived!.map((e) => e).toList(),
    };
  }
}