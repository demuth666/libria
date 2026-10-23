/// Status mesin timer sesi membaca.
enum SessionTimerState { idle, running, paused, targetReached, finished }

/// Mesin timer sesi membaca yang dihitung dari cap waktu.
///
/// Mesin ini tidak bergantung pada Flutter dan tidak memakai penghitung detik
/// di memori. Durasi selalu dihitung ulang dari waktu mulai, waktu sekarang,
/// dan akumulasi jeda, sehingga tetap akurat setelah layar mati atau aplikasi
/// dimatikan sistem (FR-S4).
///
/// Objek bersifat immutable: setiap transisi mengembalikan mesin baru.
class SessionTimerEngine {
  SessionTimerEngine._({
    required this.target,
    required this._status,
    required this._clock,
    this._startedAt,
    this._accumulatedPause = Duration.zero,
    this._pausedAt,
    this._finishedAt,
  });

  /// Membuat mesin yang belum dimulai dengan target durasi [target].
  factory SessionTimerEngine.idle({
    required Duration target,
    DateTime Function()? clock,
  }) {
    return SessionTimerEngine._(
      target: target,
      status: SessionTimerState.idle,
      clock: clock ?? DateTime.now,
    );
  }

  /// Memulihkan mesin dari hasil [toMap].
  ///
  /// Nilai yang tidak dikenal dianggap [SessionTimerState.idle] agar data
  /// tersimpan yang rusak tidak membuat aplikasi gagal dibuka.
  factory SessionTimerEngine.fromMap(
    Map<String, dynamic> map, {
    DateTime Function()? clock,
  }) {
    final int targetSeconds = (map['targetSeconds'] as num?)?.toInt() ?? 0;
    final String? stateName = map['state'] as String?;

    return SessionTimerEngine._(
      target: Duration(seconds: targetSeconds < 0 ? 0 : targetSeconds),
      status: SessionTimerState.values.firstWhere(
        (SessionTimerState value) => value.name == stateName,
        orElse: () => SessionTimerState.idle,
      ),
      clock: clock ?? DateTime.now,
      startedAt: _dateFromMilliseconds(map['startedAtMs']),
      accumulatedPause: _durationFromMilliseconds(map['accumulatedPauseMs']),
      pausedAt: _dateFromMilliseconds(map['pausedAtMs']),
      finishedAt: _dateFromMilliseconds(map['finishedAtMs']),
    );
  }

  /// Target durasi sesi.
  final Duration target;

  final DateTime Function() _clock;
  final SessionTimerState _status;
  final DateTime? _startedAt;
  final Duration _accumulatedPause;
  final DateTime? _pausedAt;
  final DateTime? _finishedAt;

  /// Status saat ini.
  ///
  /// Status [SessionTimerState.targetReached] juga muncul otomatis saat
  /// durasi berjalan sudah menyentuh target, tanpa perlu penghitung detik.
  SessionTimerState get state => _stateAt(_clock());

  /// Waktu sesi dimulai, atau `null` bila belum dimulai.
  DateTime? get startedAt => _startedAt;

  /// Waktu sesi berakhir karena target tercapai atau diselesaikan.
  DateTime? get endedAt {
    switch (state) {
      case SessionTimerState.targetReached:
        return _targetReachedAt;
      case SessionTimerState.finished:
        return _finishedAt;
      case SessionTimerState.idle:
      case SessionTimerState.running:
      case SessionTimerState.paused:
        return null;
    }
  }

  /// Durasi aktif tanpa menghitung jeda.
  ///
  /// Saat target tercapai atau sesi selesai setelah target, nilai dibatasi ke
  /// [target] agar timer berhenti tepat pada nilai target (FR-S6).
  Duration get elapsed => _elapsedAt(_clock());

  /// Progres menuju target dalam rentang 0..1.
  double get progress {
    if (state == SessionTimerState.idle) {
      return 0;
    }
    if (target <= Duration.zero) {
      return 1;
    }
    return (elapsed.inMicroseconds / target.inMicroseconds).clamp(0.0, 1.0);
  }

  /// Memulai sesi dari status idle.
  SessionTimerEngine start() {
    if (_status != SessionTimerState.idle) {
      return this;
    }
    return SessionTimerEngine._(
      target: target,
      status: SessionTimerState.running,
      clock: _clock,
      startedAt: _clock(),
    );
  }

  /// Menghentikan sementara perhitungan durasi.
  SessionTimerEngine pause() {
    final DateTime now = _clock();
    if (_stateAt(now) != SessionTimerState.running) {
      return this;
    }
    return SessionTimerEngine._(
      target: target,
      status: SessionTimerState.paused,
      clock: _clock,
      startedAt: _startedAt,
      accumulatedPause: _accumulatedPause,
      pausedAt: now,
    );
  }

