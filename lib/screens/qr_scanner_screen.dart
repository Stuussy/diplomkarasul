import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/clinic_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _hasDetected = false;
  final MobileScannerController _controller = MobileScannerController();
  String? _error;
  late Future<bool> _permissionFuture;
  bool _permissionPermanentlyDenied = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _permissionFuture = _requestPermission();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final code = barcode?.rawValue;
    if (code == null) return;
    if (!mounted) return;
    setState(() => _hasDetected = true);
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClinicTheme.radiusL),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ClinicTheme.mintSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle, color: ClinicTheme.mint, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'QR найден',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(code);
              },
              child: const Text('Подтвердить'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClinicTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Сканер QR'),
      ),
      body: FutureBuilder<bool>(
        future: _permissionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ClinicTheme.azure),
            );
          }

          final granted = snapshot.data ?? false;
          if (!granted) {
            return _PermissionWarning(
              onRetry: () async {
                final result = await _requestPermission();
                if (!mounted) return;
                setState(() => _permissionFuture = Future.value(result));
              },
              canOpenSettings: _permissionPermanentlyDenied,
            );
          }

          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) => _CameraErrorWidget(
                  message: error.toString(),
                  onShowMessage: (msg) {
                    if (!mounted) return;
                    setState(() => _error = msg);
                  },
                ),
              ),

              // Viewport overlay
              _buildViewportOverlay(),

              // Bottom instruction
              Positioned(
                left: 20,
                right: 20,
                bottom: 60 + MediaQuery.of(context).padding.bottom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Наведите камеру на QR-код',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),

              if (_error != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 120,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _error != null ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ClinicTheme.coral,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewportOverlay() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: ClinicTheme.azure, width: 2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              // Corner accents
              ..._buildCornerAccents(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerAccents() {
    const length = 30.0;
    const thickness = 3.0;
    const color = ClinicTheme.azure;
    const radius = Radius.circular(24);

    return [
      // Top left
      Positioned(
        top: -1,
        left: -1,
        child: Container(
          width: length,
          height: thickness,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topLeft: radius),
          ),
        ),
      ),
      Positioned(
        top: -1,
        left: -1,
        child: Container(
          width: thickness,
          height: length,
          decoration: const BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(topLeft: radius),
          ),
        ),
      ),
      // Top right
      Positioned(
        top: -1,
        right: -1,
        child: Container(width: length, height: thickness, color: color),
      ),
      Positioned(
        top: -1,
        right: -1,
        child: Container(width: thickness, height: length, color: color),
      ),
      // Bottom left
      Positioned(
        bottom: -1,
        left: -1,
        child: Container(width: length, height: thickness, color: color),
      ),
      Positioned(
        bottom: -1,
        left: -1,
        child: Container(width: thickness, height: length, color: color),
      ),
      // Bottom right
      Positioned(
        bottom: -1,
        right: -1,
        child: Container(width: length, height: thickness, color: color),
      ),
      Positioned(
        bottom: -1,
        right: -1,
        child: Container(width: thickness, height: length, color: color),
      ),
    ];
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) return true;
      if (result.isPermanentlyDenied) {
        if (mounted) setState(() => _permissionPermanentlyDenied = true);
        await openAppSettings();
      }
      return false;
    }
    if (status.isPermanentlyDenied) {
      if (mounted) setState(() => _permissionPermanentlyDenied = true);
      await openAppSettings();
      return false;
    }
    return false;
  }
}

class _CameraErrorWidget extends StatelessWidget {
  const _CameraErrorWidget({required this.message, required this.onShowMessage});

  final String message;
  final ValueChanged<String> onShowMessage;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onShowMessage(message.contains('permission')
          ? 'Нет доступа к камере. Разрешите в настройках.'
          : message);
    });
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.onRetry, this.canOpenSettings = false});

  final VoidCallback onRetry;
  final bool canOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ClinicTheme.azure.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.camera, size: 36, color: ClinicTheme.azure),
            ),
            const SizedBox(height: 20),
            Text(
              'Нужен доступ к камере',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Для сканирования QR-кодов необходимо разрешение камеры.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Разрешить доступ'),
            ),
            if (canOpenSettings) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: openAppSettings,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Открыть настройки'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
