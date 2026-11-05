class Game {
  final int id;
  final String title, description, genre, version, cover, banner, company;
  final double price;
  final List<String> platforms;
  final Map<String, dynamic> metadata;
  final bool owned;
  const Game(
      {required this.id,
      required this.title,
      this.description = '',
      this.genre = '',
      this.version = '',
      this.cover = '',
      this.banner = '',
      this.company = '',
      this.price = 0,
      this.platforms = const [],
      this.metadata = const {},
      this.owned = false});
  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: int.parse('${j['id']}'),
        title: '${j['title'] ?? j['game'] ?? ''}',
        description: '${j['description'] ?? j['opica'] ?? ''}',
        genre: '${j['genre'] ?? ''}',
        version: '${j['version'] ?? ''}',
        cover: '${j['img'] ?? ''}',
        banner: '${j['imggame'] ?? j['img'] ?? ''}',
        company: '${j['company'] ?? ''}',
        price: _price(j['price']),
        platforms: (j['platforms'] as List? ??
                (j['metadata'] is Map
                    ? j['metadata']['platforms'] as List?
                    : null) ??
                [])
            .map((x) => '$x')
            .toList(),
        metadata: Map<String, dynamic>.from(j['metadata'] as Map? ?? {}),
        owned:
            j['typeuser'] == true || j['typeUser'] == 1 || j['owned'] == true,
      );
  static double _price(dynamic value) {
    final parsed = double.tryParse('$value');
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : -1;
  }

  bool get released => (metadata['release_status'] ?? 'released') == 'released';
  String get priceLabel => !released
      ? 'В разработке'
      : price < 0
          ? 'Цена пока не указана'
          : price == 0
              ? 'Бесплатно'
              : '${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)} ₽';
}

class PixelProfile {
  final String id, login, username;
  final Map<String, String> fields, account;
  final Map<String, dynamic> overrides;
  const PixelProfile(
      {required this.id,
      required this.login,
      required this.username,
      required this.fields,
      required this.account,
      required this.overrides});
  factory PixelProfile.fromJson(Map<String, dynamic> j) => PixelProfile(
        id: '${j['global_id']}',
        login: '${j['login'] ?? ''}',
        username: '${j['username'] ?? ''}',
        fields: {for (final k in presentationFields) k: '${j[k] ?? ''}'},
        account: {
          for (final k in presentationFields)
            k: '${(j['account'] as Map? ?? {})[k] ?? ''}'
        },
        overrides: Map<String, dynamic>.from(j['overrides'] as Map? ?? {}),
      );
  static const presentationFields = ['display_name', 'avatar', 'banner', 'bio'];
  String get name =>
      fields['display_name']!.isEmpty ? 'Игрок' : fields['display_name']!;
  bool get customized => overrides.isNotEmpty;
}
