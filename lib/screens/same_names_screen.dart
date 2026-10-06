import 'package:flutter/material.dart';

import '../data/win_summary.dart';

/// Types the summary name for one person and ticks which spellings count.
class PersonNameScreen extends StatefulWidget {
  const PersonNameScreen({
    super.key,
    required this.names,
    required this.counts,
    required this.display,
    required this.samePerson,
    required this.displayNames,
    required this.onChanged,
  });

  final List<String> names;
  final Map<String, int> counts;

  /// The name being edited, or empty when this is a new name.
  final String display;

  final Map<String, String> samePerson;
  final List<String> displayNames;
  final Future<void> Function() onChanged;

  @override
  State<PersonNameScreen> createState() => _PersonNameScreenState();
}

class _PersonNameScreenState extends State<PersonNameScreen> {
  late final TextEditingController _shown;

  /// The label this screen last saved. Empty until a new name is typed.
  late String _owned;

  /// Spellings the user ticked. The summary name is not inferred from this
  /// when it collides with a spelling they left unticked.
  final Set<String> _selected = {};

  /// True after the user types a name that is not the most used spelling.
  /// Ticks do not set this. Clearing the field turns it off again.
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _owned = widget.display.trim();
    if (_owned.isNotEmpty) {
      for (final name in widget.names) {
        if (personRoot(name, widget.samePerson) == _owned) {
          _selected.add(name);
        }
      }
    }
    final auto = mostFrequent(_selected, widget.counts) ?? '';
    _manual = _owned.isNotEmpty && _owned != auto;
    _shown = TextEditingController(text: _owned);
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  String _field() => _shown.text.trim();

  bool _locked(String name) => _manual && _field() == name;

  void _onTyped(String value) {
    final auto = mostFrequent(_selected, widget.counts) ?? '';
    _manual = value.trim().isNotEmpty && value.trim() != auto;
    _onEdited();
  }

  bool _ticked(String name) => _selected.contains(name) || _field() == name;

  /// True when some game spelling already is, or counts as, [shown].
  bool _taken(String shown) {
    for (final name in widget.names) {
      if (name == shown || personRoot(name, widget.samePerson) == shown) {
        return true;
      }
    }
    return false;
  }

  bool get _canRemove {
    final shown = _field();
    if (shown.isEmpty || (_selected.isEmpty && _owned.isEmpty)) return false;
    final auto = mostFrequent(_selected, widget.counts);
    return !(_selected.length == 1 &&
        shown == auto &&
        shown == _selected.single);
  }

  Future<void> _onEdited() async {
    await _commit();
    if (mounted) setState(() {});
  }

  void _toggle(String name) {
    if (_locked(name)) return;
    if (_field() == name && !_selected.contains(name)) return;
    if (!_selected.add(name)) _selected.remove(name);
    _onEdited();
  }

  void _releaseOwned() {
    if (_owned.isEmpty) return;
    applyGroup(
      widget.samePerson,
      allNames: widget.names,
      previousDisplay: _owned,
      display: _owned,
      members: const {},
    );
    widget.displayNames.remove(_owned);
    _owned = '';
  }

  Future<void> _commit() async {
    final typed = _field();
    final auto = mostFrequent(_selected, widget.counts) ?? '';
    final shown = _manual ? typed : auto;

    if (!_manual && _shown.text != shown) {
      _shown.value = TextEditingValue(
        text: shown,
        selection: TextSelection.collapsed(offset: shown.length),
      );
    }

    // A blank new screen must not grab a person just because the text
    // matches their name. Clear an orphan we had started instead.
    if (shown.isEmpty ||
        (_selected.isEmpty && shown != _owned && _taken(shown))) {
      _releaseOwned();
      await widget.onChanged();
      return;
    }

    final members = <String>{..._selected};
    if (widget.names.contains(shown)) members.add(shown);
    applyGroup(
      widget.samePerson,
      allNames: widget.names,
      previousDisplay: _owned,
      display: shown,
      members: members,
    );
    widget.displayNames.remove(_owned);
    if (members.isEmpty) {
      widget.displayNames
        ..remove(shown)
        ..add(shown);
    } else {
      widget.displayNames.remove(shown);
    }
    _owned = shown;
    await widget.onChanged();
  }

  Future<void> _remove() async {
    _releaseOwned();
    widget.displayNames.remove(_field());
    await widget.onChanged();
    if (mounted) Navigator.of(context).pop();
  }

  String _games(String name) {
    final n = widget.counts[name] ?? 0;
    return n == 1 ? '1 game' : '$n games';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final title = _field().isEmpty ? 'New name' : _field();
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              'Tick every spelling that is this person. '
              'The name starts as the one from the most games. '
              'Type to choose your own.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: TextField(
              controller: _shown,
              decoration: const InputDecoration(
                labelText: 'Shown in the summary',
                helperText: 'Defaults to the spelling used in the most games.',
              ),
              onChanged: _onTyped,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Spellings', style: theme.textTheme.labelMedium),
          ),
          for (final name in widget.names)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 8, right: 4),
              title: Text(name),
              subtitle: Text(_games(name)),
              trailing: Checkbox(
                key: ValueKey('same-$name'),
                value: _ticked(name),
                onChanged: _locked(name) ? null : (_) => _toggle(name),
              ),
              onTap: _locked(name) ? null : () => _toggle(name),
            ),
          if (_canRemove)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _remove,
                child: Text(
                  'Remove this name',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
