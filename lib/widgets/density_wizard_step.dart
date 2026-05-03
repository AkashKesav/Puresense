import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DensityWizardStep extends StatefulWidget {
  final int stepNumber;
  final String title;
  final String instruction;
  final String buttonLabel;
  final double? recordedValue;
  final bool isCurrent;
  final bool isCompleted;
  final double? currentLiveWeight;
  final double? stability;
  final VoidCallback? onAction;
  final VoidCallback? onReMeasure;

  const DensityWizardStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.buttonLabel,
    this.recordedValue,
    required this.isCurrent,
    required this.isCompleted,
    this.currentLiveWeight,
    this.stability,
    this.onAction,
    this.onReMeasure,
  });

  @override
  State<DensityWizardStep> createState() => _DensityWizardStepState();
}

class _DensityWizardStepState extends State<DensityWizardStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    if (widget.isCurrent) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(DensityWizardStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !oldWidget.isCurrent) {
      _animationController.forward();
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildStepIllustration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _stepColor.withAlpha(15),
            _stepColor.withAlpha(5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _stepColor.withAlpha(40),
          width: 1.5,
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepVisual(),
                  const SizedBox(height: 16),
                  Text(
                    _getStepDescription(),
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(180),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getStepDetail(),
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(120),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepVisual() {
    switch (widget.stepNumber) {
      case 0: // Zero Scale
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF78909C).withAlpha(30),
                const Color(0xFF78909C).withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.scale,
            size: 48,
            color: const Color(0xFF78909C),
          ),
        );
      case 1: // Sample Weight
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFB300).withAlpha(30),
                const Color(0xFFFFB300).withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.science,
                size: 40,
                color: const Color(0xFFFFB300),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case 2: // Water Baseline
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2196F3).withAlpha(30),
                const Color(0xFF2196F3).withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.science_outlined,
                  size: 28,
                  color: const Color(0xFF2196F3),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.water_drop,
                  size: 16,
                  color: const Color(0xFF2196F3).withAlpha(180),
                ),
              ),
            ],
          ),
        );
      case 3: // Submerged Weight
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00BCD4).withAlpha(30),
                const Color(0xFF00BCD4).withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.opacity,
                size: 38,
                color: const Color(0xFF00BCD4),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Icon(
                  Icons.arrow_downward,
                  size: 14,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withAlpha(30),
                const Color(0xFF4CAF50).withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 48,
            color: const Color(0xFF4CAF50),
          ),
        );
    }
  }

  String _getStepDetail() {
    switch (widget.stepNumber) {
      case 0:
        return 'Remove all items from scale';
      case 1:
        return 'Place your metal sample';
      case 2:
        return 'Container with water only';
      case 3:
        return 'Sample fully in water';
      default:
        return 'All steps complete';
    }
  }

  IconData get _stepIcon {
    switch (widget.stepNumber) {
      case 0:
        return Icons.scale;
      case 1:
        return Icons.science;
      case 2:
        return Icons.water_drop;
      case 3:
        return Icons.opacity;
      default:
        return Icons.check_circle;
    }
  }

  Color get _stepColor {
    switch (widget.stepNumber) {
      case 0:
        return const Color(0xFF78909C);  // Silver-grey for scale
      case 1:
        return const Color(0xFFFFB300);  // Gold for sample
      case 2:
        return const Color(0xFF2196F3);  // Blue for water
      case 3:
        return const Color(0xFF00BCD4);  // Cyan for submerged
      default:
        return const Color(0xFF4CAF50);  // Green for complete
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isCurrent
            ? const Color(0xFF222222)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isCurrent
              ? _stepColor.withAlpha(80)
              : widget.isCompleted
                  ? Colors.green.withAlpha(40)
                  : Colors.white.withAlpha(8),
          width: widget.isCurrent ? 2 : 1,
        ),
        boxShadow: widget.isCurrent
            ? [
                BoxShadow(
                  color: _stepColor.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Header (always visible)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Enhanced step indicator with icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isCompleted
                        ? LinearGradient(
                            colors: [
                              Colors.green.withAlpha(25),
                              Colors.green.withAlpha(40)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : widget.isCurrent
                            ? LinearGradient(
                                colors: [
                                  _stepColor.withAlpha(20),
                                  _stepColor.withAlpha(35)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                    color: !widget.isCurrent && !widget.isCompleted
                        ? Colors.white.withAlpha(8)
                        : null,
                    border: Border.all(
                      color: widget.isCompleted
                          ? Colors.green
                          : widget.isCurrent
                              ? _stepColor
                              : Colors.white.withAlpha(30),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: widget.isCompleted
                        ? Icon(Icons.check, size: 20, color: Colors.green)
                        : Icon(
                            _stepIcon,
                            size: 18,
                            color: widget.isCurrent
                                ? _stepColor
                                : Colors.white.withAlpha(100),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isCompleted && widget.recordedValue != null
                            ? 'Step ${widget.stepNumber + 1} — ${widget.title}: ${widget.recordedValue!.toStringAsFixed(2)} g'
                            : widget.isCompleted && widget.stepNumber == 0
                                ? 'Step 1 — Scale zeroed'
                                : widget.title,
                        style: GoogleFonts.inter(
                          color: widget.isCompleted
                              ? Colors.white.withAlpha(180)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.isCompleted && widget.recordedValue != null)
                        Text(
                          'Completed',
                          style: GoogleFonts.inter(
                            color: Colors.green.withAlpha(150),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.isCompleted && widget.onReMeasure != null)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withAlpha(40),
                      ),
                    ),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onReMeasure!();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Re-measure',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Expanded content with animation
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: widget.isCurrent
                ? FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Illustration area with enhanced design
                            _buildStepIllustration(),
                            const SizedBox(height: 16),

                            // Real-time weight indicator during recording
                            if (widget.currentLiveWeight != null && widget.stability != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildRealTimeWeightIndicator(
                                  widget.currentLiveWeight!,
                                  widget.stability!,
                                ),
                              ),

                            // Instruction text
                            Container(
                              margin: const EdgeInsets.only(left: 0),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.instruction,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withAlpha(130),
                                  fontSize: 13,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action button with enhanced styling
                            Center(
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _stepColor.withAlpha(200),
                                        _stepColor.withAlpha(180),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _stepColor.withAlpha(60),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        widget.onAction!();
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _stepIcon,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                widget.buttonLabel,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _getStepDescription() {
    switch (widget.stepNumber) {
      case 0:
        return 'Zero the Scale';
      case 1:
        return 'Sample Weight';
      case 2:
        return 'Water Baseline';
      case 3:
        return 'Submerged Weight';
      default:
        return 'Calculate';
    }
  }

  Widget _buildRealTimeWeightIndicator(
    double currentWeight,
    double stability,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _stepColor.withAlpha(20),
            _stepColor.withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _stepColor.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync,
                size: 16,
                color: _stepColor,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE READING',
                style: GoogleFonts.inter(
                  color: _stepColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              _buildStabilityIndicator(stability),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentWeight.toStringAsFixed(2),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'g',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(150),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stability bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stability / 100,
              backgroundColor: Colors.white.withAlpha(10),
              valueColor: AlwaysStoppedAnimation<Color>(
                stability > 80
                    ? Colors.green
                    : stability > 50
                        ? Colors.orange
                        : Colors.red,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stability: ${stability.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(120),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityIndicator(double stability) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stability > 80
            ? Colors.green.withAlpha(20)
            : stability > 50
                ? Colors.orange.withAlpha(20)
                : Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stability > 80
              ? Colors.green.withAlpha(60)
              : stability > 50
                  ? Colors.orange.withAlpha(60)
                  : Colors.red.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stability > 80
                ? Icons.check_circle
                : stability > 50
                    ? Icons.adjust
                    : Icons.radio_button_unchecked,
            size: 12,
            color: stability > 80
                ? Colors.green
                : stability > 50
                    ? Colors.orange
                    : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            stability > 80 ? 'Stable' : stability > 50 ? 'Stabilizing' : 'Unstable',
            style: GoogleFonts.inter(
              color: stability > 80
                  ? Colors.green
                  : stability > 50
                      ? Colors.orange
                      : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
