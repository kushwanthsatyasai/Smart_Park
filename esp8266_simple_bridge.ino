#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <SoftwareSerial.h>

// WiFi credentials
const char* ssid = "ESP32CAM_Monitor";
const char* password = "12345678";

// Define serial pins for ESP32-CAM
#define RX_PIN D6  // Connect to ESP32-CAM's TX (GPIO1)
#define TX_PIN D5  // Connect to ESP32-CAM's RX (GPIO3)

// Create software serial for ESP32-CAM
SoftwareSerial camSerial(RX_PIN, TX_PIN);

// Create web server
ESP8266WebServer server(80);

// Buffer for storing serial data
String serialBuffer = "";
String webPageData = "";
unsigned long lastDataTime = 0;

void setup() {
  // Start hardware serial for debugging
  Serial.begin(115200);
  Serial.println("\nESP8266 Serial Bridge Starting");
  
  // Setup software serial for ESP32-CAM
  camSerial.begin(115200);
  Serial.println("Connected to ESP32-CAM");
  
  // Configure ESP8266 as access point
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  Serial.print("AP IP address: ");
  Serial.println(WiFi.softAPIP());
  
  // Setup web server routes
  server.on("/", handleRoot);
  server.on("/data", handleData);
  server.on("/send", handleSend);
  server.on("/clear", handleClear);
  server.begin();
  
  Serial.println("HTTP server started");
  Serial.println("Connect to WiFi network '" + String(ssid) + "' with password '" + String(password) + "'");
  Serial.println("Then open a browser to " + WiFi.softAPIP().toString());
}

// Serve the main HTML page
void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>ESP32-CAM Serial Monitor</title>";
  html += "<style>";
  html += "body{font-family:Arial,sans-serif;margin:20px;color:#333;background:#f8f8f8;}";
  html += "#terminal{background-color:#000;color:#0f0;border:1px solid #333;height:350px;padding:10px;overflow-y:scroll;font-family:monospace;margin-bottom:10px;font-size:14px;}";
  html += "input{width:70%;padding:8px;border:1px solid #ccc;border-radius:4px;}";
  html += "button{background-color:#4CAF50;color:white;padding:8px 15px;border:none;cursor:pointer;border-radius:4px;margin-right:5px;}";
  html += "button:hover{background-color:#45a049;}";
  html += ".controls{display:flex;margin-top:10px;}";
  html += "</style>";
  html += "</head><body>";
  html += "<h1>ESP32-CAM Serial Monitor</h1>";
  html += "<div id='terminal'>" + webPageData + "</div>";
  html += "<div class='controls'>";
  html += "<input type='text' id='cmd' placeholder='Enter command to send...'>";
  html += "<button onclick='sendCommand()'>Send</button>";
  html += "<button onclick='clearTerminal()'>Clear</button>";
  html += "<button onclick='refreshData()'>Refresh</button>";
  html += "</div>";
  html += "<script>";
  html += "function sendCommand() {";
  html += "  var cmd = document.getElementById('cmd').value;";
  html += "  fetch('/send?cmd=' + encodeURIComponent(cmd))";
  html += "    .then(response => response.text())";
  html += "    .then(data => { refreshData(); document.getElementById('cmd').value = ''; });";
  html += "}";
  html += "function clearTerminal() {";
  html += "  fetch('/clear').then(response => { document.getElementById('terminal').innerHTML = ''; });";
  html += "}";
  html += "function refreshData() {";
  html += "  fetch('/data')";
  html += "    .then(response => response.text())";
  html += "    .then(data => {";
  html += "      if(data) document.getElementById('terminal').innerHTML = data;";
  html += "    });";
  html += "}";
  html += "// Auto-refresh data every 2 seconds";
  html += "setInterval(refreshData, 2000);";
  html += "// Setup enter key for sending";
  html += "document.getElementById('cmd').addEventListener('keypress', function(e) {";
  html += "  if(e.key === 'Enter') sendCommand();";
  html += "});";
  html += "</script>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
}

// Return the current serial data to be displayed
void handleData() {
  server.send(200, "text/plain", webPageData);
}

// Clear the terminal data
void handleClear() {
  webPageData = "";
  server.send(200, "text/plain", "cleared");
}

// Send a command to the ESP32-CAM
void handleSend() {
  if (server.hasArg("cmd")) {
    String cmd = server.arg("cmd");
    
    // Send command to ESP32-CAM
    camSerial.println(cmd);
    
    // Echo to debug serial
    Serial.print("Sent to ESP32-CAM: ");
    Serial.println(cmd);
    
    // Add to web display
    webPageData += "<span style='color:yellow'>&gt; " + cmd + "</span><br>";
    
    server.send(200, "text/plain", "sent");
  } else {
    server.send(400, "text/plain", "no command provided");
  }
}

void loop() {
  server.handleClient();
  
  // Check for data from ESP32-CAM
  while (camSerial.available() > 0) {
    char c = camSerial.read();
    
    // Add to buffer
    serialBuffer += c;
    
    // If newline or buffer full, process data
    if (c == '\n' || serialBuffer.length() >= 128) {
      if (serialBuffer.length() > 0) {
        // Add to web display data
        webPageData += serialBuffer + "<br>";
        
        // Limit the size of webPageData to prevent memory issues
        if (webPageData.length() > 10000) {
          webPageData = webPageData.substring(webPageData.length() - 8000);
        }
        
        // Echo to debug serial
        Serial.print("From ESP32-CAM: ");
        Serial.print(serialBuffer);
        
        // Clear buffer
        serialBuffer = "";
      }
    }
    
    lastDataTime = millis();
  }
  
  // If data is stale, send anyway
  if (serialBuffer.length() > 0 && millis() - lastDataTime > 200) {
    // Add to web display data
    webPageData += serialBuffer + "<br>";
    
    // Echo to debug serial
    Serial.print("From ESP32-CAM (timeout): ");
    Serial.println(serialBuffer);
    
    serialBuffer = "";
  }
  
  // ESP8266 needs this
  yield();
} 