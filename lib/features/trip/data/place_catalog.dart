import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:xplore/features/trip/models/trip_stop.dart';

/// A destination the create-trip flow can add. Hardcoded stand-in for a places
/// API: [dayThemes] seed the stub plan and the two gradient colours stand in for
/// a photo.
class CatalogPlace {
  const CatalogPlace({
    required this.id,
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.dayThemes,
    required this.gradientStart,
    required this.gradientEnd,
  });

  /// Stable id, also stored as [TripStop.id].
  final String id;
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  /// Short day titles for the stub plan, e.g. "Asakusa and the old town".
  final List<String> dayThemes;
  final Color gradientStart;
  final Color gradientEnd;

  /// This place as a trip stop with [nights].
  TripStop toStop({int nights = 1}) =>
      TripStop(id: id, name: name, country: country, latitude: latitude, longitude: longitude, nights: nights);
}

/// Searches and suggests [CatalogPlace]s. Use the shared [placeCatalog]; tests
/// may build one over their own places.
class PlaceCatalog {
  const PlaceCatalog({this.places = _places, this.popularIds = _popularIds});

  final List<CatalogPlace> places;

  /// Ids shown, in order, when the search query is empty.
  final List<String> popularIds;

  /// The place with [id], or null when the catalog has none.
  CatalogPlace? byId(String id) {
    for (final place in places) {
      if (place.id == id) {
        return place;
      }
    }
    return null;
  }

  /// Places matching [query], case- and accent-insensitively: name prefix
  /// matches first, then names containing it, then places whose country
  /// contains it; catalog order within each group. An empty query returns the
  /// popular list. Ids in [exclude] (e.g. stops already added) are left out.
  List<CatalogPlace> search(String query, {Iterable<String> exclude = const []}) {
    final excluded = exclude.toSet();
    bool allowed(CatalogPlace place) => !excluded.contains(place.id);

    final needle = foldForSearch(query.trim());
    if (needle.isEmpty) {
      return popularIds.map(byId).whereType<CatalogPlace>().where(allowed).toList();
    }

    final prefix = <CatalogPlace>[];
    final contains = <CatalogPlace>[];
    final country = <CatalogPlace>[];
    for (final place in places.where(allowed)) {
      final name = foldForSearch(place.name);
      if (name.startsWith(needle)) {
        prefix.add(place);
      } else if (name.contains(needle)) {
        contains.add(place);
      } else if (foldForSearch(place.country).contains(needle)) {
        country.add(place);
      }
    }
    return [...prefix, ...contains, ...country];
  }

  /// "Often added" places for a trip with [stops]: other places in the same
  /// countries, nearest to the last stop first, excluding ones already added.
  /// Empty when there are no stops.
  List<CatalogPlace> suggestionsFor(List<TripStop> stops, {int limit = 3}) {
    if (stops.isEmpty || limit <= 0) {
      return const [];
    }
    final countries = stops.map((stop) => stop.country).toSet();
    final added = stops.map((stop) => stop.id).toSet();
    final last = stops.last;
    double distanceFromLast(CatalogPlace place) =>
        _distanceKm(last.latitude, last.longitude, place.latitude, place.longitude);

    final candidates = places.where((place) => countries.contains(place.country) && !added.contains(place.id)).toList()
      ..sort((a, b) => distanceFromLast(a).compareTo(distanceFromLast(b)));
    return candidates.take(limit).toList();
  }
}

/// The app's hardcoded destination catalog.
const placeCatalog = PlaceCatalog();

/// Lower-cases [value] and strips common Latin diacritics so "reykjavik"
/// matches "Reykjavík".
String foldForSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedChars[char] ?? char);
  }
  return buffer.toString();
}

const _foldedChars = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
  'æ': 'ae', 'ç': 'c', 'ð': 'd', 'ß': 'ss', 'þ': 'th', 'œ': 'oe', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', //
  'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ý': 'y', 'ÿ': 'y',
};

