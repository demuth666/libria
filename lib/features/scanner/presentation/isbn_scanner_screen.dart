import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/content_width.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../books/data/book.dart';
import '../data/isbn_scan_service.dart';

/// Membangun pratinjau kamera pemindai.
///
/// Parameter [onDetected] harus dipanggil dengan nilai barcode mentah. Builder
/// ini opsional dan dipakai uji widget agar tidak membutuhkan kamera asli.
typedef IsbnScannerPreviewBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onDetected,
);

/// Layar pemindai ISBN pada rute `/scan` (FR-L5, T-044).
///
/// Alur:
/// - barcode EAN-13 yang terbaca divalidasi dan dicari ke katalog;
/// - bila buku ada, [onBookFound] dipanggil. Bila tidak diisi, layar ditutup
///   dengan `Book` sebagai hasil `context.pop<Book>(book)`;
/// - bila buku tidak ada, pesan "Buku dengan ISBN ... tidak ditemukan"
///   ditampilkan dan `IsbnLogRepository.record` mencatat ISBN tersebut;
/// - bila barcode bukan ISBN, tidak ada log yang dicatat.
///
/// Alur sesi membaca (T-052) dapat memakai layar ini tanpa [onBookFound] dan
/// menunggu hasil `Book` dari navigasi, sedangkan rute `/scan` mengisi
/// [onBookFound] untuk membuka detail buku.
class IsbnScannerScreen extends ConsumerStatefulWidget {
  const IsbnScannerScreen({this.onBookFound, this.scannerBuilder, super.key});

  /// Aksi setelah buku ditemukan. Bila `null`, layar ditutup dengan buku
  /// sebagai hasil navigasi.
  final ValueChanged<Book>? onBookFound;

  /// Pengganti pratinjau kamera; hanya dipakai uji widget.
  final IsbnScannerPreviewBuilder? scannerBuilder;

