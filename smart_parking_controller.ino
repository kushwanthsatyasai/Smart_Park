#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <ESP32QRCodeReader.h>
#include "esp_camera.h"
#include "quirc/quirc.h"
#include <SPI.h>
#include <SD.h>
#include <WebServer.h>
#include <ESPmDNS.h>

// Define camera model
#define CAMERA_MODEL_AI_THINKER

// WiFi credentials
const char* ssid = "Kushwanth's Iphone";
const char* password = "ammalove";

// Supabase configuration
const char* supabaseUrl = "https://ubqrfmyvutvstgxeubvr.supabase.co";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVicXJmbXl2dXR2c3RneGV1YnZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkyNzc1MDgsImV4cCI6MjA1NDg1MzUwOH0.3wU-ZJFNSJZIoL2DdrlJjbmb1799ElBtt_IXNwXf-ek";
const char* parkingLotId = "8077dae0-c4f8-40ba-94c4-aa985c30ebfb";

// Pin definitions
const int SERVO_PIN = 12;      // Servo motor pin
const int IR_SENSOR_PIN = 13;  // IR sensor pin
const int CAPACITOR_PIN = 15;  // Capacitor control pin

// AI Thinker ESP32-CAM Pin Mapping
#define PWDN_GPIO_NUM    -1
#define RESET_GPIO_NUM   -1
#define XCLK_GPIO_NUM    0
#define SIOD_GPIO_NUM    26
#define SIOC_GPIO_NUM    27
#define Y9_GPIO_NUM      35
#define Y8_GPIO_NUM      34
#define Y7_GPIO_NUM      39
#define Y6_GPIO_NUM      36
#define Y5_GPIO_NUM      21
#define Y4_GPIO_NUM      19
#define Y3_GPIO_NUM      18
#define Y2_GPIO_NUM      5
#define VSYNC_GPIO_NUM   25
#define HREF_GPIO_NUM    23
#define PCLK_GPIO_NUM    22

// QR code processing
struct quirc *qr;
struct quirc_code code;
struct quirc_data data;

// Initialize components
Servo gateServo;
bool parkingSlotStatus = false;
unsigned long lastUpdateTime = 0;
const unsigned long UPDATE_INTERVAL = 5000;
bool isGateOpen = false;
unsigned long gateOpenTime = 0;
const unsigned long GATE_TIMEOUT = 10000; // 10 seconds timeout for gate

// Add after other global variables
const int SD_CS = 5;  // SD Card CS pin
WebServer server(80);

