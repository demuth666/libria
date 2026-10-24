import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../challenges/data/challenge.dart';
import '../../challenges/data/challenge_repository.dart';
import 'admin_challenges_providers.dart';

/// Kolom formulir yang memiliki pesan kesalahan sendiri.
enum _ChallengeField { title, description, target, endDate }

/// Formulir tambah dan ubah tantangan admin (FR-C1).
///
/// Rute `/admin/challenges/new` memakai formulir kosong, sedangkan
/// `/admin/challenges/:id/edit` memuat tantangan lebih dahulu lalu mengisi
/// formulir. Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian
/// 5.10 dan 7 serta bahasa visual formulir admin lain: kartu permukaan dengan
/// garis tipis, kolom teks bersama, pemilih jenis tantangan, pemilih tanggal
/// berbahasa Indonesia, serta tombol utama penuh.
class AdminChallengeFormScreen extends ConsumerWidget {
  const AdminChallengeFormScreen({this.challengeId, super.key});

  /// ID tantangan yang diubah; `null` berarti formulir tambah.
  final String? challengeId;

  bool get _isEditing => challengeId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEditing
        ? AppStrings.adminChallengeEditTitle
        : AppStrings.adminChallengeNewTitle;

    if (!_isEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const _ChallengeForm(),
      );
    }

    final String id = challengeId!;
    final AsyncValue<Challenge?> challenge = ref.watch(
      adminChallengeByIdProvider(id),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: challenge.when(
        data: (Challenge? value) {
          if (value == null) {
            return const _ChallengeNotFound();
          }
          return _ChallengeForm(
            key: ValueKey<String>(value.id),
            challenge: value,
          );
        },
        loading: () => const SafeArea(
          top: false,
          child: LoadingView(message: AppStrings.adminChallengeFormLoading),
        ),
        error: (Object error, StackTrace stackTrace) => SafeArea(
          top: false,
          child: ErrorView(
            message: error is ChallengeFailure
                ? error.message
                : AppStrings.adminChallengeFormLoadError,
            onRetry: () => ref.invalidate(adminChallengeByIdProvider(id)),
          ),
        ),
      ),
    );
  }
}

/// Keadaan tantangan yang hendak diubah tidak ditemukan.
class _ChallengeNotFound extends StatelessWidget {
  const _ChallengeNotFound();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: EmptyView(
        title: AppStrings.challengeNotFound,
        message: AppStrings.adminChallengeFormNotFoundMessage,
        icon: Icons.emoji_events_outlined,
        action: SecondaryButton(
          label: AppStrings.adminChallengeFormBackToList,
          icon: Icons.arrow_back,
          onPressed: () => context.go(AppRoutes.adminChallenges),
        ),
      ),
    );
  }
}

/// Isi formulir yang mengelola pengendali teks, jenis, tanggal, dan simpan.
class _ChallengeForm extends ConsumerStatefulWidget {
  const _ChallengeForm({this.challenge, super.key});

  /// Tantangan yang diubah; `null` untuk formulir tambah.
  final Challenge? challenge;

  @override
  ConsumerState<_ChallengeForm> createState() => _ChallengeFormState();
}

