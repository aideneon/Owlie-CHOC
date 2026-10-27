import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../models/favorite.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/intensity_colors.dart';
import '../utils/fade_page_route.dart';
import '../utils/phone_launcher.dart';
import '../widgets/app_shell.dart';
import '../widgets/emotion_controls.dart';
import 'session_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static const crisisLineNumber = '988';

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  /// First paint shows a spinner so a blank wait never appears while the
  /// favorites list (and any background media work) settles.
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _contentReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final showLoading = !_contentReady || !appState.isLoaded;

    return AppShell(
      title: 'Favorites',
      titleColor: const Color(0xFF424242),
      backgroundColor: AppTheme.homeBackground,
      body: showLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5D4E37),
              ),
            )
          : const _FavoritesBody(),
    );
  }
}

class _FavoritesBody extends StatefulWidget {
  const _FavoritesBody();

  @override
  State<_FavoritesBody> createState() => _FavoritesBodyState();
}

class _FavoritesBodyState extends State<_FavoritesBody> {
  int? _selectedIntensity;

  static const _emptyStyle = TextStyle(
    fontSize: 16,
    color: Color(0xFF424242),
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedBand = _selectedIntensity == null
        ? null
        : IntensityColors.bandForLevel(_selectedIntensity!);
    final selectedFavorites =
        selectedBand == null ? const <FavoriteEntry>[] : appState.favoritesByBand()[selectedBand]!;

    return Column(
      children: [
        const SizedBox(height: 8),
        IntensityScale(
          selectedIntensity: _selectedIntensity,
          onIntensitySelected: (intensity) {
            setState(() => _selectedIntensity = intensity);
          },
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_selectedIntensity == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Choose an intensity to see your saved exercises.',
                    textAlign: TextAlign.center,
                    style: _emptyStyle,
                  ),
                )
              else if (selectedFavorites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No favorites for this intensity yet.\n'
                    'During an exercise session, tap the star '
                    'next to an exercise to save it here.',
                    textAlign: TextAlign.center,
                    style: _emptyStyle,
                  ),
                )
              else
                for (final favorite in selectedFavorites)
                  _FavoriteExerciseTile(
                    favorite: favorite,
                    name: appState.exerciseName(favorite.exerciseId),
                    onRemove: () => appState.removeFavorite(favorite.exerciseId),
                  ),
              const SizedBox(height: 24),
              const _ContactsSection(),
              const SizedBox(height: 16),
              _CrisisLineButton(
                onTap: () => launchPhoneCall(FavoritesScreen.crisisLineNumber),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _showFavoritesDialog<void>(
                  context,
                  builder: (_) => const _AdditionalResourcesDialog(),
                ),
                child: const Text('Additional resources: click here'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteExerciseTile extends StatelessWidget {
  const _FavoriteExerciseTile({
    required this.favorite,
    required this.name,
    required this.onRemove,
  });

  final FavoriteEntry favorite;
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          title: Text(name),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: onRemove,
            tooltip: 'Remove favorite',
          ),
          onTap: () {
            Navigator.of(context).push(
              FadePageRoute<void>(
                duration: Duration.zero,
                builder: (_) => SessionScreen(
                  emotionId: null,
                  intensity: favorite.intensity,
                  directExerciseId: favorite.exerciseId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Who I can text / call for distraction, support, or to talk with:',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF424242),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < appState.contacts.length; i++)
              _ContactChip(
                contact: appState.contacts[i],
                onTap: () => _callContact(context, appState.contacts[i]),
                onEdit: () => _editContact(context, appState, i),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add contact'),
              onPressed: () => _addContact(context, appState),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _callContact(BuildContext context, SupportContact contact) async {
    if (contact.phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add a phone number for ${contact.name} first.')),
      );
      return;
    }

    final ok = await launchPhoneCall(contact.phoneNumber);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _addContact(BuildContext context, AppState appState) async {
    final result = await _showFavoritesDialog<SupportContact>(
      context,
      builder: (_) => const _ContactEditorDialog(),
    );
    if (result != null) {
      await appState.addContact(result);
    }
  }

  Future<void> _editContact(
    BuildContext context,
    AppState appState,
    int index,
  ) async {
    final result = await _showFavoritesDialog<SupportContact>(
      context,
      builder: (_) => _ContactEditorDialog(contact: appState.contacts[index]),
    );
    if (result != null) {
      await appState.updateContact(index, result);
    }
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.contact,
    required this.onTap,
    required this.onEdit,
  });

  final SupportContact contact;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(contact.name),
      onPressed: onTap,
      onDeleted: onEdit,
      deleteIcon: const Icon(Icons.edit, size: 18),
      backgroundColor: Colors.grey.shade300,
    );
  }
}

Future<T?> _showFavoritesDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 14 * curved.value,
          sigmaY: 14 * curved.value,
        ),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _FavoritesDialogShell extends StatelessWidget {
  const _FavoritesDialogShell({
    required this.icon,
    required this.title,
    required this.child,
    this.footer,
    this.iconColor = const Color(0xFF5D4E37),
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? footer;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Material(
          color: const Color(0xFFFAF6F0),
          elevation: 18,
          shadowColor: const Color(0xFF5D4E37).withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFF5D4E37).withValues(alpha: 0.10),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E3428),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF6D6258),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(
                  height: 1,
                  color: const Color(0xFF5D4E37).withValues(alpha: 0.12),
                ),
                const SizedBox(height: 16),
                child,
                if (footer != null) ...[
                  const SizedBox(height: 18),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactEditorDialog extends StatefulWidget {
  const _ContactEditorDialog({this.contact});

  final SupportContact? contact;

  @override
  State<_ContactEditorDialog> createState() => _ContactEditorDialogState();
}

class _ContactEditorDialogState extends State<_ContactEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  static const _fieldFill = Color(0xFFF3EEE6);
  static const _accent = Color(0xFF5D4E37);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.contact?.phoneNumber ?? '');
    _nameController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onChanged);
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _accent),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _accent.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      SupportContact(
        name: name,
        phoneNumber: _phoneController.text.trim(),
      ),
    );
  }