  /// Melanjutkan sesi yang sedang dijeda.
  SessionTimerEngine resume() {
    final DateTime now = _clock();
    if (_stateAt(now) != SessionTimerState.paused) {
      return this;
    }
    final DateTime? pausedAt = _pausedAt;
    final Duration pauseDuration = pausedAt == null
        ? Duration.zero
        : _nonNegative(now.difference(pausedAt));

    return SessionTimerEngine._(
      target: target,
      status: SessionTimerState.running,
      clock: _clock,
      startedAt: _startedAt,
      accumulatedPause: _accumulatedPause + pauseDuration,
    );
  }

  /// Menyelesaikan sesi. Bila target sudah tercapai, durasi berhenti pada
  /// nilai target.
  SessionTimerEngine finish() {
    final DateTime now = _clock();
    final SessionTimerState current = _stateAt(now);
    if (current == SessionTimerState.idle ||
        current == SessionTimerState.finished) {
      return this;
    }

    if (current == SessionTimerState.targetReached) {
      return SessionTimerEngine._(
        target: target,
        status: SessionTimerState.finished,
        clock: _clock,
        startedAt: _startedAt,
        accumulatedPause: _accumulatedPause,
        finishedAt: _targetReachedAt ?? now,
      );
    }

    Duration accumulatedPause = _accumulatedPause;
    final DateTime? pausedAt = _pausedAt;
    if (current == SessionTimerState.paused && pausedAt != null) {
      accumulatedPause += _nonNegative(now.difference(pausedAt));
    }

    return SessionTimerEngine._(
      target: target,
      status: SessionTimerState.finished,
      clock: _clock,
      startedAt: _startedAt,
      accumulatedPause: accumulatedPause,
      finishedAt: now,
    );
  }

  /// Bentuk map yang aman disimpan ke penyimpanan lokal.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'state': state.name,
      'targetSeconds': target.inSeconds,
      'startedAtMs': _startedAt?.millisecondsSinceEpoch,
      'accumulatedPauseMs': _accumulatedPause.inMilliseconds,
      'pausedAtMs': _pausedAt?.millisecondsSinceEpoch,
      'finishedAtMs': _finishedAt?.millisecondsSinceEpoch,
    };
  }

  DateTime? get _targetReachedAt {
    final DateTime? start = _startedAt;
    if (start == null) {
      return null;
    }
    if (target <= Duration.zero) {
      return start;
    }
    return start.add(_accumulatedPause + target);
  }

  SessionTimerState _stateAt(DateTime now) {
    if (_status == SessionTimerState.running ||
        _status == SessionTimerState.paused) {
      if (target <= Duration.zero || _rawElapsedAt(now) >= target) {
        return SessionTimerState.targetReached;
      }
    }
    return _status;
  }

  Duration _elapsedAt(DateTime now) {
    switch (_status) {
      case SessionTimerState.idle:
        return Duration.zero;
      case SessionTimerState.targetReached:
        return target < Duration.zero ? Duration.zero : target;
      case SessionTimerState.running:
      case SessionTimerState.paused:
      case SessionTimerState.finished:
        final Duration raw = _rawElapsedAt(now);
        if (target > Duration.zero && raw > target) {
          return target;
        }
        return raw;
    }
  }

  Duration _rawElapsedAt(DateTime now) {
    final DateTime? start = _startedAt;
    if (start == null) {
      return Duration.zero;
    }

    switch (_status) {
      case SessionTimerState.idle:
        return Duration.zero;
      case SessionTimerState.running:
        return _nonNegative(now.difference(start) - _accumulatedPause);
      case SessionTimerState.paused:
        final DateTime anchor = _pausedAt ?? start;
        return _nonNegative(anchor.difference(start) - _accumulatedPause);
      case SessionTimerState.targetReached:
        return target < Duration.zero ? Duration.zero : target;
      case SessionTimerState.finished:
        final DateTime? finishedAt = _finishedAt;
        if (finishedAt == null) {
          return Duration.zero;
        }
        return _nonNegative(finishedAt.difference(start) - _accumulatedPause);
    }
  }

  static Duration _nonNegative(Duration value) {
    return value.isNegative ? Duration.zero : value;
  }

  static DateTime? _dateFromMilliseconds(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  static Duration _durationFromMilliseconds(Object? value) {
    if (value is num) {
      final int milliseconds = value.toInt();
      return Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
    }
    return Duration.zero;
  }
}