// Function declarations
void connectToWiFi();
bool processQRCode(camera_fb_t *fb);
void updateParkingSlotStatus();
void updateSlotStatusInDatabase();
void verifyAndOperateGate(String qrData);
void operateGate(bool open);
void checkGateTimeout();
void printImageInfo(camera_fb_t *fb);
void saveImageToSD(camera_fb_t *fb);
void handleRoot();
void handleCapture();
void displayImagePreview(camera_fb_t *fb);
void handleDownload();

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("System Booting...");

  // Power cycle the camera module more aggressively
  pinMode(4, OUTPUT);              // GPIO 4 controls camera power
  digitalWrite(4, LOW);            // Turn off camera
  delay(3000);                     // Longer wait time
  digitalWrite(4, HIGH);           // Turn on camera
  delay(3000);                     // Longer wait time

  // Reset GPIO service
  gpio_uninstall_isr_service();    // Uninstall existing service
  delay(1000);

  // Initialize Camera with proper error handling
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 8000000;   // Further reduced to 8MHz for stability
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  // Enable PSRAM - crucial for camera operation
  if(!psramFound()) {
    Serial.println("PSRAM not found - Camera cannot initialize!");
    while(1) {
      Serial.println("Camera initialization failed - No PSRAM");
      delay(5000);
    }
    return;
  }

  Serial.println("Starting camera initialization...");
  
  // Multiple initialization attempts with power cycling
  int retries = 0;
  esp_err_t err = ESP_FAIL;
  while (err != ESP_OK && retries < 5) {
    // Power cycle between each attempt
    digitalWrite(4, LOW);
    delay(2000);
    digitalWrite(4, HIGH);
    delay(2000);
    
    Serial.printf("Attempting camera initialization (Attempt %d/5)...\n", retries + 1);
    
    // Uninstall and reinstall GPIO service
    gpio_uninstall_isr_service();
    delay(500);
    
    err = esp_camera_init(&config);
    if (err != ESP_OK) {
      Serial.printf("Camera init failed with error 0x%x - Retrying %d/5\n", err, retries + 1);
      if (err == ESP_ERR_NOT_FOUND) {
        Serial.println("Camera not found error - Check physical connections");
        Serial.println("1. Is the camera cable properly inserted?");
        Serial.println("2. Is the cable oriented correctly?");
        Serial.println("3. Are there any bent pins?");
      }
      retries++;
      delay(1000);
    }
  }

  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    Serial.println("Try the following:");
    Serial.println("1. Check camera cable connection");
    Serial.println("2. Make sure cable is not damaged");
    Serial.println("3. Verify power supply is stable");
    Serial.println("4. Reset the board");
    delay(1000);
    ESP.restart();  // Restart if camera init fails
    return;
  }

  Serial.println("Camera initialized successfully!");

  // Get sensor settings
  sensor_t * s = esp_camera_sensor_get();
  if (s) {
    s->set_framesize(s, FRAMESIZE_QVGA);
    s->set_quality(s, 12);        // Lower quality
    s->set_brightness(s, 0);      // Default brightness
    s->set_contrast(s, 0);        // Default contrast
    s->set_saturation(s, 0);      // Default saturation
    s->set_special_effect(s, 0);  // No special effect
    s->set_whitebal(s, 1);        // Enable white balance
    s->set_awb_gain(s, 1);        // Enable AWB gain
    s->set_wb_mode(s, 0);         // Auto White Balance
    s->set_exposure_ctrl(s, 1);   // Enable auto exposure
    s->set_aec2(s, 0);           // Disable AEC DSP
    s->set_gain_ctrl(s, 1);      // Enable auto gain
    s->set_agc_gain(s, 0);       // Set gain to lowest
    s->set_gainceiling(s, (gainceiling_t)0);
    s->set_bpc(s, 1);            // Enable black pixel correction
    s->set_wpc(s, 1);            // Enable white pixel correction
    s->set_raw_gma(s, 1);        // Enable gamma correction
    s->set_lenc(s, 1);           // Enable lens correction
    s->set_hmirror(s, 0);        // No horizontal mirror
    s->set_vflip(s, 0);          // No vertical flip
    s->set_dcw(s, 1);            // Enable downsizing
    
    Serial.println("Camera settings adjusted for stability");
  }

  // Initialize QR decoder
  qr = quirc_new();
  if (!qr) {
    Serial.println("Failed to allocate QR decoder");
    return;
  }
  if (quirc_resize(qr, 640, 480) < 0) {
    Serial.println("Failed to allocate QR buffer");
    return;
  }

  // Modified servo initialization
  pinMode(CAPACITOR_PIN, OUTPUT);
  digitalWrite(CAPACITOR_PIN, HIGH); // Start charging
  delay(2000); // Longer initial charging time
  
  gateServo.attach(SERVO_PIN);
  gateServo.write(0);
  delay(1000);
  
  Serial.println("Servo initialized with power management");

  // Initialize IR sensor
  pinMode(IR_SENSOR_PIN, INPUT);
  Serial.println("IR sensor initialized");

  // Connect to WiFi
  connectToWiFi();

  // Initialize SD card
  if (!SD.begin(SD_CS)) {
    Serial.println("SD Card Mount Failed");
    return;
  }
  Serial.println("SD Card Mounted Successfully");

  // Start web server
  server.on("/", handleRoot);
  server.on("/capture", handleCapture);
  server.on("/download", handleDownload);
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  static unsigned long lastWiFiCheck = 0;
  const unsigned long WiFiCheckInterval = 30000;
  static unsigned long lastImageCapture = 0;
  const unsigned long IMAGE_CAPTURE_INTERVAL = 5000; // Capture every 5 seconds
  
  // Check WiFi status periodically
  if (millis() - lastWiFiCheck >= WiFiCheckInterval) {
    lastWiFiCheck = millis();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi connection lost. Reconnecting...");
      connectToWiFi();
      return;
    }
  }

  // Check gate timeout
  checkGateTimeout();

  if (millis() - lastUpdateTime >= UPDATE_INTERVAL) {
    updateParkingSlotStatus();
    lastUpdateTime = millis();
  }

  // Capture and analyze image periodically
  if (millis() - lastImageCapture >= IMAGE_CAPTURE_INTERVAL) {
    lastImageCapture = millis();
    
    camera_fb_t *fb = esp_camera_fb_get();
    if (fb) {
      Serial.println("\n=== New Image Capture ===");
      printImageInfo(fb);
      displayImagePreview(fb);
      esp_camera_fb_return(fb);
    }
  }

  static unsigned long lastCameraError = 0;
  const unsigned long ERROR_RETRY_INTERVAL = 5000; // 5 seconds between retries
  
  camera_fb_t *fb = esp_camera_fb_get();
  
  if (!fb) {
    Serial.println("Camera capture failed");
    if (millis() - lastCameraError >= ERROR_RETRY_INTERVAL) {
      lastCameraError = millis();
      Serial.println("Attempting to reinitialize camera...");
      esp_camera_deinit();
      delay(100);
      setup();  // Reinitialize everything
    }
    delay(100);
    return;
  }
  
  // If we got here, we have a valid frame
  Serial.println("Camera capture successful");
  
  // Process the frame
  if (processQRCode(fb)) {
    String qrData = String((char *)data.payload, data.payload_len);
    Serial.println("QR Code detected: " + qrData);
    verifyAndOperateGate(qrData);
  }
  
  esp_camera_fb_return(fb);
  delay(100);  // Small delay between captures

  // Handle web server requests
  server.handleClient();
}

