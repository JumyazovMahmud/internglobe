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
      id: json['id'],
      title: json['title'],
      organization: json['organization'],
      url: json['url'],
      remote: json['remote_derived'] ?? false,
      cities: (json['cities_derived'] as List?)?.cast<String>(),
      countries: (json['countries_derived'] as List?)?.cast<String>(),
      locationsDerived: (json['locations_derived'] as List?)?.cast<String>(),
      organizationLogo: json['organization_logo'],
      datePosted: json['date_posted'] != null ? DateTime.parse(json['date_posted']) : null,
      latsDerived: (json['lats_derived'] as List?)?.cast<double>(),
      lngsDerived: (json['lngs_derived'] as List?)?.cast<double>(),
    );
  }

  // Add this toJson method for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organization': organization,
      'url': url,
      'remote_derived': remote,
      'cities_derived': cities,
      'countries_derived': countries,
      'locations_derived': locationsDerived,
      'organization_logo': organizationLogo,
      'date_posted': datePosted?.toIso8601String(),
      'lats_derived': latsDerived,
      'lngs_derived': lngsDerived,
    };
  }
}