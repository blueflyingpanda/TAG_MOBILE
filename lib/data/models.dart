// Mirrors TAG/src/types.ts. JSON keys match the API (snake_case).

class User {
  const User({
    required this.id,
    required this.email,
    required this.username,
    this.picture,
    required this.admin,
  });

  final String id;
  final String? email;
  final String username;
  final String? picture;
  final bool admin;
}

class Creator {
  const Creator({this.email, this.username, this.picture, this.admin = false});

  final String? email;
  final String? username;
  final String? picture;
  final bool admin;

  factory Creator.fromJson(Map<String, dynamic> j) => Creator(
        email: j['email'] as String?,
        username: j['username'] as String?,
        picture: j['picture'] as String?,
        admin: j['admin'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'email': email, 'username': username, 'picture': picture, 'admin': admin};
}

class ThemeDescription {
  const ThemeDescription({required this.words, required this.teams});

  /// word -> difficulty (1-5)
  final Map<String, int> words;
  final List<String> teams;

  factory ThemeDescription.fromJson(Map<String, dynamic> j) {
    final rawWords = (j['words'] as Map?) ?? const {};
    return ThemeDescription(
      words: {
        for (final e in rawWords.entries)
          e.key as String: ((e.value as Map?)?['difficulty'] as num?)?.toInt() ?? 1,
      },
      teams: [for (final t in (j['teams'] as List? ?? const [])) t as String],
    );
  }

  Map<String, dynamic> toJson() => {
        'words': {
          for (final e in words.entries) e.key: {'difficulty': e.value},
        },
        'teams': teams,
      };
}

class GameTheme {
  const GameTheme({
    required this.id,
    required this.name,
    required this.language,
    required this.isPublic,
    required this.verified,
    required this.description,
    this.likesCount = 0,
    this.isFavorited = false,
    this.creator,
  });

  final int id;
  final String name;
  final String language;
  final bool isPublic;
  final bool verified;
  final ThemeDescription description;
  final int likesCount;
  final bool isFavorited;
  final Creator? creator;

  /// Accepts both the raw API shape (`likes`, `favourite`) and our persisted
  /// shape (`likes_count`, `is_favorited`).
  factory GameTheme.fromJson(Map<String, dynamic> j) => GameTheme(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        language: j['language'] as String? ?? 'en',
        isPublic: j['public'] as bool? ?? false,
        verified: j['verified'] as bool? ?? false,
        description:
            ThemeDescription.fromJson(j['description'] as Map<String, dynamic>),
        likesCount: ((j['likes'] ?? j['likes_count']) as num?)?.toInt() ?? 0,
        isFavorited: (j['favourite'] ?? j['is_favorited']) as bool? ?? false,
        creator: j['creator'] == null
            ? null
            : Creator.fromJson(j['creator'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'public': isPublic,
        'verified': verified,
        'description': description.toJson(),
        'likes_count': likesCount,
        'is_favorited': isFavorited,
        'creator': creator?.toJson(),
      };

  GameTheme copyWith({bool? isFavorited, int? likesCount}) => GameTheme(
        id: id,
        name: name,
        language: language,
        isPublic: isPublic,
        verified: verified,
        description: description,
        likesCount: likesCount ?? this.likesCount,
        isFavorited: isFavorited ?? this.isFavorited,
        creator: creator,
      );
}

class ThemeListItem {
  const ThemeListItem({
    required this.id,
    required this.name,
    required this.language,
    required this.verified,
    this.likesCount = 0,
  });

  final int id;
  final String name;
  final String language;
  final bool verified;
  final int likesCount;

  factory ThemeListItem.fromJson(Map<String, dynamic> j) => ThemeListItem(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        language: j['language'] as String? ?? 'en',
        verified: j['verified'] as bool? ?? false,
        likesCount: (j['likes'] as num?)?.toInt() ?? 0,
      );
}

class Paginated<T> {
  const Paginated({required this.items, required this.total, required this.pages});

  final List<T> items;
  final int total;
  final int pages;

  factory Paginated.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromItem,
  ) =>
      Paginated(
        items: [for (final i in j['items'] as List) fromItem(i as Map<String, dynamic>)],
        total: (j['total'] as num?)?.toInt() ?? 0,
        pages: (j['pages'] as num?)?.toInt() ?? 1,
      );
}

class TeamScore {
  const TeamScore(this.name, this.score);

