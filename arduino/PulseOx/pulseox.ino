#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "DFrobot_MSM261.h"
#include "FS.h"
#include <SPI.h>
#include <TFT_eSPI.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"

// Microphone Configuration
#define SAMPLE_RATE (4000)
#define I2S_SCK_IO (12)
#define I2S_WS_IO (15)
#define I2S_DI_IO (32)
#define DATA_BIT (16)
#define MODE_PIN (33)
#define BUFFER_SIZE 256

// Pin Definitions for ECG
#define ECG_PIN 36
#define LO_PLUS_PIN 25
#define LO_MINUS_PIN 26

// Forward declarations
void touch_calibrate();
void showHomeScreen();
void showECGScreen();
void showPulseOxScreen();
void showBluetoothScreen();
void drawHomeButtons();
void drawBackButton();
void initializeBLE(const char* deviceName);
void transmitPulseOxData(float heartRate, float spO2, float temperature);
void transmitECGData(int16_t ecgValue);
void startMeasurement();

// Filter Configuration
#define FILTER_ORDER 4
#define PI 3.14159265359

// BLE Configuration
#define SERVICE_UUID        "19B10000-E8F2-537E-4F6C-D104768A1214"
#define AUDIO_CHAR_UUID    "19B10001-E8F2-537E-4F6C-D104768A1214"
#define CONTROL_CHAR_UUID  "19B10002-E8F2-537E-4F6C-D104768A1214"
#define PULSEOX_CHAR_UUID  "19B10003-E8F2-537E-4F6C-D104768A1214"
#define ECG_CHAR_UUID      "19B10004-E8F2-537E-4F6C-D104768A1214"

// Gain and Noise Configuration
const float INPUT_GAIN = 2.0;
const float POST_FILTER_GAIN = 1.5;
const float NOISE_THRESHOLD = 10.0;

// Modified coefficients for better low-frequency response
float b[FILTER_ORDER + 1] = {0.3, 0.25, 0.2, 0.15, 0.1};
float x[FILTER_ORDER + 1] = {0};  // Input buffer
float y[FILTER_ORDER + 1] = {0};  // Output buffer

// Global variables for MEMS microphone
BLEServer* pServer = nullptr;
BLEService* pService = nullptr;
BLECharacteristic* pAudioCharacteristic = nullptr;
BLECharacteristic* pControlCharacteristic = nullptr;

DFRobot_Microphone microphone(I2S_SCK_IO, I2S_WS_IO, I2S_DI_IO);
int16_t i2sReadrawBuff[BUFFER_SIZE];
bool deviceConnected = false;
bool isRecording = false;

// Moving average filter setup
const int FILTER_SIZE = 16;
int32_t filterBuffer[FILTER_SIZE];
int filterIndex = 0;

unsigned long lastPlotTime = 0;
const unsigned long PLOT_INTERVAL = 50;

float lastInput = 0;  // For DC offset removal

// Global variables for PulseOx and ECG
TFT_eSPI tft = TFT_eSPI();
MAX30105 particleSensor;

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

//-----------TOUCH SCREEN-------------
#define CALIBRATION_FILE "/TouchCalData2"
#define REPEAT_CAL false

// ECG graph settings
#define GRAPH_WIDTH 720
#define GRAPH_HEIGHT 275
#define GRAPH_X_OFFSET 0
#define ECG_GRAPH_HEIGHT 200  // Reduced height for ECG
#define ECG_GRAPH_Y_OFFSET 50 // Y offset for ECG graph

// Button dimensions
#define KEY_W 160
#define KEY_H 60
#define KEY_SPACING_Y 30
#define KEY_TEXTSIZE 2

// Button Labels
char keyLabel[5][15] = {"ECG", "Pulse OX", "Bluetooth", "Back", "Save"};
uint16_t keyColor[5] = {TFT_BLUE, TFT_GREEN, TFT_CYAN, TFT_RED, TFT_PURPLE};

// Button Objects
TFT_eSPI_Button key[5];

