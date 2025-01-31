#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <TFT_eSPI.h> // Include the TFT_eSPI library

// Create TFT object
TFT_eSPI tft = TFT_eSPI();

MAX30105 particleSensor;

// Heart rate variables
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
float beatAvg = 0;

// SpO2 variables
double avered = 0, aveir = 0, sumirrms = 0, sumredrms = 0;
int i = 0, Num = 100;
float ESpO2 = 0, FSpO2 = 0.7, frate = 0.95;

// Finger detection thresholds
#define TIMETOBOOT 3000
#define SCALE 88.0
#define SAMPLING 100
#define FINGER_ON 30000

void setup() {
  Serial.begin(115200);
  Wire.setClock(400000);

  // Initialize the TFT display
  tft.init();
  tft.setRotation(1); // Landscape orientation
  tft.fillScreen(TFT_BLACK);

  // Display static labels
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextDatum(TL_DATUM); // Left align text
  tft.setTextSize(2);
  tft.drawString("Pulse Ox Readings", 10, 10);
  tft.drawString("Heart Rate:", 10, 50);
  tft.drawString("Blood Oxygen:", 10, 90);
  tft.drawString("Body Temp:", 10, 130);

  while (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 was not found. Please check wiring/power.");
    delay(1000);
  }

  byte ledBrightness = 0x7F;
  byte sampleAverage = 4;
  byte ledMode = 2;
  int sampleRate = 200;
  int pulseWidth = 411;
  int adcRange = 16384;

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.enableDIETEMPRDY();

  Serial.println("Place your index finger on the sensor with steady pressure.");
}

void loop() {
  long irValue = particleSensor.getIR();

  if (irValue > FINGER_ON) {
    if (checkForBeat(irValue) == true) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      beatsPerMinute = 60 / (delta / 1000.0);

      if (beatsPerMinute < 255 && beatsPerMinute > 20) {
        rates[rateSpot++] = (byte)beatsPerMinute;
        rateSpot %= RATE_SIZE;

        beatAvg = 0;
        for (byte x = 0; x < RATE_SIZE; x++) beatAvg += rates[x];
        beatAvg /= RATE_SIZE;
      }
    }

    uint32_t ir, red;
    double fred, fir;
    particleSensor.check();
    while (particleSensor.available()) {
      red = particleSensor.getFIFOIR();
      ir = particleSensor.getFIFORed();

      fred = (double)red;
      fir = (double)ir;
      avered = avered * frate + fred * (1.0 - frate);
      aveir = aveir * frate + fir * (1.0 - frate);
      sumredrms += (fred - avered) * (fred - avered);
      sumirrms += (fir - aveir) * (fir - aveir);

      if ((i % Num) == 0) {
        double R = (sqrt(sumredrms) / avered) / (sqrt(sumirrms) / aveir);
        float SpO2 = -23.3 * (R - 0.4) + 100;
        ESpO2 = FSpO2 * ESpO2 + (1.0 - FSpO2) * SpO2;
        sumredrms = 0.0;
        sumirrms = 0.0;
        i = 0;

        // Read temperature
        float temperature = particleSensor.readTemperature();

        // Update TFT display with readings
        tft.setTextColor(TFT_GREEN, TFT_BLACK);

        // Update Heart Rate
        tft.fillRect(150, 50, 160, 20, TFT_BLACK); // Clear previous value
        tft.setCursor(150, 50);
        tft.printf("%.1f BPM", beatAvg);

        // Update Blood Oxygen Level
        tft.fillRect(180, 90, 160, 20, TFT_BLACK); // Clear previous value
        tft.setCursor(180, 90);
        tft.printf("%.1f %%", ESpO2);

        // Update Body Temperature
        tft.fillRect(150, 130, 160, 20, TFT_BLACK); // Clear previous value
        tft.setCursor(150, 130);
        tft.printf("%.1f C", temperature);

        // Print all values on the Serial Monitor
        Serial.print("IR=");
        Serial.print(irValue);
        Serial.print(", BPM=");
        Serial.print(beatsPerMinute);
        Serial.print(", Avg BPM=");
        Serial.print(beatAvg);
        Serial.print(", SpO2=");
        Serial.print(ESpO2);
        Serial.print("%, Temp=");
        Serial.print(temperature);
        Serial.println("C");
      }
      i++;
      particleSensor.nextSample();
    }
  } else {
    // If no finger is detected, print this message on TFT and Serial Monitor
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.fillRect(10, 200, 300, 20, TFT_BLACK); // Clear previous message
    tft.drawString("No finger detected", 10, 200);

    Serial.println("No finger detected. Place your index finger on the sensor.");
    delay(500);
  }
}

