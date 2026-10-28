import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/jellyfin_api.dart';

class FavoriteButton extends StatefulWidget {
  final String baseUrl;
  final String token;
  final String userId;
  final String itemId;
  final bool initialIsFavorite;
  final ValueChanged<bool>? onChanged;
  final double iconSize;

  const FavoriteButton({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.userId,
    required this.itemId,
    required this.initialIsFavorite,
    this.onChanged,
    this.iconSize = 22,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _isFavorite;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initialIsFavorite;
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        (!_isSaving &&
            oldWidget.initialIsFavorite != widget.initialIsFavorite)) {
      _isFavorite = widget.initialIsFavorite;
    }
  }

  Future<void> _toggle() async {
    if (_isSaving) return;
    final nextValue = !_isFavorite;
    setState(() {
      _isFavorite = nextValue;
      _isSaving = true;
    });

    final success = await JellyfinApi().setFavorite(
      baseUrl: widget.baseUrl,
      token: widget.token,
      userId: widget.userId,
      itemId: widget.itemId,
      isFavorite: nextValue,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (!success) _isFavorite = !nextValue;
    });

    if (success) {
      widget.onChanged?.call(nextValue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.favoriteUpdateError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: _isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
        onPressed: _isSaving ? null : _toggle,
        icon: _isSaving
            ? SizedBox(
                width: widget.iconSize,
                height: widget.iconSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.redAccent : Colors.white,
                size: widget.iconSize,
              ),
      ),
    );
  }
}
