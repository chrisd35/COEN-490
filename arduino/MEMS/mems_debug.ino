#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "DFrobot_MSM261.h"

// Microphone Configuration
#define SAMPLE_RATE (4000)
#define I2S_SCK_IO (12)
#define I2S_WS_IO (15)
#define I2S_DI_IO (32)
#define DATA_BIT (16)
#define MODE_PIN (33)
#define BUFFER_SIZE 256

// Filter Configuration
#define FILTER_ORDER 4
#define PI 3.14159265359

// BLE Configuration
#define SERVICE_UUID        "19B10000-E8F2-537E-4F6C-D104768A1214"
#define AUDIO_CHAR_UUID    "19B10001-E8F2-537E-4F6C-D104768A1214"
#define CONTROL_CHAR_UUID  "19B10002-E8F2-537E-4F6C-D104768A1214"

// Gain and Noise Configuration
const float INPUT_GAIN = 2.0;
const float POST_FILTER_GAIN = 1.5;
const float NOISE_THRESHOLD = 10.0;

// Modified coefficients for better low-frequency response
float b[FILTER_ORDER + 1] = {0.3, 0.25, 0.2, 0.15, 0.1};
float x[FILTER_ORDER + 1] = {0};  // Input buffer
float y[FILTER_ORDER + 1] = {0};  // Output buffer

// Global variables
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

class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Client Connected!");
    }

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        isRecording = false;
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
    Serial.println("Starting Heart Murmur Detection Device...");

    // Configure microphone
    pinMode(MODE_PIN, OUTPUT);
    digitalWrite(MODE_PIN, LOW);

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

    // Initialize BLE
    Serial.println("Initializing BLE...");
    BLEDevice::init("ESP32_Heart");
    delay(100);
    
    Serial.println("Creating BLE Server...");
    pServer = BLEDevice::createServer();
    if (pServer == nullptr) {
        Serial.println("Failed to create BLE server!");
        return;
    }
    pServer->setCallbacks(new MyServerCallbacks());
    delay(100);
    
    Serial.println("Creating BLE Service...");
    pService = pServer->createService(BLEUUID(SERVICE_UUID), 30);
    if (pService == nullptr) {
        Serial.println("Failed to create BLE service!");
        return;
    }
    Serial.println("Service created with 30 handles");
    delay(100);
    
    Serial.println("Creating Audio characteristic...");
    pAudioCharacteristic = pService->createCharacteristic(
        BLEUUID(AUDIO_CHAR_UUID),
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    if (pAudioCharacteristic == nullptr) {
        Serial.println("Failed to create Audio characteristic!");
        return;
    }
    BLE2902* descriptor = new BLE2902();
    pAudioCharacteristic->addDescriptor(descriptor);
    Serial.println("Audio characteristic created successfully");
    delay(100);
    
    Serial.println("Creating Control characteristic...");
    pControlCharacteristic = pService->createCharacteristic(
        BLEUUID(CONTROL_CHAR_UUID),
        BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_WRITE_NR |
        BLECharacteristic::PROPERTY_READ
    );
    if (pControlCharacteristic == nullptr) {
        Serial.println("Failed to create Control characteristic!");
        return;
    }
    pControlCharacteristic->setCallbacks(new ControlCallback());
    BLE2902* controlDescriptor = new BLE2902();
    pControlCharacteristic->addDescriptor(controlDescriptor);
    Serial.println("Control characteristic created successfully");
    delay(100);
    
    Serial.println("Starting service...");
    pService->start();
    delay(200);
    Serial.println("Service started successfully");

    // Start advertising
    BLEAdvertising* pAdvertising = pServer->getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    
    Serial.println("Starting advertising...");
    pAdvertising->start();
    delay(100);
    Serial.println("BLE ready - Advertising started");

    // Print final configuration
    Serial.println("Final Configuration:");
    Serial.printf("Sample Rate: %d Hz\n", SAMPLE_RATE);
    Serial.printf("Filter Order: %d\n", FILTER_ORDER);
    Serial.printf("Buffer Size: %d\n", BUFFER_SIZE);
    Serial.printf("Input Gain: %.2f\n", INPUT_GAIN);
    Serial.printf("Post-Filter Gain: %.2f\n", POST_FILTER_GAIN);
    Serial.printf("Noise Threshold: %.2f\n", NOISE_THRESHOLD);
}

void loop() {
    if (deviceConnected && isRecording) {
        int bytesRead = microphone.read((char*)i2sReadrawBuff, BUFFER_SIZE * sizeof(int16_t));

        if (bytesRead > 0) {
            // Calculate raw signal metrics
            int16_t rawMax = -32768;
            int16_t rawMin = 32767;
            float rawRms = 0;
            
            for (int i = 0; i < BUFFER_SIZE; i++) {
                rawMax = max(rawMax, i2sReadrawBuff[i]);
                rawMin = min(rawMin, i2sReadrawBuff[i]);
                rawRms += (float)i2sReadrawBuff[i] * i2sReadrawBuff[i];
            }
            rawRms = sqrt(rawRms / BUFFER_SIZE);

            // Process audio
            processAudioBuffer(i2sReadrawBuff, BUFFER_SIZE);

            // Send processed data
            pAudioCharacteristic->setValue((uint8_t*)i2sReadrawBuff, bytesRead);
            pAudioCharacteristic->notify();

            // Monitor signal levels
            if (millis() - lastPlotTime >= PLOT_INTERVAL) {
                lastPlotTime = millis();
                
                int16_t maxVal = -32768;
                int16_t minVal = 32767;
                float avgVal = 0;
                float rms = 0;
                float peak_to_peak = 0;

                for (int i = 0; i < BUFFER_SIZE; i++) {
                    int16_t val = i2sReadrawBuff[i];
                    maxVal = max(maxVal, val);
                    minVal = min(minVal, val);
                    avgVal += val;
                    rms += (float)val * val;
                }
                avgVal /= BUFFER_SIZE;
                rms = sqrt(rms / BUFFER_SIZE);
                peak_to_peak = maxVal - minVal;
                float smoothedAvg = movingAverage(avgVal);

                Serial.printf("Raw RMS: %.2f, Processed - Min: %d, Max: %d, Avg: %.2f, RMS: %.2f, P2P: %.2f\n", 
                    rawRms, minVal, maxVal, avgVal, rms, peak_to_peak);
            }
        }
        delay(10);
    } else {
        delay(100);
    }
}