// Global State
bool onHomeScreen = true;
bool onBluetoothScreen = false;
bool isMeasuring = false;
bool readingsStabilized = false; 
bool onPulseOxScreen = false;
unsigned long measureStartTime = 0;
const int MEASURE_DURATION = 3000; // 3 seconds
int measurements = 0;
float tempSum = 0, bpmSum = 0, spo2Sum = 0;
bool needToShowHome = false;
unsigned long connectionTime = 0;
const unsigned long SHOW_CONNECTION_TIME = 2000; // 2 seconds

int xPos = GRAPH_X_OFFSET;
int prevGraphY = -1;

// BLE Global Variables for PulseOx and ECG
BLECharacteristic* pPulseOxCharacteristic = nullptr;
BLECharacteristic* pECGCharacteristic = nullptr;
bool isTransmitting = false;

// BLE Data Structures
struct PulseOxData {
    float heartRate;
    float spO2;
    float temperature;
} __attribute__((packed));

struct ECGData {
    int16_t value;
    uint32_t timestamp;
} __attribute__((packed));

enum MeasurementState {
    IDLE,
    COUNTDOWN,
    MEASURING,
    COMPLETE
};

MeasurementState measureState = IDLE;
unsigned long countdownStart = 0;
const int COUNTDOWN_DURATION = 3000; // 3 seconds countdown
const int MEASUREMENT_DURATION = 3000; // 3 seconds measurement

float bandPassFilter(float input) {
    // DC offset removal
    float highpassed = input - lastInput;
    lastInput = input;
    
    // Apply noise gate with hysteresis
    if(abs(highpassed) < NOISE_THRESHOLD) {
        return 0;
    }
    
    // Apply input gain
    highpassed *= INPUT_GAIN;
    
    // Shift the input buffer
    for(int i = FILTER_ORDER; i > 0; i--) {
        x[i] = x[i-1];
    }
    x[0] = highpassed;
    
    // Apply low-pass filter
    float output = 0;
    for(int i = 0; i <= FILTER_ORDER; i++) {
        output += b[i] * x[i];
    }
    
    // Apply post-filter gain
    output *= POST_FILTER_GAIN;
    
    // Soft clipping
    if(output > 32767) {
        output = 32767 * tanh(output/32767);
    } else if(output < -32767) {
        output = -32767 * tanh(output/-32767);
    }
    
    return output;
}

void processAudioBuffer(int16_t* buffer, size_t length) {
    // Calculate signal metrics
    float sumSquares = 0;
    int zeroCrossings = 0;
    int16_t lastSample = buffer[0];
    float avgNoise = 0;
    
    // First pass: calculate metrics
    for(size_t i = 1; i < length; i++) {
    if ((lastSample < 0 && buffer[i] >= 0) || 
        (lastSample >= 0 && buffer[i] < 0)) {
        zeroCrossings++;
    }
    lastSample = buffer[i];

        
        avgNoise += abs(buffer[i]);
        sumSquares += buffer[i] * buffer[i];
    }
    avgNoise /= length;
    
    // Calculate frequency and RMS
    float dominantFreq = (float)zeroCrossings * SAMPLE_RATE / (2 * length);
    float rmsLevel = sqrt(sumSquares / length);
    
    // Process if signal is significant
   if(avgNoise > NOISE_THRESHOLD && rmsLevel > NOISE_THRESHOLD) {
        static float lastFilteredValue = 0;
        
        for(size_t i = 0; i < length; i++) {
            float sample = (float)buffer[i];
            float filtered = bandPassFilter(sample);
            
            // Smooth transitions
            filtered = 0.7 * filtered + 0.3 * lastFilteredValue;
            lastFilteredValue = filtered;
            
            buffer[i] = (int16_t)filtered;
        }
        
        // Print frequency debug info periodically
        if(millis() % 1000 < 50) {
            Serial.printf("Detected Frequency: %.1f Hz, RMS Level: %.1f\n", 
                        dominantFreq, rmsLevel);
        }
    } else {
        // Zero out buffer if signal is too weak
        memset(buffer, 0, length * sizeof(int16_t));
    }
}

