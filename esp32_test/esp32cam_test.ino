#include "esp_camera.h"
#include "Arduino.h"
#include "soc/soc.h"           // Disable brownout problems
#include "soc/rtc_cntl_reg.h"  // Disable brownout problems
#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>

// WiFi credentials
const char* ssid = "Kushwanth's Iphone";  // Replace with your WiFi name
const char* password = "ammalove";         // Replace with your WiFi password

// Camera pins for AI Thinker ESP32-CAM
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Built-in LED pin
#define LED_PIN           33  // GPIO 33 controls built-in LED
#define FLASH_LED_PIN     4   // GPIO 4 controls flash LED
#define LED_ON           LOW
#define LED_OFF          HIGH

// Web server
WebServer server(80);

// Function declarations
void printImageInfo(camera_fb_t *fb);
void displayImagePreview(camera_fb_t *fb);
void analyzeImageQuality(camera_fb_t *fb);
void handleRoot();
void handleCapture();
void handleDownload();

void setup() {
  // Start Serial with a delay to ensure it's ready
  Serial.begin(115200);
  delay(1000);  // Give serial time to start
  
  Serial.println("\n\nESP32-CAM Test Starting...");
  Serial.println("Initializing system...");
  
  // Disable brownout detector
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.println("Brownout detector disabled");
  
  // Configure LED pins
  pinMode(LED_PIN, OUTPUT);
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LED_OFF);
  digitalWrite(FLASH_LED_PIN, LOW);
  Serial.println("LED pins configured");
  
  // Connect to WiFi
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 20) {
    delay(500);
    Serial.print(".");
    wifiAttempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected successfully");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed!");
    Serial.println("Please check your WiFi credentials");
    // Blink LED rapidly to indicate WiFi failure
    while(1) {
      digitalWrite(LED_PIN, LED_ON);
      delay(100);
      digitalWrite(LED_PIN, LED_OFF);
      delay(100);
    }
  }
  
  // Power cycle the camera module
  Serial.println("Power cycling camera...");
  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);
  delay(3000);
  digitalWrite(FLASH_LED_PIN, HIGH);
  delay(3000);
  Serial.println("Camera power cycle complete");

  // Reset GPIO service
  Serial.println("Resetting GPIO service...");
  gpio_uninstall_isr_service();
  delay(1000);
  
  // Camera configuration
  Serial.println("Setting up camera configuration...");
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
  config.xclk_freq_hz = 8000000;
  config.pixel_format = PIXFORMAT_RGB565;
  config.frame_size = FRAMESIZE_QVGA;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  // Check for PSRAM
  if(!psramFound()) {
    Serial.println("WARNING: PSRAM not found!");
    config.frame_size = FRAMESIZE_QQVGA;
    config.fb_count = 1;
  } else {
    Serial.println("PSRAM found and enabled");
  }

  // Initialize camera with multiple attempts
  Serial.println("Attempting camera initialization...");
  esp_err_t err = ESP_FAIL;
  int retry_count = 0;
  
  while (err != ESP_OK && retry_count < 5) {
    Serial.printf("Camera initialization attempt %d/5...\n", retry_count + 1);
    
    // Power cycle between attempts
    digitalWrite(FLASH_LED_PIN, LOW);
    delay(2000);
    digitalWrite(FLASH_LED_PIN, HIGH);
    delay(2000);
    
    // Uninstall GPIO service before each attempt
    gpio_uninstall_isr_service();
    delay(1000);
    
    err = esp_camera_init(&config);
    
    if (err != ESP_OK) {
      Serial.printf("Camera initialization failed with error 0x%x\n", err);
      Serial.println("Troubleshooting steps:");
      Serial.println("1. Check camera cable connection");
      Serial.println("2. Verify camera module is compatible");
      Serial.println("3. Check power supply stability");
      Serial.println("4. Try different pixel format");
      retry_count++;
      delay(1000);
    }
  }

  if (err != ESP_OK) {
    Serial.println("Camera initialization failed after all attempts!");
    Serial.println("System halted. Please check hardware connections.");
    // Blink both LEDs rapidly to indicate critical error
    while(1) {
      digitalWrite(LED_PIN, LED_ON);
      digitalWrite(FLASH_LED_PIN, HIGH);
      delay(100);
      digitalWrite(LED_PIN, LED_OFF);
      digitalWrite(FLASH_LED_PIN, LOW);
      delay(100);
    }
  }

  Serial.println("Camera initialized successfully!");
  
  // Configure camera settings
  sensor_t * s = esp_camera_sensor_get();
  if (s) {
    Serial.println("Configuring camera settings...");
    s->set_brightness(s, 0);
    s->set_contrast(s, 0);
    s->set_saturation(s, 0);
    s->set_special_effect(s, 0);
    s->set_whitebal(s, 1);
    s->set_awb_gain(s, 1);
    s->set_wb_mode(s, 0);
    s->set_exposure_ctrl(s, 1);
    s->set_aec2(s, 0);
    s->set_gain_ctrl(s, 1);
    s->set_agc_gain(s, 0);
    s->set_gainceiling(s, (gainceiling_t)0);
    s->set_bpc(s, 0);
    s->set_wpc(s, 1);
    s->set_raw_gma(s, 1);
    s->set_lenc(s, 1);
    s->set_hmirror(s, 0);
    s->set_vflip(s, 0);
    s->set_dcw(s, 1);
    Serial.println("Camera settings configured");
  } else {
    Serial.println("WARNING: Could not get camera sensor settings!");
  }

  // Start web server
  Serial.println("Starting web server...");
  server.on("/", handleRoot);
  server.on("/capture", handleCapture);
  server.on("/download", handleDownload);
  server.begin();
  Serial.println("Web server started successfully");
  
  // Indicate successful setup
  Serial.println("\nSetup complete! System is ready.");
  for(int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, LED_ON);
    delay(500);
    digitalWrite(LED_PIN, LED_OFF);
    delay(500);
  }
}

