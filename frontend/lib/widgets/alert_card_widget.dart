import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/alert.dart';
import '../utils/constants.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onResolve;
  final String? vehiclePlate;

  const AlertCard({
    super.key,
    required this.alert,
    this.onAcknowledge,
    this.onResolve,
    this.vehiclePlate,
  });

  @override
  Widget build(BuildContext context) {
    final color = alert.severityColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppConstants.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(alert.severityIcon, color: color, size: 18),
                const SizedBox(width: 6),
                _SeverityBadge(severity: alert.severity, color: color),
                const Spacer(),
                Text(
                  AppConstants.timeAgo(alert.createdAt),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: AppConstants.mediumText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              alert.title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppConstants.darkText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              alert.description,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppConstants.mediumText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (alert.aiConfidence != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.psychology_outlined,
                      size: 12, color: AppConstants.mediumText),
                  const SizedBox(width: 4),
                  Text(
                    'AI Confidence: ${(alert.aiConfidence! * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppConstants.mediumText),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: alert.aiConfidence,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (vehiclePlate != null || alert.status != 'resolved') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (vehiclePlate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppConstants.lightOrangeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vehiclePlate!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryOrange,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  if (alert.status == 'open' && onAcknowledge != null)
                    _ActionButton(
                      label: 'Acknowledge',
                      color: AppConstants.severityHigh,
                      onTap: onAcknowledge!,
                    ),
                  if (alert.status == 'acknowledged' && onResolve != null) ...[
                    const SizedBox(width: 6),
                    _ActionButton(
                      label: 'Resolve',
                      color: AppConstants.severityResolved,
                      onTap: onResolve!,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  final Color color;
  const _SeverityBadge({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        severity[0].toUpperCase() + severity.substring(1),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
