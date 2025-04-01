#include <WiFi.h>

const char* ssid = "Your_WiFi_Name";      // Your WiFi name
const char* password = "Your_WiFi_Pass";   // Your WiFi password

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\nESP32-CAM Test Starting...");
  
  // Initialize WiFi in Station mode
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  
  Serial.println("Scanning for WiFi networks...");
  int n = WiFi.scanNetworks();
  if (n == 0) {
    Serial.println("No networks found");
  } else {
    Serial.print(n);
    Serial.println(" networks found");
    for (int i = 0; i < n; ++i) {
      Serial.print(i + 1);
      Serial.print(": ");
      Serial.print(WiFi.SSID(i));
      Serial.print(" (");
      Serial.print(WiFi.RSSI(i));
      Serial.print(")");
      Serial.println((WiFi.encryptionType(i) == WIFI_AUTH_OPEN)?" ":"*");
      delay(10);
    }
  }
  
  // Try to connect
  Serial.println("\nConnecting to WiFi...");
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnected successfully!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nFailed to connect!");
  }
}

void loop() {
  // Print WiFi status every 5 seconds
  Serial.print("WiFi Status: ");
  Serial.print(WiFi.status());
  Serial.print(" | RSSI: ");
  Serial.println(WiFi.RSSI());
  delay(5000);
} 