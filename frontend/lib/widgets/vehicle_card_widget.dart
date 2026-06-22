import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/vehicle.dart';
import '../utils/constants.dart';
import 'fuel_gauge_widget.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;

  const VehicleCard({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: AppConstants.primaryOrange, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.plateNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primaryOrange,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${vehicle.make} ${vehicle.model} ${vehicle.year}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppConstants.mediumText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: vehicle.status),
                  if (vehicle.assignedDriverName != null) ...[
                    const SizedBox(width: 8),
                    _DriverAvatar(name: vehicle.assignedDriverName!),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              FuelGauge(
                currentL: vehicle.currentFuelL,
                capacityL: vehicle.tankCapacityL,
              ),
              if (vehicle.assignedDriverName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: AppConstants.mediumText),
                    const SizedBox(width: 4),
                    Text(
                      vehicle.assignedDriverName!,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppConstants.mediumText,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleCardCompact extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;

  const VehicleCardCompact({super.key, required this.vehicle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.orangeBorder.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicle.plateNumber,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppConstants.primaryOrange,
              ),
            ),
            Text(
              '${vehicle.make} ${vehicle.model}',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: AppConstants.mediumText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            FuelGauge(
              currentL: vehicle.currentFuelL,
              capacityL: vehicle.tankCapacityL,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'active':
        color = AppConstants.fuelGood;
        break;
      case 'maintenance':
        color = AppConstants.severityMedium;
        break;
      default:
        color = AppConstants.bottomBarUnselected;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final String name;
  const _DriverAvatar({required this.name});

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppConstants.primaryOrange.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppConstants.primaryDarkOrange,
        ),
      ),
    );
  }
}
