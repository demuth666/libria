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
import '../../events/data/app_event.dart';
import '../../events/data/event_repository.dart';
import 'admin_events_providers.dart';

/// Kolom formulir yang memiliki pesan kesalahan sendiri.
enum _EventField { title, description, location }

/// Formulir tambah dan ubah kegiatan admin (FR-E1).
///
/// Rute `/admin/events/new` memakai formulir kosong, sedangkan
/// `/admin/events/:id/edit` memuat kegiatan lebih dahulu lalu mengisi formulir.
/// Layar ini tidak ada di Stitch. Susunannya mengikuti PRD bagian 5.9 dan 7
/// serta bahasa visual formulir admin lain: kartu permukaan dengan garis tipis,
/// kolom teks bersama, pemilih tanggal dan jam berbahasa Indonesia, serta
/// tombol utama penuh.
class AdminEventFormScreen extends ConsumerWidget {
  const AdminEventFormScreen({this.eventId, super.key});

  /// ID kegiatan yang diubah; `null` berarti formulir tambah.
  final String? eventId;

  bool get _isEditing => eventId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _isEditing
        ? AppStrings.adminEventEditTitle
        : AppStrings.adminEventNewTitle;

    if (!_isEditing) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const _EventForm(),
      );
    }

    final String id = eventId!;
    final AsyncValue<AppEvent?> event = ref.watch(adminEventByIdProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: event.when(
        data: (AppEvent? value) {
          if (value == null) {
            return const _EventNotFound();
          }
          return _EventForm(key: ValueKey<String>(value.id), event: value);
        },
        loading: () => const SafeArea(
          top: false,
          child: LoadingView(message: AppStrings.adminEventFormLoading),
        ),
        error: (Object error, StackTrace stackTrace) => SafeArea(
          top: false,
          child: ErrorView(
            message: error is EventFailure
                ? error.message
                : AppStrings.adminEventFormLoadError,
            onRetry: () => ref.invalidate(adminEventByIdProvider(id)),
          ),
        ),
      ),
    );
  }
}

/// Keadaan kegiatan yang hendak diubah tidak ditemukan.
class _EventNotFound extends StatelessWidget {
  const _EventNotFound();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: EmptyView(
        title: AppStrings.eventsNotFound,
        message: AppStrings.adminEventFormNotFoundMessage,
        icon: Icons.event_busy_outlined,
        action: SecondaryButton(
          label: AppStrings.adminEventFormBackToList,
          icon: Icons.arrow_back,
          onPressed: () => context.go(AppRoutes.adminEvents),
        ),
      ),
    );
  }
}