float movingAverage(int32_t newValue) {
    filterBuffer[filterIndex] = newValue;
    filterIndex = (filterIndex + 1) % FILTER_SIZE;
    
    int32_t sum = 0;
    for (int i = 0; i < FILTER_SIZE; i++) {
        sum += filterBuffer[i];
    }
    return (float)sum / FILTER_SIZE;
}

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Client Connected!");
    };

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        isRecording = false;
        isTransmitting = false;
        Serial.println("Client Disconnected!");
        pServer->getAdvertising()->start();
    }
};

class ControlCallback : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        uint8_t* data = pCharacteristic->getData();
        size_t length = pCharacteristic->getValue().length();
        if (length > 0) {
            uint8_t command = data[0];
            if (command == 0x01) {
                isRecording = true;
                Serial.println("Recording Started");
            } else if (command == 0x00) {
                isRecording = false;
                Serial.println("Recording Stopped");
            }
        }
    }
};

void setup() {
    Serial.begin(115200);
    Wire.setClock(400000);

    // Initialize TFT display
    tft.init();
    tft.setRotation(1);
    touch_calibrate();
    showHomeScreen();

    // Initialize MAX30102 sensor
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

    // Initialize ECG pins
    pinMode(ECG_PIN, INPUT);
    pinMode(LO_PLUS_PIN, INPUT);
    pinMode(LO_MINUS_PIN, INPUT);

    // Initialize BLE
    BLEDevice::init("ESP32_Heart");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);
    pAudioCharacteristic = pService->createCharacteristic(
        BLEUUID(AUDIO_CHAR_UUID),
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pAudioCharacteristic->addDescriptor(new BLE2902());

    pControlCharacteristic = pService->createCharacteristic(
        BLEUUID(CONTROL_CHAR_UUID),
        BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_WRITE_NR |
        BLECharacteristic::PROPERTY_READ
    );
    pControlCharacteristic->setCallbacks(new ControlCallback());
    pControlCharacteristic->addDescriptor(new BLE2902());

    pPulseOxCharacteristic = pService->createCharacteristic(
        BLEUUID(PULSEOX_CHAR_UUID),
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pPulseOxCharacteristic->addDescriptor(new BLE2902());

    pECGCharacteristic = pService->createCharacteristic(
        BLEUUID(ECG_CHAR_UUID),
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pECGCharacteristic->addDescriptor(new BLE2902());

    pService->start();
    BLEAdvertising* pAdvertising = pServer->getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    pAdvertising->start();

    Serial.println("BLE initialized and advertising...");

    // Initialize microphone with retries
    int retryCount = 0;
    while (microphone.begin(SAMPLE_RATE, DATA_BIT) != 0 && retryCount < 5) {
        Serial.printf("Microphone init failed, retry %d/5...\n", retryCount + 1);
        delay(1000);
        retryCount++;
    }

    if (retryCount >= 5) {
        Serial.println("Failed to initialize microphone!");
        return;
    }
    Serial.println("Microphone initialized successfully");

    // Initialize filter buffers
    for(int i = 0; i <= FILTER_ORDER; i++) {
        x[i] = 0;
        y[i] = 0;
    }

    // Initialize moving average filter buffer
    for (int i = 0; i < FILTER_SIZE; i++) {
        filterBuffer[i] = 0;
    }
}

void loop() {
    // Handle MEMS microphone recording
    if (deviceConnected && isRecording) {
        int bytesRead = microphone.read((char*)i2sReadrawBuff, BUFFER_SIZE * sizeof(int16_t));

        if (bytesRead > 0) {
            processAudioBuffer(i2sReadrawBuff, BUFFER_SIZE);
            pAudioCharacteristic->setValue((uint8_t*)i2sReadrawBuff, bytesRead);
            pAudioCharacteristic->notify();
        }
        delay(10);
    } else {
        delay(100);
    }

    // Handle PulseOx and ECG measurements
    uint16_t t_x = 0, t_y = 0;
    bool pressed = tft.getTouch(&t_x, &t_y);

    if (measureState != IDLE) {
        if (onPulseOxScreen) {
            handleMeasurementProcess();
        } else if (!onHomeScreen && !onBluetoothScreen && !onPulseOxScreen) {
            handleECGMeasurement();
        }
    }

    // Button handling for PulseOx and ECG
    if (pressed) {
        for (uint8_t b = 0; b < 5; b++) {
            if (key[b].contains(t_x, t_y)) {
                key[b].press(true);
                if (b == 0 && onHomeScreen) {
                    showECGScreen();
                    break;
                } else if (b == 1 && onHomeScreen) {
                    showPulseOxScreen();
                    break;
                } else if (b == 2 && onHomeScreen) {
                    showBluetoothScreen();
                    break;
                } else if (b == 3 && !onHomeScreen) {
                    showHomeScreen();
                    break;
                } else if (b == 4 && !onHomeScreen && measureState == IDLE) {
                    startMeasurement();
                    break;
                }
            } else {
                key[b].press(false);
            }
        }
    } else {
        for (uint8_t b = 0; b < 5; b++) {
            key[b].press(false);
        }
    }

    // PulseOx Processing
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

                float temperature = particleSensor.readTemperature();

                if (!onHomeScreen && !onBluetoothScreen && measureState == IDLE && onPulseOxScreen) {
                    static unsigned long lastMainDisplayUpdate = 0;
                    const unsigned long MAIN_DISPLAY_UPDATE_INTERVAL = 500;

                    if (millis() - lastMainDisplayUpdate >= MAIN_DISPLAY_UPDATE_INTERVAL) {
                        lastMainDisplayUpdate = millis();
                        tft.setTextColor(TFT_GREEN, TFT_BLACK);
                        
                        tft.fillRect(180, 60, 160, 25, TFT_BLACK);
                        tft.setCursor(180, 60);
                        tft.printf("%.1f BPM", beatAvg);

                        tft.fillRect(180, 100, 160, 25, TFT_BLACK);
                        tft.setCursor(180, 100);
                        tft.printf("%.1f %%", ESpO2);

                        tft.fillRect(180, 140, 160, 25, TFT_BLACK);
                        tft.setCursor(180, 140);
                        tft.printf("%.1f C", temperature);
                    }
                }

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
    }

    // ECG Monitoring
    if (!onHomeScreen && !onBluetoothScreen && !onPulseOxScreen) {
        bool loPlusStatus = digitalRead(LO_PLUS_PIN);
        bool loMinusStatus = digitalRead(LO_MINUS_PIN);

        if (!loPlusStatus && !loMinusStatus) {
            int ecgValue = analogRead(ECG_PIN);
            Serial.printf("ECG Value: %d\n", ecgValue);

            int graphY = map(ecgValue, 0, 4095, 
                            ECG_GRAPH_Y_OFFSET + ECG_GRAPH_HEIGHT, 
                            ECG_GRAPH_Y_OFFSET);

            if (xPos == GRAPH_X_OFFSET) {
                tft.fillRect(GRAPH_X_OFFSET + 1, ECG_GRAPH_Y_OFFSET + 1, 
                            GRAPH_WIDTH - 2, ECG_GRAPH_HEIGHT - 2, TFT_BLACK);
                prevGraphY = -1;
            }

            if (prevGraphY != -1) {
                tft.drawLine(xPos - 1, prevGraphY, xPos, graphY, TFT_GREEN);
                tft.drawLine(xPos - 1, prevGraphY + 1, xPos, graphY + 1, TFT_GREEN);
            }

            prevGraphY = graphY;

            xPos++;
            if (xPos >= GRAPH_X_OFFSET + GRAPH_WIDTH) {
                xPos = GRAPH_X_OFFSET;
            }
        }
    }
}
void transmitPulseOxData(float heartRate, float spO2, float temperature) {
    if (deviceConnected && isTransmitting) {
        PulseOxData data = {
            .heartRate = heartRate,
            .spO2 = spO2,
            .temperature = temperature
        };
        pPulseOxCharacteristic->setValue((uint8_t*)&data, sizeof(PulseOxData));
        pPulseOxCharacteristic->notify();
        Serial.println("Data transmitted via BLE");
    }
}

void transmitECGData(int16_t ecgValue) {
    if (deviceConnected) {
        ECGData data = {
            .value = ecgValue,
            .timestamp = millis()
        };
        pECGCharacteristic->setValue((uint8_t*)&data, sizeof(ECGData));
        pECGCharacteristic->notify();
    }
}

void startMeasurement() {
    measureState = COUNTDOWN;
    readingsStabilized = false;  // Make sure to reset this
    key[4].drawButton(false, "Stabilizing");
}

void handleMeasurementProcess() {
    static unsigned long lastDisplayUpdate = 0;
    const unsigned long DISPLAY_UPDATE_INTERVAL = 500;

    if (measureState == COUNTDOWN) {
        if (!readingsStabilized) {
            // Show "Stabilizing..." and wait for valid readings
            key[4].drawButton(false, "Stabilizing");
            
            if (beatAvg > 0 && ESpO2 > 50) {
                readingsStabilized = true;
                countdownStart = millis();  // Start countdown only after stabilization
                Serial.println("Readings stabilized, starting countdown...");
            }
        } else {
            // Only start countdown after stabilization
            unsigned long elapsed = millis() - countdownStart;
            int timeLeft = 3 - (elapsed / 1000);
            
            static int lastTimeLeft = -1;
            if (timeLeft != lastTimeLeft && timeLeft >= 0) {
                lastTimeLeft = timeLeft;
                char countText[10];
                sprintf(countText, "%d", timeLeft + 1);
                key[4].drawButton(false, countText);
                Serial.printf("Countdown: %d\n", timeLeft + 1);
            }
            
            if (elapsed >= 3000) {
                measureState = MEASURING;
                measureStartTime = millis();
                measurements = 0;
                tempSum = bpmSum = spo2Sum = 0;
                key[4].drawButton(false, "Measuring");
                Serial.println("Starting measurement...");
                lastTimeLeft = -1;
            }
        }
    }
    else if (measureState == MEASURING) {
        unsigned long elapsed = millis() - measureStartTime;
        
        if (elapsed < MEASUREMENT_DURATION) {
            // Update display less frequently
            if (millis() - lastDisplayUpdate >= DISPLAY_UPDATE_INTERVAL) {
                lastDisplayUpdate = millis();
                int secondsLeft = (MEASUREMENT_DURATION - elapsed) / 1000;
                
                // Update display during measurement
                tft.setTextColor(TFT_GREEN, TFT_BLACK);
 
                tft.fillRect(180, 60, 160, 25, TFT_BLACK);
                tft.setCursor(180, 60);
                tft.printf("%.1f BPM", beatAvg);

                tft.fillRect(180, 100, 160, 25, TFT_BLACK);
                tft.setCursor(180, 100);
                tft.printf("%.1f %%", ESpO2);

                tft.fillRect(180, 140, 160, 25, TFT_BLACK);
                tft.setCursor(180, 140);
                tft.printf("%.1f C", particleSensor.readTemperature());

                Serial.printf("Measuring - Time Left: %d sec, Current Values - BPM: %.1f, SpO2: %.1f\n", 
                    secondsLeft, beatAvg, ESpO2);
            }

            if (beatAvg > 0 && ESpO2 > 50) {
                bpmSum += beatAvg;
                spo2Sum += ESpO2;
                tempSum += particleSensor.readTemperature();
                measurements++;
            }
        } else {
            if (measurements > 0) {
                float finalBPM = bpmSum / measurements;
                float finalSpO2 = spo2Sum / measurements;
                float finalTemp = tempSum / measurements;
                
                Serial.printf("Final Values - BPM: %.1f, SpO2: %.1f, Temp: %.1f\n", 
                    finalBPM, finalSpO2, finalTemp);

                if (deviceConnected) {
                    isTransmitting = true;
                    transmitPulseOxData(finalBPM, finalSpO2, finalTemp);
                    isTransmitting = false;
                    key[4].drawButton(false, "Saved!");
                    Serial.println("Data successfully transmitted via Bluetooth");
                } else {
                    key[4].drawButton(false, "No BT!");
                    Serial.println("Measurement complete but no Bluetooth connection");
                }
            } else {
                key[4].drawButton(false, "Failed!");
                Serial.println("Measurement failed - no valid readings");
            }
            
            delay(2000);
            key[4].drawButton(false, "Save");
            readingsStabilized = false;  // Reset for next measurement
            Serial.println("Ready for next measurement");
            measureState = IDLE;
        }
    }
}

void handleECGMeasurement() {
    static unsigned long measurementStartTime = 0;
    static int countdown = 3;
    static unsigned long lastCountUpdate = 0;
    const int MEASUREMENT_DURATION = 5000; // 5 seconds
    static bool isTransmitting = false;  // Add transmission state
    
    bool loPlusStatus = digitalRead(LO_PLUS_PIN);
    bool loMinusStatus = digitalRead(LO_MINUS_PIN);
    bool isConnected = !loPlusStatus && !loMinusStatus;

    // Update connection status in top right
    static unsigned long lastStatusUpdate = 0;
    if (millis() - lastStatusUpdate >= 1000) {
        lastStatusUpdate = millis();
        tft.setTextSize(2);
        tft.setTextDatum(TR_DATUM);
        tft.fillRect(tft.width() - 150, 10, 140, 30, TFT_BLACK);
        tft.setTextColor(isConnected ? TFT_GREEN : TFT_RED);
        tft.drawString(isConnected ? "Connected" : "Disconnected", 
                      tft.width() - 10, 25);
    }

    if (measureState == COUNTDOWN) {
        isTransmitting = false;  // Reset transmission state
        if (!isConnected) {
            key[4].drawButton(false, "No Signal");
            measureState = IDLE;
            return;
        }

        if (millis() - lastCountUpdate >= 1000) {
            lastCountUpdate = millis();
            if (countdown > 0) {
                char countStr[3];
                sprintf(countStr, "%d", countdown);
                key[4].drawButton(false, countStr);
                countdown--;
            } else {
                measureState = MEASURING;
                measurementStartTime = millis();
                key[4].drawButton(false, "Recording");
                isTransmitting = true;  // Start transmission
                Serial.println("Started ECG Recording Session");
            }
        }
    }
    else if (measureState == MEASURING) {
        if (!isConnected) {
            key[4].drawButton(false, "Failed!");
            measureState = IDLE;
            countdown = 3;
            isTransmitting = false;
            Serial.println("ECG Recording Failed - Lost Connection");
            return;
        }

        unsigned long elapsed = millis() - measurementStartTime;
        if (elapsed < MEASUREMENT_DURATION) {
            if (isTransmitting) {
                int ecgValue = analogRead(ECG_PIN);
                transmitECGData(ecgValue);
                Serial.printf("Recording ECG Value: %d (Time: %lu ms)\n", ecgValue, elapsed);
            }
        } else {
            // Measurement complete
            isTransmitting = false;
            if (deviceConnected) {
                key[4].drawButton(false, "Sent!");
                Serial.println("ECG Recording Session Complete - Data Sent");
            } else {
                key[4].drawButton(false, "No BT!");
                Serial.println("ECG Recording Session Complete - No Bluetooth Connection");
            }
            delay(1000);
            key[4].drawButton(false, "Save");
            measureState = IDLE;
            countdown = 3;
        }
    }
}
void showHomeScreen() {
    clearAllButtons();
    onHomeScreen = true;
    onBluetoothScreen = false;
    measureState = IDLE;
    
    tft.fillScreen(TFT_BLACK);
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(3);
    tft.setTextDatum(MC_DATUM);
    tft.drawString("Welcome to RespiRhythm", tft.width() / 2, 40);
    
    // Draw only home screen buttons
    key[0].initButton(&tft, 80, 100, KEY_W, KEY_H, TFT_WHITE, keyColor[0], TFT_WHITE, keyLabel[0], KEY_TEXTSIZE); // ECG
    key[0].drawButton();
    
    key[1].initButton(&tft, 80, 170, KEY_W, KEY_H, TFT_WHITE, keyColor[1], TFT_WHITE, keyLabel[1], KEY_TEXTSIZE); // PulseOx
    key[1].drawButton();
    
    key[2].initButton(&tft, 80, 240, KEY_W, KEY_H, TFT_WHITE, keyColor[2], TFT_WHITE, keyLabel[2], KEY_TEXTSIZE); // Bluetooth
    key[2].drawButton();
}

void showECGScreen() {
    clearAllButtons();
    onHomeScreen = false;
    onBluetoothScreen = false;
    onPulseOxScreen = false;
    xPos = GRAPH_X_OFFSET;
    prevGraphY = -1;
    
    tft.fillScreen(TFT_BLACK);
    
    // Title - moved to left side to make room for status
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(3);
    tft.setTextDatum(TL_DATUM);
    tft.drawString("ECG", 20, 20);
    
    // Status area in top right
    tft.setTextSize(2);
    tft.setTextDatum(TR_DATUM);
    tft.setTextColor(TFT_RED);
    tft.drawString("Disconnected", tft.width() - 10, 25);
    
    // Adjust graph dimensions to make room for buttons
    #define GRAPH_BOTTOM_MARGIN 80
    int availableHeight = tft.height() - ECG_GRAPH_Y_OFFSET - GRAPH_BOTTOM_MARGIN;
    
    // Draw graph border with adjusted height
    tft.drawRect(GRAPH_X_OFFSET, ECG_GRAPH_Y_OFFSET, 
                 GRAPH_WIDTH, availableHeight, TFT_WHITE);
    
    // Initialize buttons with proper spacing
    key[3].initButton(&tft, 
                      tft.width() - (KEY_W/2 + 10),
                      tft.height() - (KEY_H/2 + 10),
                      KEY_W, KEY_H,
                      TFT_WHITE, keyColor[3], TFT_WHITE, 
                      keyLabel[3], KEY_TEXTSIZE);
    
    key[4].initButton(&tft, 
                      tft.width() - (KEY_W*2 + 20),
                      tft.height() - (KEY_H/2 + 10),
                      KEY_W, KEY_H,
                      TFT_WHITE, keyColor[4], TFT_WHITE, 
                      keyLabel[4], KEY_TEXTSIZE);
    
    key[3].drawButton();
    key[4].drawButton();
}

void showPulseOxScreen() {
    // Clear everything first
    tft.fillScreen(TFT_BLACK);
    clearAllButtons();
    
    // Set states
    onHomeScreen = false;
    onBluetoothScreen = false;
    onPulseOxScreen = true;  // Set Pulse OX screen state to true
    measureState = IDLE;
    
    // Title
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(3);
    tft.setTextDatum(TC_DATUM);
    tft.drawString("Pulse OX", tft.width() / 2, 10);
    
    // Labels and Values - Increased spacing and areas
    tft.setTextSize(2);
    tft.setTextDatum(TL_DATUM);
    
    // Heart Rate
    tft.drawString("Heart Rate:", 20, 60);
    tft.fillRect(180, 60, 160, 25, TFT_BLACK);  // Increased clear area
    tft.setCursor(180, 60);  // Moved value display right
    tft.printf("%.1f BPM", beatAvg);

    // Blood Oxygen - Increased space
    tft.drawString("Blood Oxygen:", 20, 100);
    tft.fillRect(180, 100, 160, 25, TFT_BLACK);  // Increased clear area
    tft.setCursor(180, 100);  // Moved value display right
    tft.printf("%.1f %%", ESpO2);

    // Temperature
    tft.drawString("Body Temp:", 20, 140);
    tft.fillRect(180, 140, 160, 25, TFT_BLACK);  // Increased clear area
    tft.setCursor(180, 140);  // Moved value display right
    tft.printf("%.1f C", particleSensor.readTemperature());

    // Buttons at the bottom
    key[4].initButton(&tft, tft.width()/2 - KEY_W/2 - 10, tft.height() - KEY_H - 20, 
                      KEY_W, KEY_H, TFT_WHITE, keyColor[4], 
                      TFT_WHITE, keyLabel[4], KEY_TEXTSIZE);
    key[4].drawButton();
    
    key[3].initButton(&tft, tft.width()/2 + KEY_W/2 + 10, tft.height() - KEY_H - 20, 
                      KEY_W, KEY_H, TFT_WHITE, keyColor[3], 
                      TFT_WHITE, keyLabel[3], KEY_TEXTSIZE);
    key[3].drawButton();
}

void showBluetoothScreen() {
    // Clear everything first
    tft.fillScreen(TFT_BLACK);
    clearAllButtons();  // Clear all button states
    
    // Set states
    onHomeScreen = false;
    onBluetoothScreen = true;
    measureState = IDLE;  // Reset measurement state
    
    // Draw Bluetooth screen content
    tft.setTextColor(TFT_WHITE);
    tft.setTextSize(2);
    tft.setTextDatum(MC_DATUM);
    
    tft.drawString("Bluetooth Connection", tft.width() / 2, 40);
    
    if (!deviceConnected) {
        tft.drawString("Waiting for connection...", tft.width() / 2, 120);
        tft.drawString("Device name: ESP32_PulseOx", tft.width() / 2, 160);
    } else {
        tft.setTextColor(TFT_GREEN, TFT_BLACK);
        tft.drawString("Device Connected!", tft.width() / 2, 120);
        needToShowHome = true;
        connectionTime = millis();
    }
    
    // Only initialize and draw Back button
    key[3].initButton(&tft, tft.width()/2, tft.height() - KEY_H - 20,  // Centered back button
                      KEY_W, KEY_H, TFT_WHITE, keyColor[3], 
                      TFT_WHITE, keyLabel[3], KEY_TEXTSIZE);
    key[3].drawButton();
}

void drawHomeButtons() {
    key[0].initButton(&tft, 80, 100, KEY_W, KEY_H, TFT_WHITE, keyColor[0], TFT_WHITE, keyLabel[0], KEY_TEXTSIZE);
    key[0].drawButton();

    key[1].initButton(&tft, 80, 170, KEY_W, KEY_H, TFT_WHITE, keyColor[1], TFT_WHITE, keyLabel[1], KEY_TEXTSIZE);
    key[1].drawButton();
    
    key[2].initButton(&tft, 80, 240, KEY_W, KEY_H, TFT_WHITE, keyColor[2], TFT_WHITE, keyLabel[2], KEY_TEXTSIZE);
    key[2].drawButton();
}

void drawBackButton() {
    key[3].initButton(&tft, tft.width() - KEY_W - 20, tft.height() - KEY_H - 20, 
                      KEY_W, KEY_H, TFT_WHITE, keyColor[3], TFT_WHITE, keyLabel[3], KEY_TEXTSIZE);
    key[3].drawButton();
}

void clearAllButtons() {
    for (int i = 0; i < 5; i++) {
        key[i].press(false);
        key[i] = TFT_eSPI_Button(); // Reset button completely
    }
}

void touch_calibrate() {
    uint16_t calData[5];
    uint8_t calDataOK = 0;

    if (!SPIFFS.begin()) {
        Serial.println("Formatting file system...");
        SPIFFS.format();
        SPIFFS.begin();
    }

    if (SPIFFS.exists(CALIBRATION_FILE)) {
        if (REPEAT_CAL) {
            SPIFFS.remove(CALIBRATION_FILE);
        } else {
            File f = SPIFFS.open(CALIBRATION_FILE, "r");
            if (f) {
                if (f.readBytes((char *)calData, 14) == 14)
                    calDataOK = 1;
                f.close();
            }
        }
    }

    if (calDataOK && !REPEAT_CAL) {
        tft.setTouch(calData);
    } else {
        tft.fillScreen(TFT_BLACK);
        tft.setCursor(20, 0);
        tft.setTextFont(2);
        tft.setTextSize(1);
        tft.setTextColor(TFT_WHITE, TFT_BLACK);

        tft.println("Touch corners as indicated");
        tft.setTextFont(1);
        tft.println();

        if (REPEAT_CAL) {
            tft.setTextColor(TFT_RED, TFT_BLACK);
            tft.println("Set REPEAT_CAL to false to stop this running again!");
        }

        tft.calibrateTouch(calData, TFT_MAGENTA, TFT_BLACK, 15);

        tft.setTextColor(TFT_GREEN, TFT_BLACK);
        tft.println("Calibration complete!");

        File f = SPIFFS.open(CALIBRATION_FILE, "w");
        if (f) {
            f.write((const unsigned char *)calData, 14);
            f.close();
        }
    }
}