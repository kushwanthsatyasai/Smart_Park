import 'package:flutter/material.dart';
import '../slot_selection/slot_selection_screen.dart';
import '../../widgets/custom_button.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedVehicle;

  final List<String> vehicles = ['Car', 'Motorcycle', 'SUV'];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _navigateToSlotSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SlotSelectionScreen(
          selectedDate: selectedDate!,
          selectedTime: selectedTime!,
          selectedVehicle: selectedVehicle!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canProceed = selectedDate != null &&
        selectedTime != null &&
        selectedVehicle != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Parking'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(selectedDate == null
                    ? 'Select Date'
                    : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                onTap: () => _selectDate(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime == null
                    ? 'Select Time'
                    : selectedTime!.format(context)),
                onTap: () => _selectTime(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_car),
                title: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select Vehicle Type'),
                  value: selectedVehicle,
                  items: vehicles.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedVehicle = newValue;
                    });
                  },
                ),
              ),
            ),
            const Spacer(),
            CustomButton(
              text: 'Find Available Slots',
              onPressed: canProceed 
                  ? () => _navigateToSlotSelection()
                  : () {},
            ),
          ],
        ),
      ),
    );
  }
}