import 'game.dart';

/// One person's results across a set of games.
class WinSummary {
  const WinSummary({
    required this.name,
    required this.played,
    required this.wins,
    this.also = const [],
  });

  /// The name shown for this person.
  final String name;
  final int played;
  final int wins;

  /// Other spellings that count as [name], in this set of games.
  final List<String> also;

  /// Share of the games this person played that they won, nearest percent.
  int get winPercent => played == 0 ? 0 : ((wins * 100) / played).round();
}

/// Who [name] counts as. Links in [samePerson] are spelling to person.
///
/// A chain follows through. A loop picks one stable name so both spellings
/// still land on the same person.
String personRoot(String name, Map<String, String> samePerson) {
  final seen = <String>[];
  var current = name.trim();
  while (true) {
    final loop = seen.indexOf(current);
    if (loop >= 0) {
      final cycle = seen.sublist(loop)..sort();
      return cycle.first;
    }
    seen.add(current);
    final next = samePerson[current]?.trim();
    if (next == null || next.isEmpty || next == current) return current;
    current = next;
  }
}

/// Record that [spelling] is the same person as [countsAs].
///
/// [countsAs] equal to [spelling] makes that spelling its own person again.
/// Choosing a spelling that already counts as someone else uses that person.
/// The map stays flat: each value is a person who does not point onward.
void applySamePerson(
  Map<String, String> samePerson,
  String spelling,
  String countsAs,
) {
  if (countsAs == spelling) {
    samePerson.remove(spelling);
    return;
  }
  final target = personRoot(countsAs, samePerson);
  if (target == spelling) {
    _repoint(samePerson, from: spelling, to: countsAs);
    samePerson.remove(countsAs);
    samePerson[spelling] = countsAs;
    return;
  }
  _repoint(samePerson, from: spelling, to: target);
  if (spelling != target) samePerson[spelling] = target;
  samePerson.remove(target);
}

/// File [members] under [display], the name shown in the summary.
///
/// [previousDisplay] is the person being edited. Spellings that counted as
/// that person, and are not in [members], stand on their own again. A
/// spelling pulled in from another person does not drag the rest of that
/// person along.
void applyGroup(
  Map<String, String> samePerson, {
  required Iterable<String> allNames,
  required String previousDisplay,
  required String display,
  required Set<String> members,
}) {
  final names = <String>{
    for (final name in allNames)
      if (name.trim().isNotEmpty) name.trim(),
    if (display.trim().isNotEmpty) display.trim(),
    if (previousDisplay.trim().isNotEmpty) previousDisplay.trim(),
  };
  final keep = <String>{
    for (final name in members)
      if (name.trim().isNotEmpty) name.trim(),
    if (display.trim().isNotEmpty) display.trim(),
  };
  final oldRoot = <String, String>{
    for (final name in names) name: personRoot(name, samePerson),
  };
  final shown = display.trim();
  for (final name in names) {
    final wasHere =
        oldRoot[name] == previousDisplay ||
        oldRoot[name] == shown ||
        keep.contains(oldRoot[name]);
    if (name == shown) {
      samePerson.remove(name);
    } else if (keep.contains(name)) {
      samePerson[name] = shown;
    } else if (wasHere) {
      samePerson.remove(name);
    }
  }
}

void _repoint(
  Map<String, String> samePerson, {
  required String from,
  required String to,
}) {
  for (final key in samePerson.keys.toList()) {
    if (samePerson[key] == from) samePerson[key] = to;
  }
}

/// Every distinct player spelling in [games], plus anyone named in [samePerson].
List<String> knownNames(Iterable<Game> games, Map<String, String> samePerson) {
  final names = <String>{};
  for (final game in games) {
    for (final raw in game.players) {
      final name = raw.trim();
      if (name.isNotEmpty) names.add(name);
    }
  }
  for (final entry in samePerson.entries) {
    final from = entry.key.trim();
    final to = entry.value.trim();
    if (from.isNotEmpty) names.add(from);
    if (to.isNotEmpty) names.add(to);
  }
  final list = names.toList();
  list.sort(_bySpelling);
  return list;
}

/// Games each trimmed spelling appears in, counted once per game.
Map<String, int> spellingCounts(Iterable<Game> games) {
  final counts = <String, int>{};
  for (final game in games) {
    final seen = <String>{};
    for (final raw in game.players) {
      final name = raw.trim();
      if (name.isEmpty || !seen.add(name)) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  return counts;
}

/// The spelling used in the most games.
///
/// A tie picks the earlier name, ignoring case, then the exact spelling.
/// Davca beats David when both were used equally often. No names returns null.
String? mostFrequent(Iterable<String> names, Map<String, int> counts) {
  String? best;
  var bestCount = -1;
  for (final raw in names) {
    final name = raw.trim();
    if (name.isEmpty) continue;
    final count = counts[name] ?? 0;
    if (best == null ||
        count > bestCount ||
        (count == bestCount && _bySpelling(name, best) < 0)) {
      best = name;
      bestCount = count;
    }
  }
  return best;
}

/// Wins across [games].
///
/// [samePerson] merges spellings. A tie counts once for every person at the
/// top. Two spellings of one person in the same game count as one seat.
/// A game with no rounds counts as played and won by nobody.
List<WinSummary> winSummary(
  Iterable<Game> games, [
  Map<String, String> samePerson = const {},
]) {
  final played = <String, int>{};
  final wins = <String, int>{};
  final spellings = <String, Set<String>>{};
  for (final game in games) {
    final playedHere = <String>{};
    for (final raw in game.players) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final who = personRoot(name, samePerson);
      playedHere.add(who);
      spellings.putIfAbsent(who, () => {}).add(name);
    }
    final wonHere = <String>{
      for (final i in game.leaders)
        if (game.players[i].trim().isNotEmpty)
          personRoot(game.players[i].trim(), samePerson),
    };
    for (final name in playedHere) {
      played[name] = (played[name] ?? 0) + 1;
      if (wonHere.contains(name)) wins[name] = (wins[name] ?? 0) + 1;
    }
  }
  final rows = [
    for (final name in played.keys)
      WinSummary(
        name: name,
        played: played[name]!,
        wins: wins[name] ?? 0,
        also: _otherSpellings(spellings[name] ?? const {}, name),
      ),
  ];
  rows.sort((a, b) {
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) return byWins;
    final byPercent = b.winPercent.compareTo(a.winPercent);
    if (byPercent != 0) return byPercent;
    return a.name.compareTo(b.name);
  });
  return rows;
}

List<String> _otherSpellings(Set<String> spellings, String display) {
  final others = [
    for (final name in spellings)
      if (name != display) name,
  ];
  others.sort(_bySpelling);
  return others;
}

int _bySpelling(String a, String b) {
  final byLower = a.toLowerCase().compareTo(b.toLowerCase());
  return byLower != 0 ? byLower : a.compareTo(b);
}

/// Display names, one per person, sorted like [knownNames].
List<String> shownNames(
  Iterable<String> names,
  Map<String, String> samePerson,
) {
  final shown = <String>{
    for (final name in names) personRoot(name, samePerson),
  };
  final list = shown.toList();
  list.sort(_bySpelling);
  return list;
}
