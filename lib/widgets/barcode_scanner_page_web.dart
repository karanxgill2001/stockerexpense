import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late final MobileScannerController _controller;
  late final TextEditingController _manualController;

  double _zoomScale = 0.2;
  bool _didReturnResult = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.codabar,
        BarcodeFormat.itf14,
      ],
    );
    _manualController = TextEditingController();
    unawaited(_applyZoomScale(_zoomScale));
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _applyZoomScale(double value) async {
    try {
      await _controller.setZoomScale(value);
      if (mounted) {
        setState(() {
          _zoomScale = value;
        });
      }
    } catch (_) {
      // Some browsers do not expose zoom control. Keep scanner running anyway.
    }
  }

  Future<void> _restartScanner() async {
    try {
      await _controller.stop();
      await _controller.start();
      await _applyZoomScale(_zoomScale);
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    }
  }

  void _returnBarcode(String barcode) {
    if (_didReturnResult) {
      return;
    }

    _didReturnResult = true;
    Navigator.of(context).pop(barcode.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Barcode'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      if (_didReturnResult) {
                        return;
                      }

                      final barcode = capture.barcodes.firstOrNull?.rawValue;
                      if (barcode == null || barcode.trim().isEmpty) {
                        return;
                      }

                      _returnBarcode(barcode);
                    },
                    onDetectError: (error, stackTrace) {
                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _errorMessage = error.toString();
                      });
                    },
                    errorBuilder: (context, error) => Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          error.errorDetails?.message ?? 'Camera could not start.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 300,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  if (_errorMessage != null)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Web scanner now uses a browser-tuned camera view. Hold the barcode 10-15 cm away, then use zoom if the lines look soft.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF0B0B0B),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _restartScanner,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3B3B3B)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Restart Camera'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Zoom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF0B7A69),
                      inactiveTrackColor: const Color(0xFF2C2C2C),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _zoomScale,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() {
                          _zoomScale = value;
                        });
                      },
                      onChangeEnd: _applyZoomScale,
                    ),
                  ),
                  const Text(
                    'Manual Barcode Entry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type barcode or SKU',
                      hintStyle: const TextStyle(color: Color(0xFFB7B7B7)),
                      filled: true,
                      fillColor: const Color(0xFF1B1B1B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _returnBarcode(value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final value = _manualController.text.trim();
                      if (value.isNotEmpty) {
                        _returnBarcode(value);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0B4A40),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Use This Barcode'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}