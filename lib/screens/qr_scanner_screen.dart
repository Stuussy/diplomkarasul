import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _hasDetected = false;
  final MobileScannerController _controller = MobileScannerController();
  String? _error;

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
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) =>
                _CameraErrorWidget(
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
      ),
    );
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