  Future<void> _delete() async {
    final appState = context.read<AppState>();
    final index = appState.contacts.indexOf(widget.contact!);
    if (index >= 0) await appState.removeContact(index);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;
    final canSave = _nameController.text.trim().isNotEmpty;

    return _FavoritesDialogShell(
      icon: isEditing ? Icons.person_rounded : Icons.person_add_alt_1_rounded,
      title: isEditing ? 'Edit contact' : 'Add contact',
      footer: Row(
        children: [
          if (isEditing)
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
              ),
              child: const Text('Delete'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6D6258),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _accent.withValues(alpha: 0.28),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: _fieldDecoration(
              label: 'Name',
              icon: Icons.person_outline_rounded,
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofocus: !isEditing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: _fieldDecoration(
              label: 'Phone number',
              icon: Icons.phone_outlined,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (canSave) _save();
            },
          ),
        ],
      ),
    );
  }
}

class _CrisisLineButton extends StatelessWidget {
  const _CrisisLineButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Crisis line: 988',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AdditionalResourcesDialog extends StatelessWidget {
  const _AdditionalResourcesDialog();

  @override
  Widget build(BuildContext context) {
    return _FavoritesDialogShell(
      icon: Icons.menu_book_rounded,
      title: 'Additional resources',
      iconColor: const Color(0xFF1565C0),
      child: Column(
        children: [
          _ResourceCard(
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFC62828),
            title: 'Emergency',
            subtitle: 'If this is an emergency, call 911.',
            onTap: () => launchPhoneCall('911'),
            actionLabel: 'Call 911',
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.sms_rounded,
            iconColor: const Color(0xFF1565C0),
            title: 'Crisis Text Line',
            subtitle: 'Text HOME to 741-741.',
            onTap: () => launchSms('741741', body: 'HOME'),
            actionLabel: 'Text 741-741',
          ),
          const SizedBox(height: 10),
          _ResourceCard(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFF6A1B9A),
            title: 'Trevor Project',
            subtitle: 'LGBTQ+ crisis lines. Text START to 678-678, or call.',
            actions: [
              _ResourceActionChip(
                icon: Icons.sms_outlined,
                label: 'Text 678-678',
                onTap: () => launchSms('678678', body: 'START'),
              ),
              _ResourceActionChip(
                icon: Icons.call_outlined,
                label: 'Call 866-488-7386',
                onTap: () => launchPhoneCall('8664887386'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.actionLabel,
    this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? actionLabel;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF5D4E37).withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3E3428),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Color(0xFF6D6258),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IgnorePointer(
                    child: _ResourceActionChip(
                      icon: Icons.arrow_forward_rounded,
                      label: actionLabel!,
                      onTap: onTap ?? () {},
                      color: iconColor,
                    ),
                  ),
                ),
              ],
              if (actions != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceActionChip extends StatelessWidget {
  const _ResourceActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? const Color(0xFF1565C0);
    return Material(
      color: tint.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