void connectToWiFi() {
  int attempts = 0;
  const int maxAttempts = 20;
  
  WiFi.disconnect();
  delay(1000);
  WiFi.mode(WIFI_STA);
  delay(1000);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  
  while (WiFi.status() != WL_CONNECTED && attempts < maxAttempts) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if(WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected to WiFi");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect. Restarting...");
    ESP.restart();
  }
}

bool processQRCode(camera_fb_t *fb) {
  uint8_t *image = quirc_begin(qr, NULL, NULL);
  memcpy(image, fb->buf, fb->len);
  quirc_end(qr);

  int count = quirc_count(qr);
  if (count <= 0) return false;

  quirc_extract(qr, 0, &code);
  if (quirc_decode(&code, &data) != 0) return false;

  return true;
}

void updateParkingSlotStatus() {
  bool currentStatus = !digitalRead(IR_SENSOR_PIN);
  if (currentStatus != parkingSlotStatus) {
    parkingSlotStatus = currentStatus;
    Serial.println(parkingSlotStatus ? "Vehicle detected" : "Slot empty");
    updateSlotStatusInDatabase();
  }
}

void updateSlotStatusInDatabase() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    StaticJsonDocument<200> doc;
    doc["parking_lot_id"] = parkingLotId;
    doc["slot_number"] = "C2";
    doc["is_occupied"] = parkingSlotStatus;

    String payload;
    serializeJson(doc, payload);

    String endpoint = String(supabaseUrl) + "/rest/v1/rpc/update_slot_status";
    http.begin(endpoint);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", supabaseKey);
    http.POST(payload);
    http.end();
  }
}

void verifyAndOperateGate(String qrData) {
  HTTPClient http;
  String url = String(supabaseUrl) + "/rest/v1/verify_qr?qr_code=" + qrData;
  http.begin(url);
  http.addHeader("apikey", supabaseKey);
  int httpResponseCode = http.GET();

  if (httpResponseCode == 200) {
    String response = http.getString();
    StaticJsonDocument<200> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error && doc["verified"] == true) {
      Serial.println("QR Verified. Opening gate...");
      operateGate(true);
    } else {
      Serial.println("Invalid QR Code or booking");
    }
  } else {
    Serial.println("Verification failed");
  }
  http.end();
}

void operateGate(bool open) {
  // Modified servo operation for small capacitor
  digitalWrite(CAPACITOR_PIN, HIGH); // Start charging
  delay(500); // Longer charging time

  // Move servo in small steps
  if (open) {
    for(int pos = 0; pos <= 90; pos += 10) {
      gateServo.write(pos);
      delay(100);  // Wait between movements
      digitalWrite(CAPACITOR_PIN, HIGH); // Recharge between movements
      delay(100);  // Allow charging
    }
    isGateOpen = true;
    gateOpenTime = millis();
  } else {
    for(int pos = 90; pos >= 0; pos -= 10) {
      gateServo.write(pos);
      delay(100);  // Wait between movements
      digitalWrite(CAPACITOR_PIN, HIGH); // Recharge between movements
      delay(100);  // Allow charging
    }
    isGateOpen = false;
  }
  
  digitalWrite(CAPACITOR_PIN, HIGH); // Ensure capacitor is charging for next operation
}

void checkGateTimeout() {
  if (isGateOpen && (millis() - gateOpenTime >= GATE_TIMEOUT)) {
    operateGate(false);
  }
}

void printImageInfo(camera_fb_t *fb) {
  Serial.println("\n=== Image Capture Details ===");
  Serial.printf("Size: %d bytes\n", fb->len);
  Serial.printf("Width: %d, Height: %d\n", fb->width, fb->height);
  Serial.printf("Format: %d\n", fb->format);
  
  // Print first 100 bytes in hex format
  Serial.println("\nFirst 100 bytes (hex):");
  size_t bytesToPrint = (fb->len < 100) ? fb->len : 100;
  for(size_t i = 0; i < bytesToPrint; i++) {
    Serial.printf("%02X ", fb->buf[i]);
    if((i + 1) % 16 == 0) Serial.println(); // New line every 16 bytes
  }
  Serial.println("\n");
  
  // Print image header information
  Serial.println("JPEG Header Information:");
  if(fb->buf[0] == 0xFF && fb->buf[1] == 0xD8) {
    Serial.println("Valid JPEG header found");
    Serial.printf("Quality: %d\n", fb->buf[2]);
    Serial.printf("Resolution: %dx%d\n", fb->buf[3] << 8 | fb->buf[4], fb->buf[5] << 8 | fb->buf[6]);
  } else {
    Serial.println("Invalid JPEG header");
  }
  
  // Print image statistics
  int totalBrightness = 0;
  size_t pixelCount = 0;
  size_t maxPixels = (fb->len < 1000) ? fb->len : 1000;
  for(size_t i = 0; i < maxPixels; i++) {
    totalBrightness += fb->buf[i];
    pixelCount++;
  }
  float avgBrightness = (float)totalBrightness / pixelCount;
  Serial.printf("Average brightness: %.2f\n", avgBrightness);
  
  Serial.println("\n=== End of Image Details ===\n");
}