  final String name;
  final int score;

  factory TeamScore.fromJson(Map<String, dynamic> j) =>
      TeamScore(j['name'] as String, (j['score'] as num).toInt());

  Map<String, dynamic> toJson() => {'name': name, 'score': score};
}

class GameInfo {
  const GameInfo({required this.teams, this.currentTeamIndex, this.currentRound});

  final List<TeamScore> teams;
  final int? currentTeamIndex;
  final int? currentRound;

  factory GameInfo.fromJson(Map<String, dynamic>? j) => GameInfo(
        teams: [
          for (final t in (j?['teams'] as List? ?? const []))
            TeamScore.fromJson(t as Map<String, dynamic>),
        ],
        currentTeamIndex: (j?['current_team_index'] as num?)?.toInt(),
        currentRound: (j?['current_round'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'teams': [for (final t in teams) t.toJson()],
        'current_team_index': currentTeamIndex ?? 0,
        'current_round': currentRound ?? 0,
      };
}

class GameListItem {
  const GameListItem({
    required this.id,
    required this.themeId,
    required this.startedAt,
    required this.endedAt,
    required this.points,
    required this.round,
    required this.skipPenalty,
    required this.themeName,
    required this.themeLanguage,
  });

  final int id;
  final int themeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int points;
  final int round;
  final bool skipPenalty;
  final String themeName;
  final String themeLanguage;

  factory GameListItem.fromJson(Map<String, dynamic> j) {
    final theme = j['theme'] as Map<String, dynamic>? ?? const {};
    return GameListItem(
      id: (j['id'] as num).toInt(),
      themeId: (j['theme_id'] as num).toInt(),
      startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
      endedAt: j['ended_at'] == null
          ? null
          : DateTime.parse(j['ended_at'] as String).toLocal(),
      points: (j['points'] as num).toInt(),
      round: (j['round'] as num).toInt(),
      skipPenalty: j['skip_penalty'] as bool? ?? false,
      themeName: theme['name'] as String? ?? '',
      themeLanguage: theme['language'] as String? ?? '',
    );
  }
}

class GameDetails {
  const GameDetails({
    required this.id,
    required this.themeId,
    this.difficulty,
    required this.startedAt,
    required this.endedAt,
    required this.points,
    required this.round,
    required this.skipPenalty,
    required this.info,
    required this.wordsGuessed,
    required this.wordsSkipped,
    required this.themeName,
    required this.themeLanguage,
  });

  final int id;
  final int themeId;
  final int? difficulty;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int points;
  final int round;
  final bool skipPenalty;
  final GameInfo info;
  final List<String> wordsGuessed;
  final List<String> wordsSkipped;
  final String themeName;
  final String themeLanguage;

  factory GameDetails.fromJson(Map<String, dynamic> j) {
    final theme = j['theme'] as Map<String, dynamic>? ?? const {};
    return GameDetails(
      id: (j['id'] as num).toInt(),
      themeId: (j['theme_id'] as num).toInt(),
      difficulty: (j['difficulty'] as num?)?.toInt(),
      startedAt: DateTime.parse(j['started_at'] as String).toLocal(),
      endedAt: j['ended_at'] == null
          ? null
          : DateTime.parse(j['ended_at'] as String).toLocal(),
      points: (j['points'] as num).toInt(),
      round: (j['round'] as num).toInt(),
      skipPenalty: j['skip_penalty'] as bool? ?? false,
      info: GameInfo.fromJson(j['info'] as Map<String, dynamic>?),
      wordsGuessed: [for (final w in (j['words_guessed'] as List? ?? const [])) w as String],
      wordsSkipped: [for (final w in (j['words_skipped'] as List? ?? const [])) w as String],
      themeName: theme['name'] as String? ?? '',
      themeLanguage: theme['language'] as String? ?? '',
    );
  }
}

class WordResult {
  const WordResult(this.word, this.guessed);

  final String word;
  final bool guessed;

  WordResult toggled() => WordResult(word, !guessed);

  factory WordResult.fromJson(Map<String, dynamic> j) =>
      WordResult(j['word'] as String, j['guessed'] as bool);

  Map<String, dynamic> toJson() => {'word': word, 'guessed': guessed};
}

class GameSettings {
  const GameSettings({
    required this.theme,
    required this.selectedTeams,
    required this.difficulty,
    required this.pointsRequired,
    required this.roundTimer,
    required this.skipPenalty,
  });

  final GameTheme theme;
  final List<String> selectedTeams;
  final int difficulty; // 1-5
  final int pointsRequired; // 10-100
  final int roundTimer; // 15-120, step 15
  final bool skipPenalty;

  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
        theme: GameTheme.fromJson(j['theme'] as Map<String, dynamic>),
        selectedTeams: [for (final t in j['selectedTeams'] as List) t as String],
        difficulty: (j['difficulty'] as num).toInt(),
        pointsRequired: (j['pointsRequired'] as num).toInt(),
        roundTimer: (j['roundTimer'] as num).toInt(),
        skipPenalty: j['skipPenalty'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.toJson(),
        'selectedTeams': selectedTeams,
        'difficulty': difficulty,
        'pointsRequired': pointsRequired,
        'roundTimer': roundTimer,
        'skipPenalty': skipPenalty,
      };
}

/// Persistent, between-rounds game state. Per-round state (the shuffled deck,
/// the current word, the running timer) lives in the game play screen, as in
/// the web app.
class GameState {
  const GameState({
    required this.settings,
    required this.currentTeamIndex,
    required this.currentRound,
    required this.teamScores,
    required this.wordsUsed,
    this.roundResults = const [],
    this.lastWord,
  });

  final GameSettings settings;
  final int currentTeamIndex;
  final int currentRound;

  /// Insertion order matches `settings.selectedTeams`.
  final Map<String, int> teamScores;
  final List<String> wordsUsed;

  /// Results of the round awaiting confirmation.
  final List<WordResult> roundResults;

  /// Word on screen when the timer ran out; the team may credit it (+1, never a penalty).
  final String? lastWord;

  bool get hasPendingResults => roundResults.isNotEmpty || lastWord != null;

  String get currentTeam => settings.selectedTeams[currentTeamIndex];

  GameState copyWith({
    int? currentTeamIndex,
    int? currentRound,
    Map<String, int>? teamScores,
    List<String>? wordsUsed,
    List<WordResult>? roundResults,
    Object? lastWord = _unset,
  }) =>
      GameState(
        settings: settings,
        currentTeamIndex: currentTeamIndex ?? this.currentTeamIndex,
        currentRound: currentRound ?? this.currentRound,
        teamScores: teamScores ?? this.teamScores,
        wordsUsed: wordsUsed ?? this.wordsUsed,
        roundResults: roundResults ?? this.roundResults,
        lastWord: identical(lastWord, _unset) ? this.lastWord : lastWord as String?,
      );

  factory GameState.fromJson(Map<String, dynamic> j) => GameState(
        settings: GameSettings.fromJson(j['settings'] as Map<String, dynamic>),
        currentTeamIndex: (j['currentTeamIndex'] as num).toInt(),
        currentRound: (j['currentRound'] as num).toInt(),
        teamScores: {
          for (final e in (j['teamScores'] as Map).entries)
            e.key as String: (e.value as num).toInt(),
        },
        wordsUsed: [for (final w in j['wordsUsed'] as List) w as String],
        roundResults: [
          for (final r in (j['roundResults'] as List? ?? const []))
            WordResult.fromJson(r as Map<String, dynamic>),
        ],
        lastWord: j['lastWord'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'currentTeamIndex': currentTeamIndex,
        'currentRound': currentRound,
        'teamScores': teamScores,
        'wordsUsed': wordsUsed,
        'roundResults': [for (final r in roundResults) r.toJson()],
        'lastWord': lastWord,
      };
}

const _unset = Object();
