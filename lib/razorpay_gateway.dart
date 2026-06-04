import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class RazorpayPaymentScreen extends StatefulWidget {
  final String amount;
  const RazorpayPaymentScreen({super.key, required this.amount});

  @override
  State<RazorpayPaymentScreen> createState() => _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState extends State<RazorpayPaymentScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isWebViewSupported = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  void _checkSupport() {
    // WebView is supported on Android & iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isWebViewSupported = true;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() => _isLoading = true);
            },
            onPageFinished: (String url) {
              setState(() => _isLoading = false);
              if (url.contains('paymentsuccess') ||
                  url.contains('success=true')) {
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted) Navigator.pop(context, true);
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView Error: ${error.description}');
            },
          ),
        )
        ..loadRequest(
          Uri.parse('https://razorpay.com/demo/?amount=${widget.amount}'),
        );
    } else {
      _isWebViewSupported = false;
      _isLoading = false;
    }
  }

  Future<void> _launchInBrowser() async {
    final url = Uri.parse('https://razorpay.com/demo/?amount=${widget.amount}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch payment page')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: Text(
          "CineSocial Pay",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        elevation: 0,
      ),
      body: _isWebViewSupported ? _buildWebView() : _buildBrowserFallback(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF00F0FF)),
          ),
      ],
    );
  }

  Widget _buildBrowserFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.language,
                color: Color(0xFF00F0FF),
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Complete Payment in Browser",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "To ensure a secure transaction on this platform, please complete your payment in your default web browser.",
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _launchInBrowser,
                icon: const Icon(Icons.open_in_new),
                label: const Text("Open Payment Page"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ), // Simulating success for testing
              child: Text(
                "I have completed the payment",
                style: GoogleFonts.outfit(
                  color: const Color(0xFF00F0FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

