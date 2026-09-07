class SchoolCatalogItem {
  final String name;
  final String defaultScale; // 'scale_5' | 'scale_4' | 'percentage'
  final bool isAccurate;

  const SchoolCatalogItem({
    required this.name,
    required this.defaultScale,
    this.isAccurate = true,
  });
}

const List<SchoolCatalogItem> philippineSchools = [
  // --- National University (NU) System ---
  SchoolCatalogItem(name: 'National University Manila', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Baliwag', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Clark', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University MOA', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Laguna', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Lipa', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Fairview', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Dasmariñas', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'National University Nazareth School', defaultScale: 'scale_4'),

  // --- University of the Philippines (UP) System ---
  SchoolCatalogItem(name: 'University of the Philippines Diliman', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Manila', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Los Baños', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Visayas', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Mindanao', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Open University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Baguio', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the Philippines Cebu', defaultScale: 'scale_5'),

  // --- De La Salle University (DLSU) System ---
  SchoolCatalogItem(name: 'De La Salle University Manila', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'De La Salle University Dasmariñas', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'De La Salle Santiago Zobel School', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'De La Salle Araneta University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'De La Salle - College of Saint Benilde', defaultScale: 'scale_4'),

  // --- Ateneo System ---
  SchoolCatalogItem(name: 'Ateneo de Manila University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Ateneo de Davao University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Ateneo de Zamboanga University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Ateneo de Naga University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Xavier University - Ateneo de Cagayan', defaultScale: 'scale_4'),

  // --- Far Eastern University (FEU) System ---
  SchoolCatalogItem(name: 'Far Eastern University Manila', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Far Eastern University Alabang', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Far Eastern University Diliman', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'FEU Institute of Technology (FEU Tech)', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'FEU Cavite', defaultScale: 'scale_4'),

  // --- Polytechnic University of the Philippines (PUP) ---
  SchoolCatalogItem(name: 'Polytechnic University of the Philippines Manila', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Polytechnic University of the Philippines Taguig', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Polytechnic University of the Philippines Quezon City', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Polytechnic University of the Philippines Santa Maria', defaultScale: 'scale_5'),

  // --- Other Major Philippine HEIs ---
  SchoolCatalogItem(name: 'University of Santo Tomas', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Mapua University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of the East', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Adamson University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Technological University of the Philippines', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Technological Institute of the Philippines', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Centro Escolar University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'San Beda University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Batangas State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Bulacan State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Cavite State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Pamantasan ng Lungsod ng Maynila', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Mindanao State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Bicol University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Cebu Technological University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'West Visayas State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Central Luzon State University', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of Southeastern Philippines', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'Silliman University', defaultScale: 'scale_4'),
  SchoolCatalogItem(name: 'Saint Louis University Baguio', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of San Carlos', defaultScale: 'scale_5'),
  SchoolCatalogItem(name: 'University of San Jose - Recoletos', defaultScale: 'scale_5'),
];
