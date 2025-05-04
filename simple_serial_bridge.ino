#include <ESP8266WiFi.h>        // Use <WiFi.h> for ESP32
#include <WebSocketsServer.h>    // Install from Library Manager
#include <ESP8266WebServer.h>    // Use <WebServer.h> for ESP32

// WiFi credentials
const char* ssid = "ESP32CAM_Monitor";
const char* password = "12345678";

// Create web server and websocket server
ESP8266WebServer server(80);     // Use WebServer for ESP32
WebSocketsServer webSocket(81);

void setup() {
  // Start serial connection to ESP32-CAM
  Serial.begin(115200);
  
  // Configure ESP as an access point
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  
  Serial.println();
  Serial.print("Access Point started: ");
  Serial.println(ssid);
  Serial.print("IP address: ");
  Serial.println(WiFi.softAPIP());

  // Setup WebSocket server
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);

  // Configure web server routes
  server.on("/", HTTP_GET, handleRoot);
  server.begin();
  
  Serial.println("HTTP server started");
}

void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  html += "<title>ESP32-CAM Serial Monitor</title>";
  html += "<style>";
  html += "body{font-family:Arial,sans-serif;margin:20px;color:#333;}";
  html += "#terminal{background-color:#f5f5f5;border:1px solid #ccc;height:350px;padding:10px;overflow-y:scroll;font-family:monospace;margin-bottom:10px;}";
  html += "input{width:70%;padding:8px;}";
  html += "button{background-color:#4CAF50;color:white;padding:8px 15px;border:none;cursor:pointer;}";
  html += "button:hover{background-color:#45a049;}";
  html += ".controls{display:flex;gap:10px;margin-top:10px;}";
  html += "</style>";
  html += "</head><body>";
  html += "<h1>ESP32-CAM Serial Monitor</h1>";
  html += "<div id='terminal'></div>";
  html += "<div class='controls'>";
  html += "<input type='text' id='cmd' placeholder='Enter command...'>";
  html += "<button onclick='sendCommand()'>Send</button>";
  html += "<button onclick='clearTerminal()'>Clear</button>";
  html += "</div>";
  html += "<p>Connect to the ESP32-CAM at <strong>" + WiFi.softAPIP().toString() + "</strong></p>";
  html += "<script>";
  html += "var ws=new WebSocket('ws://'+window.location.hostname+':81/');";
  html += "var term=document.getElementById('terminal');";
  html += "ws.onmessage=function(e){term.innerHTML+=e.data+'<br>';term.scrollTop=term.scrollHeight;};";
  html += "function sendCommand(){var cmd=document.getElementById('cmd').value;ws.send(cmd);document.getElementById('cmd').value='';};";
  html += "function clearTerminal(){term.innerHTML='';};";
  html += "document.getElementById('cmd').addEventListener('keypress',function(e){if(e.key==='Enter')sendCommand();});";
  html += "</script>";
  html += "</body></html>";
  server.send(200, "text/html", html);
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.printf("[WebSocket] Client #%u disconnected\n", num);
      break;
    case WStype_CONNECTED:
      {
        IPAddress ip = webSocket.remoteIP(num);
        Serial.printf("[WebSocket] Client #%u connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
      }
      break;
    case WStype_TEXT:
      // Forward data from WebSocket to ESP32-CAM serial
      Serial.write(payload, length);
      Serial.println(); // Add newline after command
      break;
  }
}

void loop() {
  webSocket.loop();
  server.handleClient();
  
  // Forward serial data from ESP32-CAM to all WebSocket clients
  while (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');
    webSocket.broadcastTXT(data);
  }
  
  yield(); // Allow ESP8266 to handle background tasks
} 