class _ChallengeFormState extends ConsumerState<_ChallengeForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late String _type;
  late DateTime _startDate;
  late DateTime _endDate;

  Map<_ChallengeField, String> _errors = <_ChallengeField, String>{};
  bool _isSaving = false;

  bool get _isEditing => widget.challenge != null;

  @override
  void initState() {
    super.initState();
    final Challenge? challenge = widget.challenge;
    _titleController = TextEditingController(text: challenge?.title ?? '');
    _descriptionController = TextEditingController(
      text: challenge?.description ?? '',
    );
    _targetController = TextEditingController(
      text: challenge == null ? '' : '${challenge.targetValue}',
    );
    _type = challenge?.type == Challenge.typeMinutes
        ? Challenge.typeMinutes
        : Challenge.typeBooks;
    _startDate = _initialStartDate(challenge?.startDate);
    _endDate = _initialEndDate(challenge?.endDate, _startDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  /// Tantangan baru dimulai hari ini dan berakhir sepekan kemudian agar
  /// tanggal langsung terisi dan tetap valid saat diubah pengguna.
  static DateTime _initialStartDate(DateTime? existing) {
    final DateTime value = existing ?? DateTime.now();
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _initialEndDate(DateTime? existing, DateTime startDate) {
    if (existing != null) {
      return DateTime(existing.year, existing.month, existing.day);
    }
    return startDate.add(const Duration(days: 7));
  }

  void _clearError(_ChallengeField field) {
    if (!_errors.containsKey(field)) {
      return;
    }
    setState(() {
      _errors = Map<_ChallengeField, String>.of(_errors)..remove(field);
    });
  }

  bool _validate() {
    final Map<_ChallengeField, String> errors = <_ChallengeField, String>{};
    final String targetText = _targetController.text.trim();
    final int? targetValue = int.tryParse(targetText);

    if (_titleController.text.trim().isEmpty) {
      errors[_ChallengeField.title] =
          AppStrings.adminChallengeFormTitleRequired;
    }
    if (_descriptionController.text.trim().isEmpty) {
      errors[_ChallengeField.description] =
          AppStrings.adminChallengeFormDescriptionRequired;
    }
    if (targetText.isEmpty) {
      errors[_ChallengeField.target] =
          AppStrings.adminChallengeFormTargetRequired;
    } else if (targetValue == null || targetValue <= 0) {
      errors[_ChallengeField.target] =
          AppStrings.adminChallengeFormTargetInvalid;
    }
    if (!_endDate.isAfter(_startDate)) {
      errors[_ChallengeField.endDate] =
          AppStrings.adminChallengeFormEndDateInvalid;
    }

    setState(() {
      _errors = errors;
    });
    return errors.isEmpty;
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await _showDatePicker(
      initialDate: _startDate,
      title: AppStrings.adminChallengeStartDatePickerTitle,
      keyPrefix: 'admin-challenge-start',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startDate = _dateOnly(picked);
      _errors = Map<_ChallengeField, String>.of(_errors)
        ..remove(_ChallengeField.endDate);
    });
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await _showDatePicker(
      initialDate: _endDate,
      title: AppStrings.adminChallengeEndDatePickerTitle,
      keyPrefix: 'admin-challenge-end',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _endDate = _dateOnly(picked);
      _errors = Map<_ChallengeField, String>.of(_errors)
        ..remove(_ChallengeField.endDate);
    });
  }

  Future<DateTime?> _showDatePicker({
    required DateTime initialDate,
    required String title,
    required String keyPrefix,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      builder: (BuildContext context) => _ChallengeDatePickerSheet(
        initialDate: initialDate,
        title: title,
        keyPrefix: keyPrefix,
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    bool saved = false;
    final int targetValue = int.parse(_targetController.text.trim());

    try {
      final ChallengeRepository repository = ref.read(
        challengeRepositoryProvider,
      );
      if (_isEditing) {
        await repository.updateChallenge(
          challengeId: widget.challenge!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          type: _type,
          targetValue: targetValue,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        await repository.createChallenge(
          title: _titleController.text,
          description: _descriptionController.text,
          type: _type,
          targetValue: targetValue,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (!mounted) {
        return;
      }
      saved = true;
      ref.read(adminChallengesReloadProvider.notifier).request();
      context.go(AppRoutes.adminChallenges);
    } on ChallengeFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(AppStrings.adminChallengeFormSaveError);
      }
    } finally {
      if (mounted && !saved) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final ScreenSize screenSize = Breakpoints.of(context);
    final double horizontalPadding = screenSize == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.lg,
          horizontalPadding,
          AppSpacing.xl,
        ),
        child: ContentWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing
                    ? AppStrings.adminChallengeFormSubtitleEdit
                    : AppStrings.adminChallengeFormSubtitleNew,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminChallengeFormSectionDetails,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      label: AppStrings.adminChallengeFormTitleLabel,
                      hint: AppStrings.adminChallengeFormTitleHint,
                      errorText: _errors[_ChallengeField.title],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_ChallengeField.title),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      label: AppStrings.adminChallengeFormDescriptionLabel,
                      hint: AppStrings.adminChallengeFormDescriptionHint,
                      errorText: _errors[_ChallengeField.description],
                      maxLines: 4,
                      onChanged: (_) =>
                          _clearError(_ChallengeField.description),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminChallengeFormSectionGoal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.adminChallengeFormTypeLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ChallengeTypeOption(
                      key: const ValueKey<String>('admin-challenge-type-books'),
                      icon: Icons.menu_book_outlined,
                      label: AppStrings.adminChallengeTypeBooks,
                      selected: _type == Challenge.typeBooks,
                      enabled: !_isSaving,
                      onTap: () {
                        setState(() {
                          _type = Challenge.typeBooks;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ChallengeTypeOption(
                      key: const ValueKey<String>(
                        'admin-challenge-type-minutes',
                      ),
                      icon: Icons.timer_outlined,
                      label: AppStrings.adminChallengeTypeMinutes,
                      selected: _type == Challenge.typeMinutes,
                      enabled: !_isSaving,
                      onTap: () {
                        setState(() {
                          _type = Challenge.typeMinutes;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _targetController,
                      enabled: !_isSaving,
                      label: AppStrings.adminChallengeFormTargetLabel,
                      hint: _type == Challenge.typeMinutes
                          ? AppStrings.adminChallengeFormTargetHintMinutes
                          : AppStrings.adminChallengeFormTargetHintBooks,
                      prefixIcon: Icons.flag_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      errorText: _errors[_ChallengeField.target],
                      onChanged: (_) => _clearError(_ChallengeField.target),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.adminChallengeFormSectionPeriod,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ChallengeDateField(
                      fieldKey: const ValueKey<String>(
                        'admin-challenge-start-date-field',
                      ),
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.adminChallengeFormStartDateLabel,
                      value: AppDateFormatter.date(_startDate),
                      enabled: !_isSaving,
                      onTap: _pickStartDate,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ChallengeDateField(
                      fieldKey: const ValueKey<String>(
                        'admin-challenge-end-date-field',
                      ),
                      icon: Icons.event_available_outlined,
                      label: AppStrings.adminChallengeFormEndDateLabel,
                      value: AppDateFormatter.date(_endDate),
                      errorText: _errors[_ChallengeField.endDate],
                      enabled: !_isSaving,
                      onTap: _pickEndDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                key: const ValueKey<String>('admin-challenge-save'),
                label: _isSaving
                    ? AppStrings.adminChallengeFormSaving
                    : AppStrings.adminChallengeFormSave,
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                expand: true,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Permukaan kartu formulir dengan garis dan bayangan dari token tema.
class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: child,
    );
  }
}

/// Pilihan jenis tantangan berupa kartu yang dapat diketuk.
class _ChallengeTypeOption extends StatelessWidget {
  const _ChallengeTypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.allLarge,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.surfaceContainerLow
                  : scheme.surfaceContainerLowest,
              borderRadius: AppRadius.allLarge,
              border: Border.all(
                color: selected ? scheme.secondary : extras.cardBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? scheme.secondary : scheme.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kolom tanggal yang membuka pemilih di lembar bawah.
class _ChallengeDateField extends StatelessWidget {
  const _ChallengeDateField({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.errorText,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final String value;
  final String? errorText;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: '$label: $value',
          child: Material(
            key: fieldKey,
            color: scheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.allMedium,
              side: BorderSide(
                color: errorText == null ? extras.inputBorder : scheme.error,
              ),
            ),
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: scheme.secondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

/// Pemilih kalender sederhana berbahasa Indonesia untuk tanggal tantangan.
///
/// Dibuat sendiri agar nama bulan dan hari memakai locale `id_ID` tanpa
/// menambah paket lokalisasi, mengikuti pemilih tanggal kegiatan (T-087).
class _ChallengeDatePickerSheet extends StatefulWidget {
  const _ChallengeDatePickerSheet({
    required this.initialDate,
    required this.title,
    required this.keyPrefix,
  });

  final DateTime initialDate;
  final String title;
  final String keyPrefix;

  @override
  State<_ChallengeDatePickerSheet> createState() =>
      _ChallengeDatePickerSheetState();
}

class _ChallengeDatePickerSheetState extends State<_ChallengeDatePickerSheet> {
  static final DateTime _weekdayAnchor = DateTime(2026, 10, 5);
  static final DateTime _firstDate = DateTime(2000);
  static final DateTime _lastDate = DateTime(2100, 12, 31);

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  DateTime get _firstMonth => DateTime(_firstDate.year, _firstDate.month);

  DateTime get _lastMonth => DateTime(_lastDate.year, _lastDate.month);

  bool get _canGoPrevious => _visibleMonth.isAfter(_firstMonth);

  bool get _canGoNext => _visibleMonth.isBefore(_lastMonth);

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _select(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int leadingBlanks = _visibleMonth.weekday - DateTime.monday;
    final int daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final int cellCount = leadingBlanks + daysInMonth;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: ContentWidth(
            maxWidth: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    IconButton(
                      key: ValueKey<String>(
                        '${widget.keyPrefix}-date-picker-prev',
                      ),
                      tooltip: AppStrings.datePickerPreviousMonth,
                      onPressed: _canGoPrevious ? () => _changeMonth(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        AppDateFormatter.monthYear(_visibleMonth),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>(
                        '${widget.keyPrefix}-date-picker-next',
                      ),
                      tooltip: AppStrings.datePickerNextMonth,
                      onPressed: _canGoNext ? () => _changeMonth(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    for (int index = 0; index < 7; index++)
                      Expanded(
                        child: Text(
                          AppDateFormatter.weekdayNarrow(
                            _weekdayAnchor.add(Duration(days: index)),
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    if (index < leadingBlanks) {
                      return const SizedBox.shrink();
                    }
                    final int day = index - leadingBlanks + 1;
                    final DateTime date = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month,
                      day,
                    );
                    return _CalendarDay(
                      keyPrefix: widget.keyPrefix,
                      date: date,
                      selected: _isSameDay(date, _selectedDate),
                      onTap: () => _select(date),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    TextButton(
                      key: ValueKey<String>(
                        '${widget.keyPrefix}-date-picker-cancel',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.datePickerCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        key: ValueKey<String>(
                          '${widget.keyPrefix}-date-picker-confirm',
                        ),
                        label: AppStrings.datePickerConfirm,
                        expand: true,
                        onPressed: _confirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu tanggal pada kalender pemilih.
class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.keyPrefix,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String keyPrefix;
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: AppDateFormatter.date(date),
      child: InkWell(
        key: ValueKey<String>(
          '$keyPrefix-day-${date.year}-${date.month}-${date.day}',
        ),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : null,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${date.day}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
