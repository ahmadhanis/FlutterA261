import 'dart:async';

import 'package:flutter/material.dart';

import 'loginscreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _introController.forward();
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700;
    final horizontalPadding = size.width < 360 ? 24.0 : 32.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: FadeTransition(
                opacity: _fadeIn,
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    _BrandMark(size: compact ? 96 : 112),
                    SizedBox(height: compact ? 24 : 30),
                    const Text(
                      'Budget Plus',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF172A25),
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A clearer view of your money.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF65736E),
                        fontSize: size.width < 360 ? 15 : 16,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(flex: 2),
                    const _LoadingIndicator(),
                    SizedBox(height: compact ? 28 : 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE2F1EB),
        borderRadius: BorderRadius.circular(size * .31),
      ),
      child: Center(
        child: Container(
          width: size * .60,
          height: size * .60,
          decoration: BoxDecoration(
            color: const Color(0xFF147D64),
            borderRadius: BorderRadius.circular(size * .19),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33147D64),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: size * .32,
          ),
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF147D64),
          ),
        ),
        SizedBox(width: 10),
        Text(
          'Getting things ready',
          style: TextStyle(
            color: Color(0xFF65736E),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