void loop() {
  // Handle web server requests
  server.handleClient();
  
  Serial.println("\n=== Taking New Picture ===");
  
  // Take picture
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    // Blink twice rapidly to indicate capture failure
    for(int i = 0; i < 2; i++) {
      digitalWrite(LED_PIN, LED_ON);
      delay(200);
      digitalWrite(LED_PIN, LED_OFF);
      delay(200);
    }
    return;
  }
  
  // Print detailed image information
  printImageInfo(fb);
  
  // Display ASCII preview of the image
  displayImagePreview(fb);
  
  // Analyze image quality
  analyzeImageQuality(fb);
  
  // Blink once quickly to indicate successful capture
  digitalWrite(LED_PIN, LED_ON);
  delay(100);
  digitalWrite(LED_PIN, LED_OFF);
  
  // Return the frame buffer back to be reused
  esp_camera_fb_return(fb);
  
  // Wait before next capture
  delay(5000);
}

void printImageInfo(camera_fb_t *fb) {
  Serial.println("\n=== Image Information ===");
  Serial.printf("Size: %d bytes\n", fb->len);
  Serial.printf("Width: %d, Height: %d\n", fb->width, fb->height);
  Serial.printf("Format: %d\n", fb->format);
  
  // Print JPEG header information
  if(fb->buf[0] == 0xFF && fb->buf[1] == 0xD8) {
    Serial.println("Valid JPEG header found");
    Serial.printf("Quality: %d\n", fb->buf[2]);
    Serial.printf("Resolution: %dx%d\n", fb->buf[3] << 8 | fb->buf[4], fb->buf[5] << 8 | fb->buf[6]);
  } else {
    Serial.println("Invalid JPEG header");
  }
  
  // Print first 100 bytes in hex format
  Serial.println("\nFirst 100 bytes (hex):");
  size_t bytesToPrint = (fb->len < 100) ? fb->len : 100;
  for(size_t i = 0; i < bytesToPrint; i++) {
    Serial.printf("%02X ", fb->buf[i]);
    if((i + 1) % 16 == 0) Serial.println();
  }
  Serial.println("\n");
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

void analyzeImageQuality(camera_fb_t *fb) {
  Serial.println("\n=== Image Quality Analysis ===");
  
  // Calculate average brightness
  int totalBrightness = 0;
  int pixelCount = 0;
  size_t bytesToAnalyze = (fb->len < 1000) ? fb->len : 1000;
  for(size_t i = 0; i < bytesToAnalyze; i++) {
    totalBrightness += fb->buf[i];
    pixelCount++;
  }
  float avgBrightness = (float)totalBrightness / pixelCount;
  Serial.printf("Average brightness: %.2f\n", avgBrightness);
  
  // Check for potential issues
  if(avgBrightness < 50) {
    Serial.println("Warning: Image might be too dark");
  } else if(avgBrightness > 200) {
    Serial.println("Warning: Image might be too bright");
  }
  
  // Check image size
  if(fb->len < 1000) {
    Serial.println("Warning: Image size is very small, might be corrupted");
  }
  
  // Check for JPEG markers
  bool hasStartMarker = (fb->buf[0] == 0xFF && fb->buf[1] == 0xD8);
  bool hasEndMarker = false;
  for(int i = fb->len - 2; i >= 0; i--) {
    if(fb->buf[i] == 0xFF && fb->buf[i+1] == 0xD9) {
      hasEndMarker = true;
      break;
    }
  }
  
  if(!hasStartMarker || !hasEndMarker) {
    Serial.println("Warning: JPEG markers not found, image might be corrupted");
  }
  
  Serial.println("=== End of Analysis ===\n");
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
  html += "<div id='imageContainer'></div>";
  
  // Add JavaScript for auto-refresh
  html += "<script>";
  html += "function startStream() {";
  html += "  const img = document.createElement('img');";
  html += "  img.src = '/capture?' + new Date().getTime();";
  html += "  img.onload = function() {";
  html += "    document.getElementById('imageContainer').innerHTML = '';";
  html += "    document.getElementById('imageContainer').appendChild(img);";
  html += "    setTimeout(startStream, 1000);";
  html += "  };";
  html += "}";
  html += "startStream();";
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