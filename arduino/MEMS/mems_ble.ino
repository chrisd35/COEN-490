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

// BLE Configuration
#define SERVICE_UUID        "19B10000-E8F2-537E-4F6C-D104768A1214"
#define AUDIO_CHAR_UUID    "19B10001-E8F2-537E-4F6C-D104768A1214"
#define CONTROL_CHAR_UUID  "19B10002-E8F2-537E-4F6C-D104768A1214"

BLEServer* pServer = nullptr;
BLEService* pService = nullptr;
BLECharacteristic* pAudioCharacteristic = nullptr;
BLECharacteristic* pControlCharacteristic = nullptr;

DFRobot_Microphone microphone(I2S_SCK_IO, I2S_WS_IO, I2S_DI_IO);
int16_t i2sReadrawBuff[BUFFER_SIZE];
bool deviceConnected = false;
bool isRecording = false;

class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        Serial.println("[BLE] Device connected");
        deviceConnected = true;
    }
    void onDisconnect(BLEServer* pServer) {
        Serial.println("[BLE] Device disconnected, restarting advertising");
        deviceConnected = false;
        isRecording = false;
        pServer->getAdvertising()->start();
    }
};

class ControlCallback : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        uint8_t* data = pCharacteristic->getData();
        size_t length = pCharacteristic->getValue().length();
        if (length > 0) {
            uint8_t command = data[0];
            isRecording = (command == 0x01);
            Serial.printf("[BLE] Control command received: %d\n", command);
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("[SYSTEM] Initializing...");

    pinMode(MODE_PIN, OUTPUT);
    digitalWrite(MODE_PIN, LOW);
    
    if (microphone.begin(SAMPLE_RATE, DATA_BIT)) {
        Serial.println("[MIC] Microphone initialized successfully");
    } else {
        Serial.println("[MIC] Microphone initialization failed");
    }

    BLEDevice::init("ESP32_Heart");
    Serial.println("[BLE] BLE Device initialized");
    
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    Serial.println("[BLE] BLE Server created");
    
    pService = pServer->createService(BLEUUID(SERVICE_UUID));
    Serial.println("[BLE] BLE Service created");
    
    pAudioCharacteristic = pService->createCharacteristic(
        BLEUUID(AUDIO_CHAR_UUID),
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pAudioCharacteristic->addDescriptor(new BLE2902());
    Serial.println("[BLE] Audio characteristic created");
    
    pControlCharacteristic = pService->createCharacteristic(
        BLEUUID(CONTROL_CHAR_UUID),
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR | BLECharacteristic::PROPERTY_READ
    );
    pControlCharacteristic->setCallbacks(new ControlCallback());
    pControlCharacteristic->addDescriptor(new BLE2902());
    Serial.println("[BLE] Control characteristic created");

    pService->start();
    Serial.println("[BLE] BLE Service started");
    
    BLEAdvertising* pAdvertising = pServer->getAdvertising();
    pAdvertising->addServiceUUID(BLEUUID(SERVICE_UUID));
    pAdvertising->setScanResponse(true);
    pAdvertising->start();
    Serial.println("[BLE] Advertising started");
}

void loop() {
    if (deviceConnected && isRecording) {
        int bytesRead = microphone.read((char*)i2sReadrawBuff, BUFFER_SIZE * sizeof(int16_t));
        if (bytesRead > 0) {
            pAudioCharacteristic->setValue((uint8_t*)i2sReadrawBuff, bytesRead);
            pAudioCharacteristic->notify();
            Serial.printf("[MIC] Sent %d bytes of audio data\n", bytesRead);
        }
        delay(10);
    } else {
        delay(100);
    }
}
