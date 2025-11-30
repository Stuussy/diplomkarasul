import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _hasDetected = false;
  final MobileScannerController _controller = MobileScannerController();
  String? _error;
  late Future<bool> _permissionFuture;
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _permissionFuture = _requestPermission();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    final code = barcode?.rawValue;
    if (code == null) return;
    if (!mounted) return;
    setState(() => _hasDetected = true);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR найден'),
        content: Text(code),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(code);
            },
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сканер QR')),
      body: FutureBuilder<bool>(
        future: _permissionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final granted = snapshot.data ?? false;
          if (!granted) {
            return _PermissionWarning(
              onRetry: () async {
                final result = await _requestPermission();
                if (!mounted) return;
                setState(() {
                  _permissionFuture = Future.value(result);
                });
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
              if (_error != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: Card(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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

  Future<bool> _requestPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        return true;
      }
      if (result.isPermanentlyDenied) {
        if (mounted) {
          setState(() => _permissionPermanentlyDenied = true);
        }
        await openAppSettings();
      }
      return false;
    }
    if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _permissionPermanentlyDenied = true);
      }
      await openAppSettings();
      return false;
    }
    if (status.isRestricted) {
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
          ? 'Нет доступа к камере. Разрешите использование камеры в настройках.'
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Нужен доступ к камере для сканирования QR-кодов.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Разрешить доступ'),
            ),
            if (canOpenSettings) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: openAppSettings,
                child: const Text('Открыть настройки'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
