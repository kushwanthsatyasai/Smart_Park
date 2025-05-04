# ESP32-CAM to WiFi Module Serial Bridge

## Required Hardware
- ESP32-CAM (with damaged CP1202 chip)
- ESP8266 or another ESP32 module for the serial bridge
- Jumper wires
- 3.3V power supply for both modules
- Optional: breadboard

## Wiring Diagram

```
ESP32-CAM                            ESP8266/ESP32 WiFi Module
---------                            -----------------------
VCC (3.3V) ------------------+------ VCC (3.3V)
                             |
                            [PS]     (3.3V Power Supply)
                             |
GND --------------------------+------ GND
                             
U0TXD (GPIO1) -------------+------- RX  
                           |
                          [R]       (Optional 470Ω resistor)
                           |
U0RXD (GPIO3) --------------+------ TX
```

## Connection Details

1. **Power Connections**:
   - Connect both modules to 3.3V power supply
   - Connect GND of both modules together

2. **Serial Connections**:
   - Connect ESP32-CAM's U0TXD (GPIO1) to WiFi module's RX pin
   - Connect ESP32-CAM's U0RXD (GPIO3) to WiFi module's TX pin
   - Optional: Add a 470Ω resistor in the TX-RX connection for protection

3. **ESP32-CAM GPIO Pins**:
   - U0TXD is GPIO1
   - U0RXD is GPIO3

## Setup Instructions

1. Upload the serial bridge sketch to your ESP8266/ESP32 WiFi module
2. Power up both modules
3. Connect to the WiFi network "ESP32CAM_Monitor" with password "12345678"
4. Open a web browser and navigate to 192.168.4.1 (default AP IP)
5. You should now see the ESP32-CAM serial output in the web interface

## Troubleshooting

1. **No serial data appears**:
   - Confirm ESP32-CAM is powered properly
   - Check GPIO connections (TX/RX might need to be swapped)
   - Make sure baud rates match (both set to 115200)

2. **Unable to connect to WiFi network**:
   - Ensure WiFi module code is properly uploaded
   - Confirm power supply is stable

3. **Unstable or corrupted data**:
   - Try lowering the baud rate (e.g., 9600 instead of 115200)
   - Add a small delay in the loop function
   - Ensure ground connection is solid 