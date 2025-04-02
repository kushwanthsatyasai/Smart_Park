# Power Connection Guide for ESP32-CAM

## Power Supply Connections (Red and Black Wires)

### 1. Main Power Supply (5V 1.5A)
```
Red Wire → ESP32-CAM 5V pin
Black Wire → ESP32-CAM GND pin
```

### 2. Capacitor Connection (470µF)
```
Red Wire → ESP32-CAM 5V pin
Black Wire → ESP32-CAM GND pin
```

### 3. FTDI Programmer Connections
```
FTDI Programmer    →    ESP32-CAM
--------------------------------
TX (White)        →    U0R (GPIO3)
RX (Green)        →    U0T (GPIO1)
GND (Black)       →    GND Rail
```
Note: Do NOT connect FTDI's 5V when using external power!

## Complete Connection Guide

### Step 1: Breadboard Setup
1. Place ESP32-CAM on breadboard
2. Place FTDI programmer on breadboard
3. Connect 470µF capacitor on breadboard
4. Connect IR sensor and servo motor

### Step 2: Ground Connections (All Black Wires)
1. Connect external power supply GND to GND rail
2. Connect ESP32-CAM GND to GND rail
3. Connect FTDI GND to GND rail
4. Connect servo motor GND to GND rail
5. Connect IR sensor GND to GND rail
6. Connect capacitor negative (shorter leg) to GND rail

### Step 3: Power Connections (All Red Wires)
1. Connect external 5V power to power rail
2. Connect ESP32-CAM 5V to power rail
3. Connect servo motor power to power rail
4. Connect IR sensor VCC to power rail
5. Connect capacitor positive (longer leg) to power rail
DO NOT connect FTDI 5V!

### Step 4: Signal Connections
1. Servo motor signal (Orange/Yellow) → GPIO12
2. IR sensor OUT (Yellow) → GPIO13
3. FTDI TX (White) → ESP32-CAM U0R (GPIO3)
4. FTDI RX (Green) → ESP32-CAM U0T (GPIO1)

### Step 5: Programming Mode Setup
1. Add jumper or button between GPIO0 and GND
2. Add reset button between RST and GND

## Power Management Tips

### For ESP32-CAM
1. The 470µF capacitor provides:
   - Enhanced power stability
   - Support for both ESP32-CAM and servo
   - Better handling of power spikes

2. Power Requirements:
   - ESP32-CAM needs stable 5V
   - Maximum current draw: ~500mA
   - External 5V 1.5A power supply is ideal

### For Components
1. Servo Motor:
   - Powered from same 5V rail
   - Benefits from 470µF capacitor stability
   - Peak current handled by power supply

2. IR Sensor:
   - Stable 5V from power rail
   - Low current consumption
   - Clean ground connection important

## Programming Process
1. Initial Setup:
   - Connect all grounds first
   - Connect signal wires (TX/RX)
   - Connect GPIO0 to GND
   - Press reset button

2. Upload Process:
   - Select correct board in Arduino IDE
   - Choose proper COM port
   - Start upload
   - Release GPIO0 after upload

3. Normal Operation:
   - Disconnect GPIO0 from GND
   - Press reset button
   - Check Serial Monitor for startup messages

## Safety Precautions
1. Power Connection Order:
   - Connect all GND first
   - Connect components
   - Connect external power last

2. FTDI Safety:
   - Never connect FTDI 5V with external power
   - Keep TX/RX connections secure
   - Maintain proper ground connection

3. General Safety:
   - Double-check all polarities
   - Keep connections insulated
   - Monitor component temperatures
   - Use proper wire gauge (18-22 AWG)

## Troubleshooting
1. If programming fails:
   - Verify TX/RX connections
   - Check GPIO0 to GND connection
   - Ensure proper reset timing

2. If power issues occur:
   - Check all ground connections
   - Verify capacitor polarity
   - Monitor power supply voltage

3. If components misbehave:
   - Check signal connections
   - Verify power stability
   - Ensure clean ground connections

## Additional Notes
1. Keep wires short and organized
2. Use breadboard for clean connections
3. Monitor system during operation
4. Keep connections away from interference
5. Regular maintenance checks recommended

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