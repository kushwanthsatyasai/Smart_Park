# Power Connection Guide for ESP32-CAM

## Power Supply Connections (Red and Black Wires)

### 1. Main Power Supply (5V 1.5A)
```
Red Wire → ESP32-CAM 5V pin
Black Wire → ESP32-CAM GND pin
```

### 2. Capacitor Connection
```
Red Wire → ESP32-CAM 5V pin
Black Wire → ESP32-CAM GND pin
```

## Detailed Connection Steps

### Step 1: Power Supply Connection
1. Connect the red wire from your 5V 1.5A power supply to the ESP32-CAM's 5V pin
2. Connect the black wire from your power supply to the ESP32-CAM's GND pin
3. **Important**: Double-check these connections before powering on

### Step 2: Capacitor Connection
1. Connect the 100µF capacitor:
   - Positive lead (longer leg) → ESP32-CAM 5V pin
   - Negative lead (shorter leg) → ESP32-CAM GND pin
2. **Important**: The capacitor should be connected in parallel with the power supply

## Power Management Tips

### For ESP32-CAM
1. The 100µF capacitor is sufficient for:
   - Stabilizing power for the ESP32-CAM
   - Handling brief power fluctuations
   - Supporting camera operations

2. Power Requirements:
   - ESP32-CAM needs stable 5V
   - Maximum current draw: ~500mA
   - Your 1.5A power supply is adequate

### For Servo Motor
1. The 100µF capacitor might be too small for the servo motor
2. Recommendations:
   - Use a separate power supply for the servo if possible
   - Or use a larger capacitor (at least 470µF) for servo operation

## Safety Precautions
1. Always connect red wire to positive (5V)
2. Always connect black wire to negative (GND)
3. Never reverse the polarity
4. Double-check connections before powering on
5. Keep connections secure and insulated

## Testing Steps
1. Before connecting components:
   - Test power supply voltage (should be 5V)
   - Check capacitor polarity
2. After connecting:
   - Monitor ESP32-CAM temperature
   - Check for stable operation
   - Watch for any power-related issues

## Troubleshooting
1. If ESP32-CAM doesn't power on:
   - Check red/black wire connections
   - Verify power supply voltage
2. If unstable operation:
   - Check capacitor connections
   - Verify power supply stability
3. If camera issues:
   - Ensure stable power supply
   - Check for interference

## Additional Notes
1. Keep power wires as short as possible
2. Use proper wire gauge (18-22 AWG recommended)
3. Consider using a breadboard for prototyping
4. Monitor power supply temperature
5. Keep connections away from metal objects

## Recommended Setup
For most reliable operation:
1. Use separate power supplies for:
   - ESP32-CAM (5V 1.5A)
   - Servo Motor (5V 2A)
2. Use separate capacitors for:
   - ESP32-CAM (100µF)
   - Servo Motor (470µF or larger)
3. Connect all grounds together

Would you like me to provide a diagram showing these connections or explain any part in more detail? 