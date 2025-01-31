#include <TFT_eSPI.h> // TFT library for ST7796S

// Pin Definitions
#define ECG_PIN 36       // VP (OUTPUT of AD8232 to GPIO36)
#define LO_PLUS_PIN 25   // LO+ connected to GPIO25
#define LO_MINUS_PIN 26  // LO- connected to GPIO26

// TFT instance
TFT_eSPI tft = TFT_eSPI();

// ECG graph settings
#define GRAPH_WIDTH 720
#define GRAPH_HEIGHT 275
#define GRAPH_X_OFFSET 0
#define GRAPH_Y_OFFSET 60

int xPos = GRAPH_X_OFFSET;  // Current x-position for the graph
int prevGraphY = -1;        // Previous y-coordinate for the ECG graph

void setup() {
  // Initialize ECG pins
  pinMode(ECG_PIN, INPUT);
  pinMode(LO_PLUS_PIN, INPUT);
  pinMode(LO_MINUS_PIN, INPUT);

  // Initialize Serial
  Serial.begin(115200);
  Serial.println("Starting ECG Monitoring...");

  // Initialize TFT display
  tft.init();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);

  // Display header
  tft.drawString("ECG Monitoring", 10, 10);
  tft.drawRect(GRAPH_X_OFFSET, GRAPH_Y_OFFSET, GRAPH_WIDTH, GRAPH_HEIGHT, TFT_BLACK); // Draw graph boundary
}

void loop() {
  // Check Lead-Off Status
  bool loPlusStatus = digitalRead(LO_PLUS_PIN);
  bool loMinusStatus = digitalRead(LO_MINUS_PIN);

  if (loPlusStatus || loMinusStatus) {
    // If electrodes are disconnected
    tft.fillRect(10, 270, 300, 30, TFT_BLACK); // Clear previous message
    tft.drawString("Electrodes disconnected!", 10, 270);
  } else {
    // Read ECG signal
    int ecgValue = analogRead(ECG_PIN);

    // Map ECG value to graph height
    int graphY = map(ecgValue, 0, 4095, GRAPH_Y_OFFSET + GRAPH_HEIGHT, GRAPH_Y_OFFSET);

    // Draw a thicker line for the ECG signal
    if (xPos == GRAPH_X_OFFSET) {
      tft.fillRect(GRAPH_X_OFFSET + 1, GRAPH_Y_OFFSET + 1, GRAPH_WIDTH - 2, GRAPH_HEIGHT - 2, TFT_BLACK); // Clear graph area
      prevGraphY = -1; // Reset previous y-coordinate
    }

    if (prevGraphY != -1) {
      // Draw a line between the previous and current points
      tft.drawLine(xPos - 1, prevGraphY, xPos, graphY, TFT_GREEN);
      // Draw a slightly thicker line for better visibility
      tft.drawLine(xPos - 1, prevGraphY + 1, xPos, graphY + 1, TFT_GREEN);
    }

    // Update previous y-coordinate
    prevGraphY = graphY;

    // Advance x-position
    xPos++;
    if (xPos >= GRAPH_X_OFFSET + GRAPH_WIDTH) {
      xPos = GRAPH_X_OFFSET; // Reset to start
    }

    // Clear disconnection message
    //tft.fillRect(10, 270, 300, 30, TFT_BLACK);
  }

  delay(10);  // Sampling rate ~100Hz
}
