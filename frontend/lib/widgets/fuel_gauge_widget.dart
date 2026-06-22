import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

class FuelGauge extends StatefulWidget {
  final double currentL;
  final double capacityL;
  final double? width;

  const FuelGauge({
    super.key,
    required this.currentL,
    required this.capacityL,
    this.width,
  });

  @override
  State<FuelGauge> createState() => _FuelGaugeState();
}

class _FuelGaugeState extends State<FuelGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: _percent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  double get _percent =>
      widget.capacityL > 0
          ? (widget.currentL / widget.capacityL).clamp(0.0, 1.0)
          : 0;

  Color get _barColor {
    if (_percent > 0.5) return AppConstants.fuelGood;
    if (_percent > 0.2) return AppConstants.fuelWarning;
    return AppConstants.fuelCritical;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.currentL.toStringAsFixed(1)}L / ${widget.capacityL.toStringAsFixed(0)}L',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppConstants.mediumText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_percent * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _animation.value,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
