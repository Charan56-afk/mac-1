import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'utils.dart';

class QRPaymentScreen extends StatefulWidget {
  final String userId;
  final String amount;

  const QRPaymentScreen({
    super.key,
    required this.userId,
    required this.amount,
  });

  @override
  State<QRPaymentScreen> createState() => _QRPaymentScreenState();
}

class _QRPaymentScreenState extends State<QRPaymentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late TextEditingController _txController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _txController = TextEditingController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _txController.dispose();
    super.dispose();
  }

  Future<void> _verifyPayment() async {
    setState(() => _isProcessing = true);

    // Simulate payment processing delay
    await Future.delayed(const Duration(seconds: 3));

    final String transactionId = _txController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/verify'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": widget.userId,
          "transactionId": transactionId,
          "amount": widget.amount,
        }),
      );

      if (response.statusCode == 200) {
        // Persist verification status locally
        await CacheUtility.setUserVerified(true);

        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        throw Exception('Verification failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Server busy. Please try again later."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF00F0FF), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Color(0xFF00F0FF), size: 100),
              const SizedBox(height: 24),
              Text(
                "VERIFIED",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Welcome to CineSocial Blue",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(
                    context,
                    true,
                  ); // Return to profile with success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "AWESOME",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              const Color(0xFF00F0FF).withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildQRContainer(),
                      const SizedBox(height: 40),
                      _buildInstructions(),
                      const SizedBox(height: 30),
                      _buildTransactionInput(),
                      const SizedBox(height: 40),
                      _buildVerifyButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            "SECURE PAYMENT",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balancing back button
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          "SCAN & PAY",
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "FOR ",
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
            ),
            Text(
              "₹${widget.amount}",
              style: GoogleFonts.outfit(
                color: const Color(0xFF00F0FF),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRContainer() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 280,
          height: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(
                0xFF00F0FF,
              ).withValues(alpha: 0.3 + (_controller.value * 0.4)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF00F0FF,
                ).withValues(alpha: 0.1 * _controller.value),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Real QR Code from Assets
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/payment_qr.jpg',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                ),
              ),
              // Scanning Line Animation
              Positioned(
                top: _controller.value * 240,
                child: Container(
                  width: 240,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildStep(1, "Take a screenshot of this QR"),
          const SizedBox(height: 12),
          _buildStep(2, "Open your preferred UPI app"),
          const SizedBox(height: 12),
          _buildStep(3, "Select QR from gallery and pay"),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF00F0FF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              "$num",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ENTER TRANSACTION ID",
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _txController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "e.g. T2403011805...",
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
              suffixIcon: Icon(
                Icons.receipt_long,
                color: const Color(0xFF00F0FF).withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _verifyPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00F0FF),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.5),
        ),
        child: _isProcessing
            ? const CircularProgressIndicator(color: Colors.black)
            : Text(
                "I'VE PAID, VERIFY ME",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }
}

