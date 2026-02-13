#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "WiFi.h"

// Settings
#define BUTTON_PIN 3  
#define SDA_PIN 8     
#define SCL_PIN 9     

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// Data structers (Holding on RAM)
// We will copy data to here because we won't black screen while scanning.
struct NetworkData {
  String ssid;
  int rssi;
  int channel;
  String mac;
  String security;
};

NetworkData foundedNetworks[5]; // We keep on the memory founded most powerfull 5 network
int totalNetworkCount = 0;

// Variables
int page = 0;          
int lastbuttonStats = HIGH; 
unsigned long lastbuttonTime = 0; // for debounce

// Scanning stats check
bool scanningcontinue = false;
unsigned long lastScanStart = 0;
int scanTimer = 0; // for animation

// Fuunction definitions
void drawTitle(String leftWrite);
void scanStart();
void processScanResults();
void pageRadar();
void pageDetail();
void pageSystem();
void openScreen();

void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // Start WI-FI
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  // Start screen
  Wire.begin(SDA_PIN, SCL_PIN);
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
    Serial.println("Screen not founded!");
    for(;;);
  }
  
  openScreen();
  scanStart(); // Pull the trigger for first scan
}

void loop() {
  // 1. ASYNC scan check
  // If scan is over (scanComplete >= 0), take results.
  int scanstats = WiFi.scanComplete();
  
  if (scanstats >= 0) {
    processScanResults(); // Copy data
    WiFi.scanDelete();       // Clear the WI-FI memory
    scanStart();          // Start new scan non-stop (for fast watch)
  }
  // If there is a mistake or scan isn't over yet (-1 or -2), don't wait, keep going.

  // 2. Button read (Non-blocking Debounce)
  int buttonRead = digitalRead(BUTTON_PIN);
  if (buttonRead == LOW && lastbuttonStats == HIGH && (millis() - lastbuttonTime > 150)) {
    page++;
    if (page > 2) sayfa = 0; 
    lastbuttonTime = millis();
  }
  lastbuttonStats = buttonRead;

  // 3. Screen Appearence (Refresh for every loop, not lagged or not freeze)
  display.clearDisplay();
  
  if (page == 0) pageRadar();
  else if (page == 1) pageDetail();
  else if (page == 2) pageSystem();

  // Icon of scan (Blinking dot). Show to system is live.
  if (scanningcontinue) {
     if ((millis() / 500) % 2 == 0) display.fillCircle(124, 15, 2, WHITE);
  }

  display.display();
}

  // New functions

void scanStart() {
  // true parameter is too important. This is "async = true".
  // Starting scan on background for not freeze the processor.
  WiFi.scanNetworks(true); 
  scanningcontinue = true;
  lastScanStart = millis();
}

void processScanResult() {
  int n = WiFi.scanComplete();
  if (n < 0) return;

  totalNetworkCount = n;
  
  // Copy for 5 Network max. (Memory saving)
  int limit = (n > 5) ? 5 : n;
  
  for (int i = 0; i < limit; i++) {
    foundedNetworks[i].ssid = WiFi.SSID(i);
    foundedNetworks[i].rssi = WiFi.RSSI(i);
    foundedNetworks[i].channel = WiFi.channel(i);
    foundedNetworks[i].mac = WiFi.BSSIDstr(i);
    
    if(WiFi.encryptionType(i) == WIFI_AUTH_OPEN) foundedNetworks[i].security = "Open";
    else foundedNetworks[i].security = "Secured";
  }
  scanningcontinue = false;
}

// Visual functions

void drawTitle(String leftWrite) {
  display.fillRect(0, 0, 128, 12, WHITE); 
  display.setTextColor(BLACK); 
  display.setCursor(2, 2);
  display.print(leftWrite);
  
  float temp = temperatureRead(); 
  display.setCursor(95, 2); 
  display.print((int)temp); 
  display.print("C"); 
  display.setTextColor(WHITE);
}

void pageRadar() {
  drawTitle("Scanner (" + String(totalNetworkCount) + ")");

  if (totalNetworkCount == 0) {
    display.setCursor(10, 30);
    if(scanningcontinue) display.print("Scanning...");
    else display.print("No Signal");
  } else {
    // Read the data from copied on RAM (For not freeze)
    int limit = (totalNetworkCount > 4) ? 4 : totalNetworkCount;
    for (int i = 0; i < limit; i++) {
      int y = 16 + (i * 12);
      
      display.setCursor(0, y);
      String name = foundedNetworks[i].ssid;
      if(isim.length()>11) name = name.substring(0,11);
      display.print(name);

      int rssi = foundedNetworks[i].rssi;
      // Let's make more dynamic signal bar
      int bar = map(constrain(rssi, -100, -40), -100, -40, 2, 40);
      
      // Dolu bar çiz
      display.fillRect(85, y, bar, 8, WHITE);
      // Çerçeve çiz (Görsellik)
      display.drawRect(85, y, 40, 8, WHITE);
    }
  }
}

void pageDetail() {
  drawTitle("Info");

  if (totalNetworkCount > 0) {
    // Use data on RAM (0.index most powerfull)
    AgVerisi target = foundedNetworks[0]; 

    display.setCursor(0, 16); display.print("ID:");
    display.setCursor(25, 16); display.println(target.ssid);

    display.setCursor(0, 28); display.print("MAC:"); 
    display.setCursor(25, 28); 
    String shortMac = target.mac;
    if(shortMac.length() > 12) shortMac.remove(12);
    display.print(shortMac); 

    display.setCursor(0, 40); display.print("CH:");
    display.print(target.channel);
    
    display.setCursor(45, 40); display.print("PWR:");
    display.print(target.rssi); display.print("dBm");
    
    display.setCursor(0, 52); display.print("SEC:");
    display.print(target.security);
    
  } else {
    display.setCursor(20, 30); display.print("Searching...");
  }
}

void pageSystem() {
  drawTitle("SYSTEM STATS");
  
  display.setCursor(0, 20); display.print("Mode:");
  display.setCursor(40, 20); display.print("ASYNC SCAN");

  display.setCursor(0, 35); display.print("Time:");
  display.setCursor(40, 35); 
  long time = millis() / 1000;
  display.print(sure); display.print(" sec");

  // Add more technical data
  display.setCursor(0, 50); display.print("RAM:");
  display.setCursor(40, 50); 
  display.print(ESP.getFreeHeap() / 1024); display.print(" KB Free");
}

void openScreen() {
  display.clearDisplay();
  
  // Basic animation for zombie efect
  for(int i=0; i<3; i++) {
    display.clearDisplay();
    display.setTextSize(2);
    display.setTextColor(WHITE);
    display.setCursor(10, 20);
    if(i==0) display.print("ZOMBIE");
    if(i==1) display.print("ZOMBIE C3");
    if(i==2) display.print("ZOMBIE C3");
    
    display.setTextSize(1);
    display.setCursor(80, 40);
    if(i==2) display.print("v1.0");
    display.display();
    delay(200);
  }
  
  delay(500);
}
