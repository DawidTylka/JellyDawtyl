import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/unwanted_api.dart';

String formatShortDate(BuildContext context, DateTime date) =>
    MaterialLocalizations.of(context).formatShortDate(date);

/// Human description of an active snooze ("until 12.12.2026, new episode").
String describeSnooze(
  BuildContext context, {
  DateTime? until,
  bool untilNewEpisode = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final parts = <String>[
    if (until != null)
      l10n.unwantedSnoozedUntil(formatShortDate(context, until)),
    if (untilNewEpisode) l10n.unwantedUntilNewEpisode,
  ];
  return parts.isEmpty ? l10n.unwantedSnoozed : parts.join(' · ');
}

/// Buttons of the jellyfin-plugin-unwanted lists ("Na później", "Uśpij",
/// "Nieulubione") for a series, movie or episode. An episode or season acts
/// on its series, like in the plugin's web client. Shows nothing when the
/// server has no plugin.
class UnwantedActions extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String itemId;

  /// Called after "Nieulubione" was set, because the plugin also removes the
  /// item from favorites.
  final ValueChanged<UnwantedStatus>? onChanged;

  const UnwantedActions({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.itemId,
    this.onChanged,
  });

  @override
  State<UnwantedActions> createState() => _UnwantedActionsState();
}

class _UnwantedActionsState extends State<UnwantedActions> {
  final _api = UnwantedApi();
  UnwantedStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UnwantedActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId) _load();
  }

  Future<void> _load() async {
    final status = await _api.fetchStatus(
      widget.baseUrl,
      widget.token,
      widget.itemId,
    );
    if (mounted) setState(() => _status = status);
  }

  Future<void> _run(
    Future<UnwantedStatus?> Function() action,
    String message, {
    Future<UnwantedStatus?> Function()? undo,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final status = await action();
      if (!mounted) return;
      if (status != null) {
        setState(() => _status = status);
        widget.onChanged?.call(status);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: undo == null
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () async {
                    final reverted = await undo();
                    if (mounted && reverted != null) {
                      setState(() => _status = reverted);
                      widget.onChanged?.call(reverted);
                    }
                  },
                ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.unwantedError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _name => _status?.targetName ?? '';

  void _toggleWatchLater() {
    final l10n = AppLocalizations.of(context)!;
    final value = !(_status?.watchLater ?? false);
    _run(
      () => _api.setWatchLater(
        widget.baseUrl,
        widget.token,
        widget.itemId,
        value,
      ),
      value
          ? l10n.unwantedWatchLaterAdded(_name)
          : l10n.unwantedWatchLaterRemoved(_name),
    );
  }

  void _toggleUnwanted() {
    final l10n = AppLocalizations.of(context)!;
    final value = !(_status?.unwanted ?? false);
    _run(
      () =>
          _api.setUnwanted(widget.baseUrl, widget.token, widget.itemId, value),
      value ? l10n.unwantedMarked(_name) : l10n.unwantedRestored(_name),
      undo: () =>
          _api.setUnwanted(widget.baseUrl, widget.token, widget.itemId, !value),
    );
  }

  Future<void> _showSnoozeSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final status = _status;
    final choice = await showModalBottomSheet<_SnoozeChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.unwantedSnoozeTitle(_name),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.unwantedSnoozeHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (status?.snoozed == true)
                ListTile(
                  leading: const Icon(Icons.alarm_on),
                  title: Text(l10n.unwantedWake),
                  subtitle: Text(
                    describeSnooze(
                      context,
                      until: status?.snoozeUntil,
                      untilNewEpisode: status?.untilNewEpisode ?? false,
                    ),
                  ),
                  onTap: () =>
                      Navigator.pop(context, const _SnoozeChoice.wake()),
                ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: Text(l10n.unwantedSnoozeNewEpisode),
                onTap: () =>
                    Navigator.pop(context, const _SnoozeChoice.newEpisode()),
              ),
              for (final days in const [1, 3, 7, 14, 30, 90])
                ListTile(
                  leading: const Icon(Icons.snooze),
                  title: Text(switch (days) {
                    1 => l10n.unwantedSnoozeOneDay,
                    7 => l10n.unwantedSnoozeWeek,
                    14 => l10n.unwantedSnoozeTwoWeeks,
                    30 => l10n.unwantedSnoozeMonth,
                    90 => l10n.unwantedSnoozeThreeMonths,
                    _ => l10n.unwantedSnoozeDays(days),
                  }),
                  onTap: () => Navigator.pop(context, _SnoozeChoice.days(days)),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.wake) {
      _run(
        () => _api.wake(widget.baseUrl, widget.token, widget.itemId),
        l10n.unwantedWoken(_name),
      );
    } else {
      _run(
        () => _api.snooze(
          widget.baseUrl,
          widget.token,
          widget.itemId,
          days: choice.days,
          untilNewEpisode: choice.newEpisode,
        ),
        l10n.unwantedSnoozedMessage(_name),
        undo: () => _api.wake(widget.baseUrl, widget.token, widget.itemId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isEpisodeOfSeries = status.targetId != widget.itemId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToggleChip(
              selected: status.watchLater,
              icon: status.watchLater
                  ? Icons.watch_later
                  : Icons.watch_later_outlined,
              label: l10n.unwantedWatchLater,
              onPressed: _busy ? null : _toggleWatchLater,
            ),
            if (status.canSnooze)
              _ToggleChip(
                selected: status.snoozed,
                icon: status.snoozed ? Icons.bedtime : Icons.snooze,
                label: status.snoozed
                    ? describeSnooze(
                        context,
                        until: status.snoozeUntil,
                        untilNewEpisode: status.untilNewEpisode,
                      )
                    : l10n.unwantedSnooze,
                onPressed: _busy ? null : _showSnoozeSheet,
              ),
            _ToggleChip(
              selected: status.unwanted,
              icon: status.unwanted
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              label: l10n.unwantedNotInterested,
              onPressed: _busy ? null : _toggleUnwanted,
            ),
          ],
        ),
        if (isEpisodeOfSeries && (status.targetName ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.unwantedAppliesToSeries(status.targetName!),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _SnoozeChoice {
  final int? days;
  final bool newEpisode;
  final bool wake;

  const _SnoozeChoice.days(int this.days) : newEpisode = false, wake = false;
  const _SnoozeChoice.newEpisode()
    : days = null,
      newEpisode = true,
      wake = false;
  const _SnoozeChoice.wake() : days = null, newEpisode = false, wake = true;
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ToggleChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.deepPurpleAccent : Colors.white70;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: selected
            ? Colors.deepPurpleAccent.withValues(alpha: 0.15)
            : null,
        side: BorderSide(
          color: selected ? Colors.deepPurpleAccent : Colors.white24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
