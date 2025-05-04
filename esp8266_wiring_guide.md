# ESP8266 to ESP32-CAM Serial Bridge Wiring Guide

## Required Hardware
- ESP32-CAM (with damaged CP1202 chip)
- ESP8266 module (NodeMCU, Wemos D1 Mini, or similar)
- Jumper wires
- 3.3V power supply for the ESP32-CAM
- Computer with Arduino IDE

## Wiring Diagram

```
ESP32-CAM                            ESP8266 (NodeMCU)
---------                            ---------------
VCC (3.3V) ------------------------- 3V3 (not Vin!)
GND --------------------------+------ GND
                              |
U0TXD (GPIO1) ---------------|------ D6 (GPIO12)
                              |
U0RXD (GPIO3) ---------------|------ D5 (GPIO14)
```

## Pin Connections

1. **Power Connection:**
   - Connect ESP32-CAM's VCC to ESP8266's 3V3 pin (NOT Vin)
   - Connect ESP32-CAM's GND to ESP8266's GND

2. **Serial Connection:**
   - Connect ESP32-CAM's U0TXD (GPIO1) to ESP8266's D6 pin
   - Connect ESP32-CAM's U0RXD (GPIO3) to ESP8266's D5 pin

## ESP8266 Pin Reference (NodeMCU)

For NodeMCU ESP8266 module:
- D5 = GPIO14
- D6 = GPIO12

For Wemos D1 Mini:
- D5 = GPIO14
- D6 = GPIO12

## Step-by-Step Setup

1. **Connect the Hardware:**
   - Make all connections according to the diagram when both devices are powered OFF
   - Double-check that you're using 3.3V (not 5V) for the ESP32-CAM

2. **Prepare the Arduino IDE:**
   - Install ESP8266 board support in Arduino IDE
   - Install the required libraries:
     - ESP8266WiFi
     - ESP8266WebServer
     - WebSocketsServer (by Markus Sattler)

3. **Upload the Software:**
   - Open the `esp8266_serial_bridge.ino` in Arduino IDE
   - Select your ESP8266 board type from Tools > Board
   - Upload the sketch to the ESP8266

4. **Power Up:**
   - Connect the ESP8266 to USB for power
   - The ESP32-CAM will be powered via the ESP8266's 3V3 pin

5. **Connect and Monitor:**
   - On your phone or computer, connect to the WiFi network `ESP32CAM_Monitor` with password `12345678`
   - Open a web browser and navigate to `192.168.4.1`
   - You should see the ESP32-CAM's serial output displayed in the web interface

## Troubleshooting

1. **No Serial Data:**
   - Check that ESP32-CAM is properly powered (3.3V)
   - Verify that the ESP32-CAM is actually running (onboard LED should flash)
   - Try swapping the TX/RX connections

2. **Garbled Text:**
   - Confirm that both devices are using the same baud rate (115200)
   - Try a lower baud rate if problems persist (9600)

3. **ESP8266 Not Creating WiFi Network:**
   - Check your upload settings in Arduino IDE
   - Try pressing the reset button on the ESP8266 after upload

4. **Connection Issues:**
   - Keep the wires short to minimize interference
   - Ensure the ground connection is solid
   - Try adding a small delay (10-50ms) in the readSerialData function

## Notes

- This setup only powers the ESP32-CAM enough for serial communication - the camera functionality may not work reliably with this power arrangement
- For full ESP32-CAM functionality, consider using a separate 3.3V power supply
- The ESP8266 D5/D6 pins are used as software serial pins in this setup 