void displayImagePreview(camera_fb_t *fb) {
  Serial.println("\n=== Image Preview (ASCII) ===");
  // We'll sample every 10th pixel to create a smaller preview
  const int sampleRate = 10;
  const int maxWidth = 40;  // Maximum width of ASCII preview
  const int maxHeight = 20; // Maximum height of ASCII preview
  
  // Calculate scaling factors
  int scaleX = fb->width / maxWidth;
  int scaleY = fb->height / maxHeight;
  
  // ASCII characters for different brightness levels
  const char* asciiChars = " .:-=+*#%@";
  const int numChars = strlen(asciiChars) - 1;
  
  // Print preview
  for(int y = 0; y < fb->height; y += scaleY) {
    for(int x = 0; x < fb->width; x += scaleX) {
      // Calculate pixel position in buffer
      int pixelPos = (y * fb->width + x) * 3; // Assuming RGB format
      if(pixelPos + 2 >= fb->len) break;
      
      // Calculate brightness (simple average of RGB)
      int brightness = (fb->buf[pixelPos] + fb->buf[pixelPos + 1] + fb->buf[pixelPos + 2]) / 3;
      
      // Map brightness to ASCII character
      int charIndex = (brightness * numChars) / 255;
      Serial.print(asciiChars[charIndex]);
    }
    Serial.println();
  }
  Serial.println("\n=== End of Preview ===\n");
}

void saveImageToSD(camera_fb_t *fb) {
  // Create a unique filename using timestamp
  char filename[32];
  sprintf(filename, "/image_%lu.jpg", millis());
  
  File file = SD.open(filename, FILE_WRITE);
  if (!file) {
    Serial.println("Failed to open file for writing");
    return;
  }
  
  // Write the image data
  if (file.write(fb->buf, fb->len)) {
    Serial.printf("Image saved as %s\n", filename);
  } else {
    Serial.println("Failed to write image to file");
  }
  
  file.close();
}

void handleRoot() {
  String html = "<html><head>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; margin: 20px; }";
  html += "h1 { color: #333; }";
  html += ".button { display: inline-block; padding: 10px 20px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; margin: 10px 0; }";
  html += ".button:hover { background-color: #45a049; }";
  html += "img { max-width: 640px; margin: 20px 0; }";
  html += "</style>";
  html += "</head><body>";
  
  html += "<h1>ESP32-CAM Image Viewer</h1>";
  html += "<p><a href='/capture' class='button'>Capture New Image</a></p>";
  html += "<p><a href='/download' class='button'>Download Latest Image</a></p>";
  html += "<p><a href='/stream' class='button'>Start Live Stream</a></p>";
  html += "<div id='imageContainer'></div>";
  
  // Add JavaScript for live streaming
  html += "<script>";
  html += "function startStream() {";
  html += "  const img = document.createElement('img');";
  html += "  img.src = '/capture?' + new Date().getTime();";
  html += "  img.onload = function() {";
  html += "    document.getElementById('imageContainer').innerHTML = '';";
  html += "    document.getElementById('imageContainer').appendChild(img);";
  html += "    setTimeout(startStream, 1000);";
  html += "  };";
  html += "</script>";
  
  html += "</body></html>";
  server.send(200, "text/html", html);
}

void handleCapture() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (fb) {
    server.setContentLength(fb->len);
    server.send(200, "image/jpeg");
    server.sendContent((char*)fb->buf, fb->len);
    esp_camera_fb_return(fb);
  } else {
    server.send(500, "text/plain", "Camera capture failed");
  }
}

void handleDownload() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (fb) {
    // Set headers for file download
    server.sendHeader("Content-Type", "image/jpeg");
    server.sendHeader("Content-Disposition", "attachment; filename=capture.jpg");
    server.sendHeader("Content-Length", String(fb->len));
    
    // Send the image data
    server.setContentLength(fb->len);
    server.send(200, "image/jpeg");
    server.sendContent((char*)fb->buf, fb->len);
    esp_camera_fb_return(fb);
  } else {
    server.send(500, "text/plain", "Camera capture failed");
  }
} 