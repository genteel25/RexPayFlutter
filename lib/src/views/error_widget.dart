import 'package:flutter/material.dart';
import 'package:rexpay/src/core/common/utils.dart';
import 'package:rexpay/src/core/constants/colors.dart';
import 'package:rexpay/src/views/animated_widget.dart';
import 'package:rexpay/src/views/common/extensions.dart';

class ErrorWidget extends StatefulWidget {
  final String message;
  final VoidCallback onCountdownComplete;

  ErrorWidget({required this.message, required this.onCountdownComplete});

  @override
  _SuccessfulWidgetState createState() {
    return _SuccessfulWidgetState();
  }
}

class _SuccessfulWidgetState extends State<ErrorWidget>
    with TickerProviderStateMixin {
  final sizedBox = const SizedBox(height: 20.0);
  late AnimationController _mainController;
  late AnimationController _opacityController;
  late Animation<double> _opacity;

  static const int kStartValue = 60;
  late AnimationController _countdownController;
  late Animation _countdownAnim;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _mainController.forward();

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: kStartValue),
    );
    _countdownController.addListener(() => setState(() {}));
    _countdownAnim =
        StepTween(begin: kStartValue, end: 0).animate(_countdownController);

    _opacityController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = CurvedAnimation(parent: _opacityController, curve: Curves.linear)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _opacityController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _opacityController.forward();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  @override
  void dispose() {
    _mainController.dispose();
    _countdownController.dispose();
    _opacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sceondaryColor = context.colorScheme().secondary;
    return Container(
      child: CustomAnimatedWidget(
        controller: _mainController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            sizedBox,
            Icon(Icons.cancel_outlined, color: AppColors.red, size: 60),
            sizedBox,
            const Text(
              'Payment Failed',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(
              height: 5.0,
            ),
            Text(widget.message,
                style: TextStyle(
                  color: context.textTheme().headlineSmall?.color,
                  fontWeight: FontWeight.normal,
                  fontSize: 14.0,
                )),
            sizedBox,
            FadeTransition(
              opacity: _opacity,
              child: Text(
                _countdownAnim.value.toString(),
                style: TextStyle(
                    color: sceondaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 25.0),
              ),
            ),
            const SizedBox(
              height: 30.0,
            )
          ],
        ),
      ),
    );
  }

  void _startCountdown() {
    if (_countdownController.isAnimating ||
        _countdownController.isCompleted ||
        !mounted) {
      return;
    }
    _countdownController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onCountdownComplete();
      }
    });
    _countdownController.forward();
    _opacityController.forward();
  }
}
