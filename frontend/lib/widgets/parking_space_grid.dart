import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ParkingSpaceGrid extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final String? selectedSlotId;
  final Function(Map<String, dynamic>) onSlotSelected;

  const ParkingSpaceGrid({
    Key? key,
    required this.slots,
    this.selectedSlotId,
    required this.onSlotSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isAvailable = slot['is_available'] ?? false;
        final isSelected = slot['id'] == selectedSlotId;

        return GestureDetector(
          onTap: isAvailable ? () => onSlotSelected(slot) : null,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : isAvailable
                      ? AppTheme.cardBackground
                      : AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : isAvailable
                        ? AppTheme.secondaryBlue.withOpacity(0.3)
                        : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car,
                  size: 32,
                  color: isSelected
                      ? Colors.white
                      : isAvailable
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary.withOpacity(0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  slot['slot_number'].toString(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isAvailable
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary.withOpacity(0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 