  @override
  ConsumerState<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends ConsumerState<IsbnScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  IsbnScanResult? _result;
  MobileScannerErrorCode? _cameraErrorCode;
  TorchState? _torchState;
  String _activeIsbn = '';
  bool _isSearching = false;
  bool _isHandling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.scannerBuilder == null) {
      _controller = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.ean13],
      )..addListener(_handleControllerState);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final MobileScannerController? controller = _controller;
    if (controller != null) {
      controller.removeListener(_handleControllerState);
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isHandling && !_isSearching && _result == null) {
          unawaited(_startCamera());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_stopCamera());
    }
  }

  void _handleControllerState() {
    final MobileScannerController? controller = _controller;
    final MobileScannerErrorCode? code = controller?.value.error?.errorCode;
    final TorchState? torchState = controller?.value.torchState;
    if (!mounted || (code == _cameraErrorCode && torchState == _torchState)) {
      return;
    }
    setState(() {
      _cameraErrorCode = code;
      _torchState = torchState;
    });
  }

  Future<void> _startCamera() async {
    final MobileScannerController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      if (!controller.value.isRunning && !controller.value.isStarting) {
        await controller.start();
      }
    } on Exception {
      // Keadaan galat kamera ditampilkan lewat errorBuilder/panel bawah.
    }
  }

  Future<void> _stopCamera() async {
    final MobileScannerController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.stop();
    } on Exception {
      // Kamera mungkin belum terpasang atau sudah berhenti.
    }
  }

  Future<void> _toggleTorch() async {
    final MobileScannerController? controller = _controller;
    if (controller == null) {
      return;
    }
    try {
      await controller.toggleTorch();
    } on Exception {
      // Lampu tidak tersedia pada perangkat ini.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandling || _isSearching || _result != null) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue ?? barcode.displayValue;
      if (value != null && value.trim().isNotEmpty) {
        _lookup(value);
        return;
      }
    }
  }

  Future<void> _lookup(String rawValue) async {
    if (_isHandling) {
      return;
    }
    final String normalized = rawValue.trim();
    setState(() {
      _isHandling = true;
      _isSearching = true;
      _activeIsbn = normalized;
      _result = null;
    });
    unawaited(_stopCamera());

    final IsbnScanResult result = await ref
        .read(isbnScanServiceProvider)
        .scan(rawValue);
    if (!mounted) {
      return;
    }

    final Book? book = result.book;
    if (result.isFound && book != null) {
      setState(() {
        _isHandling = false;
        _isSearching = false;
      });
      _complete(book);
      return;
    }

    setState(() {
      _isHandling = false;
      _isSearching = false;
      _result = result;
      _activeIsbn = result.isbn.isEmpty ? normalized : result.isbn;
    });
  }

  void _complete(Book book) {
    final ValueChanged<Book>? onBookFound = widget.onBookFound;
    if (onBookFound != null) {
      onBookFound(book);
      return;
    }
    if (context.canPop()) {
      context.pop<Book>(book);
      return;
    }
    context.pushReplacement(AppRoutes.bookDetailPath(book.id));
  }

  void _rescan() {
    setState(() {
      _isHandling = false;
      _isSearching = false;
      _result = null;
      _activeIsbn = '';
    });
    unawaited(_startCamera());
  }

  void _retryCamera() {
    unawaited(_startCamera());
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double horizontalPadding =
        Breakpoints.of(context) == ScreenSize.compact
        ? AppSpacing.screenMargin
        : AppSpacing.lg;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: AppStrings.isbnScanTitle,
            leading: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey<String>('isbn-scan-back'),
                tooltip: AppStrings.isbnScanBack,
                padding: EdgeInsets.zero,
                onPressed: _close,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            actions: [
              if (_canToggleTorch)
                IconButton(
                  key: const ValueKey<String>('isbn-scan-torch'),
                  tooltip: _isTorchOn
                      ? AppStrings.isbnScanTorchOff
                      : AppStrings.isbnScanTorchOn,
                  onPressed: _toggleTorch,
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ContentWidth(
                maxWidth: 720,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    AppSpacing.md,
                    horizontalPadding,
                    AppSpacing.lg,
                  ),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return Stack(
                            children: [
                              Positioned.fill(child: _buildCamera(context)),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _buildBottomPanel(
                                  context,
                                  maxHeight: constraints.maxHeight * 0.82,
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _cameraFailed => _cameraErrorCode != null;

  bool get _isTorchOn => _torchState == TorchState.on;

  bool get _canToggleTorch {
    final MobileScannerController? controller = _controller;
    if (controller == null || _cameraFailed || _result != null) {
      return false;
    }
    return _torchState != null && _torchState != TorchState.unavailable;
  }

  Widget _buildCamera(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    final Widget preview =
        widget.scannerBuilder?.call(context, _lookup) ??
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          useAppLifecycleState: false,
          errorBuilder: (BuildContext context, MobileScannerException error) =>
              _CameraPlaceholder(
                icon: Icons.videocam_off_outlined,
                message: AppStrings.isbnScanCameraErrorTitle,
              ),
          placeholderBuilder: (BuildContext context) =>
              const _CameraPlaceholder(
                icon: Icons.photo_camera_outlined,
                message: AppStrings.isbnScanPreparingCamera,
              ),
        );

    final bool showScanWindow =
        !_cameraFailed && !_isSearching && _result == null;

    return ClipRRect(
      borderRadius: AppRadius.allLarge,
      child: ColoredBox(
        color: scheme.shadow,
        child: Stack(
          fit: StackFit.expand,
          children: [
            preview,
            if (showScanWindow)
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScanWindowPainter(
                    maskColor: extras.scrim,
                    frameColor: scheme.secondary,
                  ),
                ),
              ),
            if (_isSearching)
              ColoredBox(
                color: extras.scrim,
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.level1,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, {required double maxHeight}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _ScannerPanel(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _buildPanelContent(context),
        ),
      ),
    );
  }

  Widget _buildPanelContent(BuildContext context) {
    final MobileScannerErrorCode? cameraError = _cameraErrorCode;
    if (cameraError != null) {
      return _CameraErrorContent(
        errorCode: cameraError,
        onRetry: _retryCamera,
        onClose: _close,
      );
    }

    if (_isSearching) {
      return _PanelStatusContent(
        icon: Icons.manage_search,
        title: AppStrings.isbnScanSearchingTitle,
        message: AppStrings.isbnScanSearchingMessage(_activeIsbn),
      );
    }

    final IsbnScanResult? result = _result;
    if (result != null) {
      return _ResultContent(result: result, onRescan: _rescan, onClose: _close);
    }

    return const _PanelStatusContent(
      icon: Icons.qr_code_scanner,
      title: AppStrings.isbnScanHintTitle,
      message: AppStrings.isbnScanHintMessage,
    );
  }
}

/// Panel permukaan yang menempel di bagian bawah pratinjau kamera.
class _ScannerPanel extends StatelessWidget {
  const _ScannerPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors extras = theme.extension<AppSemanticColors>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.allLarge,
        border: Border.all(color: extras.cardBorder),
        boxShadow: AppShadows.level1,
      ),
      child: ClipRRect(borderRadius: AppRadius.allLarge, child: child),
    );
  }
}

/// Isi panel untuk petunjuk, proses pencarian, atau hasil pemindaian.
class _PanelStatusContent extends StatelessWidget {
  const _PanelStatusContent({
    required this.icon,
    required this.title,
    required this.message,
    this.statusIcon,
    this.statusText,
    this.statusColor,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String message;
  final IconData? statusIcon;
  final String? statusText;
  final Color? statusColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (statusText != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                statusIcon ?? Icons.info_outline,
                size: 18,
                color: statusColor ?? scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  statusText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor ?? scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (int index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: actions[index]),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Isi panel setelah ISBN tidak ditemukan, tidak valid, atau pencarian gagal.
class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.result,
    required this.onRescan,
    required this.onClose,
  });

  final IsbnScanResult result;
  final VoidCallback onRescan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (result.isNotFound) {
      final String? logError = result.logError;
      return _PanelStatusContent(
        icon: Icons.search_off_rounded,
        title: AppStrings.isbnScanNotFoundTitle,
        message: result.message ?? '',
        statusIcon: logError == null
            ? Icons.check_circle_outline
            : Icons.error_outline,
        statusText: logError ?? AppStrings.isbnScanLogRecorded,
        statusColor: logError == null ? scheme.secondary : scheme.error,
        actions: <Widget>[
          SecondaryButton(label: AppStrings.isbnScanClose, onPressed: onClose),
          PrimaryButton(
            label: AppStrings.isbnScanAgain,
            icon: Icons.qr_code_scanner,
            onPressed: onRescan,
          ),
        ],
      );
    }

    if (result.status == IsbnScanStatus.invalid) {
      return _PanelStatusContent(
        icon: Icons.qr_code_2,
        title: AppStrings.isbnScanInvalidTitle,
        message: result.message ?? '',
        actions: <Widget>[
          SecondaryButton(label: AppStrings.isbnScanClose, onPressed: onClose),
          PrimaryButton(
            label: AppStrings.isbnScanAgain,
            icon: Icons.qr_code_scanner,
            onPressed: onRescan,
          ),
        ],
      );
    }

    return _PanelStatusContent(
      icon: Icons.cloud_off_outlined,
      title: AppStrings.isbnScanErrorTitle,
      message: result.message ?? AppStrings.isbnScanLookupError,
      actions: <Widget>[
        SecondaryButton(label: AppStrings.isbnScanClose, onPressed: onClose),
        PrimaryButton(
          label: AppStrings.retry,
          icon: Icons.refresh,
          onPressed: onRescan,
        ),
      ],
    );
  }
}

/// Isi panel saat kamera tidak dapat dipakai.
class _CameraErrorContent extends StatelessWidget {
  const _CameraErrorContent({
    required this.errorCode,
    required this.onRetry,
    required this.onClose,
  });

  final MobileScannerErrorCode errorCode;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    switch (errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return _PanelStatusContent(
          icon: Icons.no_photography_outlined,
          title: AppStrings.isbnScanPermissionDeniedTitle,
          message: AppStrings.isbnScanPermissionDeniedMessage,
          actions: <Widget>[
            SecondaryButton(
              label: AppStrings.isbnScanClose,
              onPressed: onClose,
            ),
            PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        );
      case MobileScannerErrorCode.unsupported:
        return _PanelStatusContent(
          icon: Icons.videocam_off_outlined,
          title: AppStrings.isbnScanCameraUnsupportedTitle,
          message: AppStrings.isbnScanCameraUnsupportedMessage,
          actions: <Widget>[
            PrimaryButton(label: AppStrings.isbnScanClose, onPressed: onClose),
          ],
        );
      default:
        return _PanelStatusContent(
          icon: Icons.videocam_off_outlined,
          title: AppStrings.isbnScanCameraErrorTitle,
          message: AppStrings.isbnScanCameraErrorMessage,
          actions: <Widget>[
            SecondaryButton(
              label: AppStrings.isbnScanClose,
              onPressed: onClose,
            ),
            PrimaryButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        );
    }
  }
}

/// Kartu statis di atas pratinjau saat kamera belum siap atau gagal.
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return ColoredBox(
      color: scheme.shadow,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: AppRadius.allMedium,
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bingkai pemindaian dan lapisan gelap di luar bingkai.
class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({required this.maskColor, required this.frameColor});

  final Color maskColor;
  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double frameWidth = (size.width - AppSpacing.xl * 2).clamp(160, 320);
    final double frameHeight = frameWidth * 0.52;
    final Offset center = Offset(
      size.width / 2,
      size.height < 320 ? size.height * 0.36 : size.height * 0.42,
    );
    final Rect frame = Rect.fromCenter(
      center: center,
      width: frameWidth,
      height: frameHeight,
    );
    final RRect frameRRect = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(AppRadius.large),
    );

    final Path mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frameRRect);
    canvas.drawPath(mask, Paint()..color = maskColor);

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSpacing.xs / 2
      ..color = frameColor;
    canvas.drawRRect(frameRRect, borderPaint);

    final Paint cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSpacing.xs
      ..strokeCap = StrokeCap.round
      ..color = frameColor;
    const double cornerLength = AppSpacing.lg;
    final double left = frame.left;
    final double right = frame.right;
    final double top = frame.top;
    final double bottom = frame.bottom;

    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) {
    return oldDelegate.maskColor != maskColor ||
        oldDelegate.frameColor != frameColor;
  }
}