/// Isi formulir yang mengelola pengendali teks, jadwal, dan keadaan simpan.
class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.event, super.key});

  /// Kegiatan yang diubah; `null` untuk formulir tambah.
  final AppEvent? event;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late DateTime _startAt;

  Map<_EventField, String> _errors = <_EventField, String>{};
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final AppEvent? event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _locationController = TextEditingController(text: event?.location ?? '');
    _startAt = _initialStartAt(event?.startAt);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Kegiatan baru dimulai dengan jadwal besok pukul 19.00 agar formulir
  /// langsung memiliki tanggal dan jam yang dapat diubah pengguna.
  static DateTime _initialStartAt(DateTime? existing) {
    if (existing != null) {
      return DateTime(
        existing.year,
        existing.month,
        existing.day,
        existing.hour,
        existing.minute,
      );
    }
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19);
  }

  void _clearError(_EventField field) {
    if (!_errors.containsKey(field)) {
      return;
    }
    setState(() {
      _errors = Map<_EventField, String>.of(_errors)..remove(field);
    });
  }

  bool _validate() {
    final Map<_EventField, String> errors = <_EventField, String>{};

    if (_titleController.text.trim().isEmpty) {
      errors[_EventField.title] = AppStrings.adminEventFormTitleRequired;
    }
    if (_descriptionController.text.trim().isEmpty) {
      errors[_EventField.description] =
          AppStrings.adminEventFormDescriptionRequired;
    }
    if (_locationController.text.trim().isEmpty) {
      errors[_EventField.location] = AppStrings.adminEventFormLocationRequired;
    }

    setState(() {
      _errors = errors;
    });
    return errors.isEmpty;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      builder: (BuildContext context) =>
          _EventDatePickerSheet(initialDate: _startAt),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startAt.hour,
        _startAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.extraLarge),
        ),
      ),
      builder: (BuildContext context) =>
          _EventTimePickerSheet(initialTime: TimeOfDay.fromDateTime(_startAt)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startAt = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        picked.hour,
        picked.minute,
      );
    });
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

    try {
      final EventRepository repository = ref.read(eventRepositoryProvider);
      if (_isEditing) {
        await repository.updateEvent(
          eventId: widget.event!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          startAt: _startAt,
          location: _locationController.text,
        );
      } else {
        await repository.createEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          startAt: _startAt,
          location: _locationController.text,
        );
      }

      if (!mounted) {
        return;
      }
      saved = true;
      ref.read(adminEventsReloadProvider.notifier).request();
      context.go(AppRoutes.adminEvents);
    } on EventFailure catch (failure) {
      if (mounted) {
        _showMessage(failure.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(AppStrings.adminEventFormSaveError);
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
                    ? AppStrings.adminEventFormSubtitleEdit
                    : AppStrings.adminEventFormSubtitleNew,
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
                      AppStrings.adminEventFormSectionDetails,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      label: AppStrings.adminEventFormTitleLabel,
                      hint: AppStrings.adminEventFormTitleHint,
                      errorText: _errors[_EventField.title],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearError(_EventField.title),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _descriptionController,
                      enabled: !_isSaving,
                      label: AppStrings.adminEventFormDescriptionLabel,
                      hint: AppStrings.adminEventFormDescriptionHint,
                      errorText: _errors[_EventField.description],
                      maxLines: 4,
                      onChanged: (_) => _clearError(_EventField.description),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _locationController,
                      enabled: !_isSaving,
                      label: AppStrings.adminEventFormLocationLabel,
                      hint: AppStrings.adminEventFormLocationHint,
                      prefixIcon: Icons.place_outlined,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      errorText: _errors[_EventField.location],
                      onChanged: (_) => _clearError(_EventField.location),
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
                      AppStrings.adminEventFormSectionSchedule,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PickerField(
                      fieldKey: const ValueKey<String>(
                        'admin-event-date-field',
                      ),
                      icon: Icons.calendar_today_outlined,
                      label: AppStrings.adminEventFormDateLabel,
                      value: AppDateFormatter.date(_startAt),
                      enabled: !_isSaving,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PickerField(
                      fieldKey: const ValueKey<String>(
                        'admin-event-time-field',
                      ),
                      icon: Icons.schedule_outlined,
                      label: AppStrings.adminEventFormTimeLabel,
                      value: AppDateFormatter.time(_startAt),
                      enabled: !_isSaving,
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                key: const ValueKey<String>('admin-event-save'),
                label: _isSaving
                    ? AppStrings.adminEventFormSaving
                    : AppStrings.adminEventFormSave,
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

/// Kolom tanggal atau jam yang membuka pemilih di lembar bawah.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.fieldKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final Key fieldKey;
  final IconData icon;
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label: $value',
      child: Material(
        key: fieldKey,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.allMedium,
          side: BorderSide(color: extras.inputBorder),
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
    );
  }
}

/// Pemilih kalender sederhana berbahasa Indonesia untuk jadwal kegiatan.
///
/// Dibuat sendiri agar nama bulan dan hari memakai locale `id_ID` tanpa
/// menambah paket lokalisasi, mengikuti pemilih tanggal laporan (T-073).
class _EventDatePickerSheet extends StatefulWidget {
  const _EventDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_EventDatePickerSheet> createState() => _EventDatePickerSheetState();
}

class _EventDatePickerSheetState extends State<_EventDatePickerSheet> {
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
                  AppStrings.adminEventDatePickerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey<String>(
                        'admin-event-date-picker-prev',
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
                      key: const ValueKey<String>(
                        'admin-event-date-picker-next',
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
                      key: const ValueKey<String>(
                        'admin-event-date-picker-cancel',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.datePickerCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        key: const ValueKey<String>(
                          'admin-event-date-picker-confirm',
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

/// Pemilih jam kegiatan dengan daftar jam dan menit 24 jam.
class _EventTimePickerSheet extends StatefulWidget {
  const _EventTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_EventTimePickerSheet> createState() => _EventTimePickerSheetState();
}

class _EventTimePickerSheetState extends State<_EventTimePickerSheet> {
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
  }

  void _confirm() {
    Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

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
                  AppStrings.adminEventTimePickerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TimeDropdown(
                        dropdownKey: const ValueKey<String>(
                          'admin-event-hour-dropdown',
                        ),
                        label: AppStrings.adminEventFormHourLabel,
                        value: _hour,
                        values: List<int>.generate(24, (int index) => index),
                        onChanged: (int value) {
                          setState(() => _hour = value);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TimeDropdown(
                        dropdownKey: const ValueKey<String>(
                          'admin-event-minute-dropdown',
                        ),
                        label: AppStrings.adminEventFormMinuteLabel,
                        value: _minute,
                        values: List<int>.generate(60, (int index) => index),
                        onChanged: (int value) {
                          setState(() => _minute = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    TextButton(
                      key: const ValueKey<String>(
                        'admin-event-time-picker-cancel',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.datePickerCancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        key: const ValueKey<String>(
                          'admin-event-time-picker-confirm',
                        ),
                        label: AppStrings.timePickerSave,
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

/// Satu daftar pilihan angka jam atau menit.
class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.dropdownKey,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: dropdownKey,
          value: value,
          isDense: true,
          isExpanded: true,
          items: values
              .map(
                (int item) => DropdownMenuItem<int>(
                  value: item,
                  child: Text(item.toString().padLeft(2, '0')),
                ),
              )
              .toList(growable: false),
          onChanged: (int? selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
        ),
      ),
    );
  }
}

/// Satu tanggal pada kalender pemilih.
class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.selected,
    required this.onTap,
  });

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
          'admin-event-day-${date.year}-${date.month}-${date.day}',
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