/// Great-circle distance; accurate enough to rank nearby places.
double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(lat1)) * math.cos(radians(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(a));
}

const _popularIds = [
  'tokyo',
  'lisbon',
  'paris',
  'bali',
  'new-york',
  'rome',
  'barcelona',
  'kyoto',
  'reykjavik',
  'mexico-city',
  'bangkok',
  'london',
];

const _places = <CatalogPlace>[
  // Japan
  CatalogPlace(
    id: 'tokyo',
    name: 'Tokyo',
    country: 'Japan',
    latitude: 35.6762,
    longitude: 139.6503,
    dayThemes: ['Asakusa and the old town', 'Shibuya and Harajuku', 'Tsukiji and Ginza', 'Shinjuku by night'],
    gradientStart: Color(0xFFE94B6A),
    gradientEnd: Color(0xFF3A1C71),
  ),
  CatalogPlace(
    id: 'hakone',
    name: 'Hakone',
    country: 'Japan',
    latitude: 35.2324,
    longitude: 139.1069,
    dayThemes: ['Lake Ashi and the torii', 'Owakudani and the ropeway', 'Onsen and open-air art'],
    gradientStart: Color(0xFF4CA1AF),
    gradientEnd: Color(0xFF2C3E50),
  ),
  CatalogPlace(
    id: 'kyoto',
    name: 'Kyoto',
    country: 'Japan',
    latitude: 35.0116,
    longitude: 135.7681,
    dayThemes: [
      'Fushimi Inari at dawn',
      'Gion and Higashiyama',
      'Arashiyama bamboo grove',
      'Golden Pavilion and Zen gardens',
    ],
    gradientStart: Color(0xFFD3494E),
    gradientEnd: Color(0xFF6B2D5C),
  ),
  CatalogPlace(
    id: 'osaka',
    name: 'Osaka',
    country: 'Japan',
    latitude: 34.6937,
    longitude: 135.5023,
    dayThemes: ['Dotonbori street food', 'Osaka Castle and park', 'Shinsekai and Tsutenkaku'],
    gradientStart: Color(0xFFFF7E5F),
    gradientEnd: Color(0xFF86168C),
  ),
  CatalogPlace(
    id: 'nara',
    name: 'Nara',
    country: 'Japan',
    latitude: 34.6851,
    longitude: 135.8048,
    dayThemes: ['Todai-ji and the deer park', 'Kasuga Taisha lanterns', 'Naramachi old merchant quarter'],
    gradientStart: Color(0xFFA8C66C),
    gradientEnd: Color(0xFF1E5631),
  ),
  CatalogPlace(
    id: 'hiroshima',
    name: 'Hiroshima',
    country: 'Japan',
    latitude: 34.3853,
    longitude: 132.4553,
    dayThemes: ['Peace Memorial Park', 'Miyajima and the floating torii', 'Okonomiyaki and Hondori'],
    gradientStart: Color(0xFF56CCF2),
    gradientEnd: Color(0xFF2F80ED),
  ),
  CatalogPlace(
    id: 'kanazawa',
    name: 'Kanazawa',
    country: 'Japan',
    latitude: 36.5613,
    longitude: 136.6562,
    dayThemes: ['Kenroku-en garden', 'Higashi Chaya geisha district', 'Omicho market and the castle'],
    gradientStart: Color(0xFFF2C94C),
    gradientEnd: Color(0xFF9B6B12),
  ),
  CatalogPlace(
    id: 'kamakura',
    name: 'Kamakura',
    country: 'Japan',
    latitude: 35.3192,
    longitude: 139.5467,
    dayThemes: ['The Great Buddha', 'Temple hike to Hase-dera', 'Enoshima island and the coast'],
    gradientStart: Color(0xFF6FB1FC),
    gradientEnd: Color(0xFF0052D4),
  ),
  CatalogPlace(
    id: 'nikko',
    name: 'Nikko',
    country: 'Japan',
    latitude: 36.7199,
    longitude: 139.6982,
    dayThemes: ['Toshogu shrine', 'Lake Chuzenji and Kegon Falls', 'Kanmangafuchi abyss walk'],
    gradientStart: Color(0xFF38EF7D),
    gradientEnd: Color(0xFF11998E),
  ),
  CatalogPlace(
    id: 'sapporo',
    name: 'Sapporo',
    country: 'Japan',
    latitude: 43.0618,
    longitude: 141.3545,
    dayThemes: ['Odori Park and the TV tower', 'Ramen alley and Susukino', 'Day trip to Otaru'],
    gradientStart: Color(0xFFE0EAFC),
    gradientEnd: Color(0xFF5B7DB1),
  ),

  // Portugal
  CatalogPlace(
    id: 'lisbon',
    name: 'Lisbon',
    country: 'Portugal',
    latitude: 38.7223,
    longitude: -9.1393,
    dayThemes: [
      'Alfama and the castle',
      'Belém and pastéis de nata',
      'Bairro Alto sunset',
      'LX Factory and the riverside',
    ],
    gradientStart: Color(0xFFF7B733),
    gradientEnd: Color(0xFFFC4A1A),
  ),
  CatalogPlace(
    id: 'porto',
    name: 'Porto',
    country: 'Portugal',
    latitude: 41.1579,
    longitude: -8.6291,
    dayThemes: ['Ribeira and the Dom Luís bridge', 'Port cellars in Gaia', 'Livraria Lello and Clérigos'],
    gradientStart: Color(0xFF3A7BD5),
    gradientEnd: Color(0xFF00467F),
  ),
  CatalogPlace(
    id: 'sintra',
    name: 'Sintra',
    country: 'Portugal',
    latitude: 38.8029,
    longitude: -9.3817,
    dayThemes: ['Pena Palace', 'Quinta da Regaleira', 'Cabo da Roca coast'],
    gradientStart: Color(0xFFFFD86F),
    gradientEnd: Color(0xFFC33764),
  ),
  CatalogPlace(
    id: 'lagos',
    name: 'Lagos',
    country: 'Portugal',
    latitude: 37.1028,
    longitude: -8.6730,
    dayThemes: ['Ponta da Piedade by kayak', 'Beach hopping on the Algarve', 'Old town and the marina'],
    gradientStart: Color(0xFF43C6AC),
    gradientEnd: Color(0xFF191654),
  ),
  CatalogPlace(
    id: 'funchal',
    name: 'Funchal',
    country: 'Portugal',
    latitude: 32.6669,
    longitude: -16.9241,
    dayThemes: ['Mercado dos Lavradores', 'Monte toboggan ride', 'Levada walk in the hills'],
    gradientStart: Color(0xFF56AB2F),
    gradientEnd: Color(0xFF1D4E89),
  ),

  // Spain
  CatalogPlace(
    id: 'barcelona',
    name: 'Barcelona',
    country: 'Spain',
    latitude: 41.3874,
    longitude: 2.1686,
    dayThemes: [
      'Sagrada Família and Eixample',
      'Gothic Quarter and El Born',
      'Park Güell and Gràcia',
      'Barceloneta beach',
    ],
    gradientStart: Color(0xFFFF9966),
    gradientEnd: Color(0xFFFF5E62),
  ),
  CatalogPlace(
    id: 'madrid',
    name: 'Madrid',
    country: 'Spain',
    latitude: 40.4168,
    longitude: -3.7038,
    dayThemes: ['The Prado and Retiro Park', 'Royal Palace and La Latina tapas', 'Malasaña and Gran Vía'],
    gradientStart: Color(0xFFDA4453),
    gradientEnd: Color(0xFF89216B),
  ),
  CatalogPlace(
    id: 'seville',
    name: 'Seville',
    country: 'Spain',
    latitude: 37.3891,
    longitude: -5.9845,
    dayThemes: ['Real Alcázar and the cathedral', 'Plaza de España', 'Triana and flamenco'],
    gradientStart: Color(0xFFF09819),
    gradientEnd: Color(0xFFEDDE5D),
  ),
  CatalogPlace(
    id: 'granada',
    name: 'Granada',
    country: 'Spain',
    latitude: 37.1773,
    longitude: -3.5986,
    dayThemes: ['The Alhambra', 'Albaicín and Mirador de San Nicolás', 'Tapas crawl in the centre'],
    gradientStart: Color(0xFFE65C00),
    gradientEnd: Color(0xFFF9D423),
  ),
  CatalogPlace(
    id: 'valencia',
    name: 'Valencia',
    country: 'Spain',
    latitude: 39.4699,
    longitude: -0.3763,
    dayThemes: ['City of Arts and Sciences', 'Old town and the Central Market', 'Paella by the beach'],
    gradientStart: Color(0xFF00C9FF),
    gradientEnd: Color(0xFF92FE9D),
  ),
  CatalogPlace(
    id: 'san-sebastian',
    name: 'San Sebastián',
    country: 'Spain',
    latitude: 43.3183,
    longitude: -1.9812,
    dayThemes: ['La Concha beach', 'Pintxos in the old town', 'Monte Igueldo views'],
    gradientStart: Color(0xFF2193B0),
    gradientEnd: Color(0xFF6DD5ED),
  ),
  CatalogPlace(
    id: 'palma',
    name: 'Palma de Mallorca',
    country: 'Spain',
    latitude: 39.5696,
    longitude: 2.6502,
    dayThemes: ['La Seu cathedral and the old town', 'Coves and calas', 'Serra de Tramuntana drive'],
    gradientStart: Color(0xFF1FA2FF),
    gradientEnd: Color(0xFFA6FFCB),
  ),

  // Italy
  CatalogPlace(
    id: 'rome',
    name: 'Rome',
    country: 'Italy',
    latitude: 41.9028,
    longitude: 12.4964,
    dayThemes: [
      'Colosseum and the Forum',
      'Vatican Museums and St Peter’s',
      'Trastevere evening',
      'Pantheon and Piazza Navona',
    ],
    gradientStart: Color(0xFFCB356B),
    gradientEnd: Color(0xFFBD3F32),
  ),
  CatalogPlace(
    id: 'florence',
    name: 'Florence',
    country: 'Italy',
    latitude: 43.7696,
    longitude: 11.2558,
    dayThemes: ['The Duomo and Uffizi', 'Oltrarno and Piazzale Michelangelo', 'Chianti day trip'],
    gradientStart: Color(0xFFDE6262),
    gradientEnd: Color(0xFFFFB88C),
  ),
  CatalogPlace(
    id: 'venice',
    name: 'Venice',
    country: 'Italy',
    latitude: 45.4408,
    longitude: 12.3155,
    dayThemes: ['St Mark’s and the Doge’s Palace', 'Cannaregio and cicchetti', 'Murano and Burano'],
    gradientStart: Color(0xFF4568DC),
    gradientEnd: Color(0xFFB06AB3),
  ),
  CatalogPlace(
    id: 'milan',
    name: 'Milan',
    country: 'Italy',
    latitude: 45.4642,
    longitude: 9.1900,
    dayThemes: ['The Duomo rooftop', 'The Last Supper and Brera', 'Navigli aperitivo'],
    gradientStart: Color(0xFF757F9A),
    gradientEnd: Color(0xFFD7DDE8),
  ),
  CatalogPlace(
    id: 'amalfi',
    name: 'Amalfi',
    country: 'Italy',
    latitude: 40.6340,
    longitude: 14.6027,
    dayThemes: ['Positano by boat', 'Path of the Gods hike', 'Ravello gardens'],
    gradientStart: Color(0xFF00B4DB),
    gradientEnd: Color(0xFFF8B500),
  ),
  CatalogPlace(
    id: 'cinque-terre',
    name: 'Cinque Terre',
    country: 'Italy',
    latitude: 44.1350,
    longitude: 9.6847,
    dayThemes: ['Vernazza and Monterosso', 'Coastal trail to Corniglia', 'Manarola at sunset'],
    gradientStart: Color(0xFFFF6E7F),
    gradientEnd: Color(0xFF3B8D99),
  ),
  CatalogPlace(
    id: 'naples',
    name: 'Naples',
    country: 'Italy',
    latitude: 40.8518,
    longitude: 14.2681,
    dayThemes: ['Pizza in the historic centre', 'Pompeii day trip', 'Spaccanapoli and the underground'],
    gradientStart: Color(0xFFF46B45),
    gradientEnd: Color(0xFFEEA849),
  ),

  // France
  CatalogPlace(
    id: 'paris',
    name: 'Paris',
    country: 'France',
    latitude: 48.8566,
    longitude: 2.3522,
    dayThemes: ['The Louvre and the Tuileries', 'Montmartre and Sacré-Cœur', 'Le Marais', 'Eiffel Tower and the Seine'],
    gradientStart: Color(0xFFEECDA3),
    gradientEnd: Color(0xFFEF629F),
  ),
  CatalogPlace(
    id: 'nice',
    name: 'Nice',
    country: 'France',
    latitude: 43.7102,
    longitude: 7.2620,
    dayThemes: ['Promenade des Anglais', 'Vieux Nice and Cours Saleya', 'Èze and Monaco'],
    gradientStart: Color(0xFF00D2FF),
    gradientEnd: Color(0xFF3A7BD5),
  ),
  CatalogPlace(
    id: 'lyon',
    name: 'Lyon',
    country: 'France',
    latitude: 45.7640,
    longitude: 4.8357,
    dayThemes: ['Vieux Lyon traboules', 'Fourvière hill', 'Bouchons and Les Halles'],
    gradientStart: Color(0xFFB24592),
    gradientEnd: Color(0xFFF15F79),
  ),
  CatalogPlace(
    id: 'bordeaux',
    name: 'Bordeaux',
    country: 'France',
    latitude: 44.8378,
    longitude: -0.5792,
    dayThemes: ['Place de la Bourse and the water mirror', 'Saint-Émilion vineyards', 'La Cité du Vin'],
    gradientStart: Color(0xFF8E0E00),
    gradientEnd: Color(0xFF1F1C18),
  ),
  CatalogPlace(
    id: 'marseille',
    name: 'Marseille',
    country: 'France',
    latitude: 43.2965,
    longitude: 5.3698,
    dayThemes: ['Vieux-Port and Le Panier', 'Calanques boat trip', 'Notre-Dame de la Garde'],
    gradientStart: Color(0xFF36D1DC),
    gradientEnd: Color(0xFF5B86E5),
  ),

  // United Kingdom
  CatalogPlace(
    id: 'london',
    name: 'London',
    country: 'UK',
    latitude: 51.5072,
    longitude: -0.1276,
    dayThemes: [
      'Westminster and the South Bank',
      'British Museum and Covent Garden',
      'Shoreditch and Brick Lane',
      'Notting Hill and Hyde Park',
    ],
    gradientStart: Color(0xFF606C88),
    gradientEnd: Color(0xFF3F4C6B),
  ),
  CatalogPlace(
    id: 'edinburgh',
    name: 'Edinburgh',
    country: 'UK',
    latitude: 55.9533,
    longitude: -3.1883,
    dayThemes: ['The castle and the Royal Mile', 'Arthur’s Seat hike', 'Dean Village and Stockbridge'],
    gradientStart: Color(0xFF536976),
    gradientEnd: Color(0xFF292E49),
  ),
  CatalogPlace(
    id: 'bath',
    name: 'Bath',
    country: 'UK',
    latitude: 51.3811,
    longitude: -2.3590,
    dayThemes: ['Roman Baths and the abbey', 'Royal Crescent', 'Thermae spa evening'],
    gradientStart: Color(0xFFD9A7C7),
    gradientEnd: Color(0xFFFFFCDC),
  ),
  CatalogPlace(
    id: 'isle-of-skye',
    name: 'Isle of Skye',
    country: 'UK',
    latitude: 57.4125,
    longitude: -6.1960,
    dayThemes: ['Old Man of Storr', 'Fairy Pools', 'Quiraing loop'],
    gradientStart: Color(0xFF134E5E),
    gradientEnd: Color(0xFF71B280),
  ),

  // Iceland
  CatalogPlace(
    id: 'reykjavik',
    name: 'Reykjavík',
    country: 'Iceland',
    latitude: 64.1466,
    longitude: -21.9426,
    dayThemes: ['Hallgrímskirkja and the harbour', 'Golden Circle', 'Blue Lagoon soak'],
    gradientStart: Color(0xFF2BC0E4),
    gradientEnd: Color(0xFF3A6073),
  ),
  CatalogPlace(
    id: 'vik',
    name: 'Vík',
    country: 'Iceland',
    latitude: 63.4186,
    longitude: -19.0060,
    dayThemes: ['Reynisfjara black sand beach', 'Skógafoss and Seljalandsfoss', 'Glacier walk on Sólheimajökull'],
    gradientStart: Color(0xFF232526),
    gradientEnd: Color(0xFF414345),
  ),
  CatalogPlace(
    id: 'akureyri',
    name: 'Akureyri',
    country: 'Iceland',
    latitude: 65.6835,
    longitude: -18.0878,
    dayThemes: ['Lake Mývatn', 'Whale watching in Húsavík', 'Goðafoss waterfall'],
    gradientStart: Color(0xFF00C6FF),
    gradientEnd: Color(0xFF0072FF),
  ),

  // Greece
  CatalogPlace(
    id: 'athens',
    name: 'Athens',
    country: 'Greece',
    latitude: 37.9838,
    longitude: 23.7275,
    dayThemes: ['The Acropolis and Plaka', 'Ancient Agora and Monastiraki', 'Cape Sounion sunset'],
    gradientStart: Color(0xFFF3904F),
    gradientEnd: Color(0xFF3B4371),
  ),
  CatalogPlace(
    id: 'santorini',
    name: 'Santorini',
    country: 'Greece',
    latitude: 36.3932,
    longitude: 25.4615,
    dayThemes: ['Oia and the caldera', 'Fira to Imerovigli walk', 'Red Beach and Akrotiri'],
    gradientStart: Color(0xFF2980B9),
    gradientEnd: Color(0xFFFFFFFF),
  ),
  CatalogPlace(
    id: 'mykonos',
    name: 'Mykonos',
    country: 'Greece',
    latitude: 37.4467,
    longitude: 25.3289,
    dayThemes: ['Little Venice and the windmills', 'Beach day', 'Delos island'],
    gradientStart: Color(0xFF4AC29A),
    gradientEnd: Color(0xFFBDFFF3),
  ),
  CatalogPlace(
    id: 'chania',
    name: 'Chania',
    country: 'Greece',
    latitude: 35.5138,
    longitude: 24.0180,
    dayThemes: ['Venetian harbour', 'Samaria Gorge hike', 'Balos lagoon'],
    gradientStart: Color(0xFF02AAB0),
    gradientEnd: Color(0xFF00CDAC),
  ),

  // Thailand
  CatalogPlace(
    id: 'bangkok',
    name: 'Bangkok',
    country: 'Thailand',
    latitude: 13.7563,
    longitude: 100.5018,
    dayThemes: ['Grand Palace and Wat Pho', 'Chinatown street food', 'Chatuchak market', 'Canals of Thonburi'],
    gradientStart: Color(0xFFFDC830),
    gradientEnd: Color(0xFFF37335),
  ),
  CatalogPlace(
    id: 'chiang-mai',
    name: 'Chiang Mai',
    country: 'Thailand',
    latitude: 18.7883,
    longitude: 98.9853,
    dayThemes: ['Old city temples', 'Doi Suthep', 'Night bazaar and khao soi'],
    gradientStart: Color(0xFF5A3F37),
    gradientEnd: Color(0xFF2C7744),
  ),
  CatalogPlace(
    id: 'phuket',
    name: 'Phuket',
    country: 'Thailand',
    latitude: 7.8804,
    longitude: 98.3923,
    dayThemes: ['Old Phuket Town', 'Phi Phi islands', 'Big Buddha and Kata beach'],
    gradientStart: Color(0xFF11998E),
    gradientEnd: Color(0xFF38EF7D),
  ),
  CatalogPlace(
    id: 'krabi',
    name: 'Krabi',
    country: 'Thailand',
    latitude: 8.0863,
    longitude: 98.9063,
    dayThemes: ['Railay beach', 'Four islands by longtail', 'Tiger Cave Temple'],
    gradientStart: Color(0xFF00B09B),
    gradientEnd: Color(0xFF96C93D),
  ),

  // Indonesia
  CatalogPlace(
    id: 'bali',
    name: 'Bali',
    country: 'Indonesia',
    latitude: -8.4095,
    longitude: 115.1889,
    dayThemes: ['Ubud rice terraces', 'Uluwatu temple at sunset', 'Seminyak beach', 'Mount Batur sunrise'],
    gradientStart: Color(0xFF7F7FD5),
    gradientEnd: Color(0xFF91EAE4),
  ),
  CatalogPlace(
    id: 'jakarta',
    name: 'Jakarta',
    country: 'Indonesia',
    latitude: -6.2088,
    longitude: 106.8456,
    dayThemes: ['Kota Tua old town', 'National Monument and museums', 'Thousand Islands day trip'],
    gradientStart: Color(0xFFEB5757),
    gradientEnd: Color(0xFF000000),
  ),
  CatalogPlace(
    id: 'yogyakarta',
    name: 'Yogyakarta',
    country: 'Indonesia',
    latitude: -7.7956,
    longitude: 110.3695,
    dayThemes: ['Borobudur at sunrise', 'Prambanan temples', 'Kraton and Malioboro street'],
    gradientStart: Color(0xFFC79081),
    gradientEnd: Color(0xFFDFA579),
  ),
  CatalogPlace(
    id: 'lombok',
    name: 'Lombok',
    country: 'Indonesia',
    latitude: -8.6500,
    longitude: 116.3249,
    dayThemes: ['Gili islands snorkelling', 'Kuta Lombok beaches', 'Sendang Gile waterfalls'],
    gradientStart: Color(0xFF1CB5E0),
    gradientEnd: Color(0xFF000851),
  ),

  // USA
  CatalogPlace(
    id: 'new-york',
    name: 'New York',
    country: 'USA',
    latitude: 40.7128,
    longitude: -74.0060,
    dayThemes: ['Central Park and the Met', 'Lower Manhattan and the ferry', 'Brooklyn and DUMBO', 'Midtown lights'],
    gradientStart: Color(0xFFFFB75E),
    gradientEnd: Color(0xFFED8F03),
  ),
  CatalogPlace(
    id: 'san-francisco',
    name: 'San Francisco',
    country: 'USA',
    latitude: 37.7749,
    longitude: -122.4194,
    dayThemes: ['Golden Gate and the Presidio', 'Alcatraz and the waterfront', 'Mission murals and tacos'],
    gradientStart: Color(0xFFF83600),
    gradientEnd: Color(0xFFF9D423),
  ),
  CatalogPlace(
    id: 'los-angeles',
    name: 'Los Angeles',
    country: 'USA',
    latitude: 34.0522,
    longitude: -118.2437,
    dayThemes: ['Griffith Observatory and Hollywood', 'Santa Monica and Venice Beach', 'Downtown and the Getty'],
    gradientStart: Color(0xFFFF5F6D),
    gradientEnd: Color(0xFFFFC371),
  ),
  CatalogPlace(
    id: 'las-vegas',
    name: 'Las Vegas',
    country: 'USA',
    latitude: 36.1699,
    longitude: -115.1398,
    dayThemes: ['The Strip', 'Red Rock Canyon', 'Fremont Street'],
    gradientStart: Color(0xFFDA22FF),
    gradientEnd: Color(0xFF9733EE),
  ),
  CatalogPlace(
    id: 'grand-canyon',
    name: 'Grand Canyon',
    country: 'USA',
    latitude: 36.1069,
    longitude: -112.1129,
    dayThemes: ['South Rim viewpoints', 'Bright Angel Trail', 'Desert View Drive at sunset'],
    gradientStart: Color(0xFFE96443),
    gradientEnd: Color(0xFF904E95),
  ),
  CatalogPlace(
    id: 'chicago',
    name: 'Chicago',
    country: 'USA',
    latitude: 41.8781,
    longitude: -87.6298,
    dayThemes: ['Architecture river cruise', 'Millennium Park and the Art Institute', 'Deep dish and jazz'],
    gradientStart: Color(0xFF4B79A1),
    gradientEnd: Color(0xFF283E51),
  ),
  CatalogPlace(
    id: 'new-orleans',
    name: 'New Orleans',
    country: 'USA',
    latitude: 29.9511,
    longitude: -90.0715,
    dayThemes: ['French Quarter', 'Garden District streetcar', 'Frenchmen Street jazz'],
    gradientStart: Color(0xFF8E2DE2),
    gradientEnd: Color(0xFF4A00E0),
  ),
  CatalogPlace(
    id: 'honolulu',
    name: 'Honolulu',
    country: 'USA',
    latitude: 21.3069,
    longitude: -157.8583,
    dayThemes: ['Waikiki beach', 'Diamond Head hike', 'Pearl Harbor', 'North Shore drive'],
    gradientStart: Color(0xFF00F260),
    gradientEnd: Color(0xFF0575E6),
  ),

  // Mexico
  CatalogPlace(
    id: 'mexico-city',
    name: 'Mexico City',
    country: 'Mexico',
    latitude: 19.4326,
    longitude: -99.1332,
    dayThemes: [
      'Zócalo and the historic centre',
      'Coyoacán and Frida Kahlo',
      'Teotihuacán pyramids',
      'Roma and Condesa tacos',
    ],
    gradientStart: Color(0xFFFF416C),
    gradientEnd: Color(0xFFFF4B2B),
  ),
  CatalogPlace(
    id: 'oaxaca',
    name: 'Oaxaca',
    country: 'Mexico',
    latitude: 17.0732,
    longitude: -96.7266,
    dayThemes: ['Santo Domingo and the markets', 'Monte Albán', 'Mezcal and Hierve el Agua'],
    gradientStart: Color(0xFFF7971E),
    gradientEnd: Color(0xFFFFD200),
  ),
  CatalogPlace(
    id: 'tulum',
    name: 'Tulum',
    country: 'Mexico',
    latitude: 20.2114,
    longitude: -87.4654,
    dayThemes: ['Ruins on the cliff', 'Cenote swimming', 'Sian Ka’an biosphere'],
    gradientStart: Color(0xFF0ABFBC),
    gradientEnd: Color(0xFFFC354C),
  ),
  CatalogPlace(
    id: 'cancun',
    name: 'Cancún',
    country: 'Mexico',
    latitude: 21.1619,
    longitude: -86.8515,
    dayThemes: ['Hotel Zone beaches', 'Isla Mujeres', 'Chichén Itzá day trip'],
    gradientStart: Color(0xFF00D2FF),
    gradientEnd: Color(0xFF928DAB),
  ),
  CatalogPlace(
    id: 'guadalajara',
    name: 'Guadalajara',
    country: 'Mexico',
    latitude: 20.6597,
    longitude: -103.3496,
    dayThemes: ['Historic centre and Hospicio Cabañas', 'Tlaquepaque crafts', 'Tequila town day trip'],
    gradientStart: Color(0xFF6A3093),
    gradientEnd: Color(0xFFA044FF),
  ),
];
