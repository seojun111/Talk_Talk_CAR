#include <Wire.h>
#include <Adafruit_INA219.h>     // 전압 측정용
#include <SoftwareSerial.h>      // 블루투스 통신용
#include <Servo.h>               // 서보모터 제어용

SoftwareSerial BTSerial(10, 11); // 블루투스 TX=10, RX=11
Adafruit_INA219 ina219;          // 전압 센서 객체
Servo speedServo;                // 속도계 서보모터

// 핀 설정
const int START_LED = 9;         // 시동 상태 표시용 초록 LED
const int SERVO_PIN = 6;         // 속도계 서보모터 핀
const int RED_PIN = 3;           // 연료 RGB - 빨강
const int GREEN_PIN = 4;         // 연료 RGB - 초록
const int BLUE_PIN = 5;          // 연료 RGB - 파랑
const int WARNING_LED = 2;       // 경고등 (파랑 LED)
const int SPEAKER = 7;           // 문 위치 알림용 스피커
const int TRIG_PIN = 12;         // 초음파 센서 트리거
const int ECHO_PIN = 13;         // 초음파 센서 에코
const int VIBRATION_SENSOR = A1; // 진동 센서

// 상태 변수
bool engineOn = false;
bool doorOpen = false;
int speedKmh = 0;
unsigned long lastBeepTime = 0;
bool speakerState = false;

void setup() {
  // 핀 모드 설정
  pinMode(START_LED, OUTPUT);
  pinMode(RED_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
  pinMode(WARNING_LED, OUTPUT);
  pinMode(SPEAKER, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(VIBRATION_SENSOR, INPUT);

  Serial.begin(9600);       // USB 시리얼 통신 시작
  BTSerial.begin(9600);     // 블루투스 시리얼 통신 시작
  speedServo.attach(SERVO_PIN);

  if (!ina219.begin()) {
    Serial.println("INA219 센서 초기화 실패!");
    while (1); // 전압 센서 없으면 무한 루프
  }
}

// 시동 제어
void controlEngine(bool state) {
  engineOn = state;
  digitalWrite(START_LED, state ? HIGH : LOW);
}

// 문 열기/닫기 및 스피커 제어
void notifyDoor(bool open) {
  doorOpen = open;
  lastBeepTime = millis();
  speakerState = false;

  if (!open) {
    digitalWrite(SPEAKER, LOW); // 문 닫히면 스피커 꺼짐
  }
}

// 연료 상태 RGB LED 표시 + 연료 전압 전송
void updateFuelLED() {
  float voltage = ina219.getBusVoltage_V();

  // RGB LED로 연료 상태 표시
  if (voltage > 7.0) {
    digitalWrite(RED_PIN, LOW);
    digitalWrite(GREEN_PIN, HIGH);
    digitalWrite(BLUE_PIN, LOW);
  } else if (voltage > 6.5) {
    digitalWrite(RED_PIN, HIGH);
    digitalWrite(GREEN_PIN, HIGH);
    digitalWrite(BLUE_PIN, LOW);
  } else {
    digitalWrite(RED_PIN, HIGH);
    digitalWrite(GREEN_PIN, LOW);
    digitalWrite(BLUE_PIN, LOW);
  }

  Serial.println(voltage, 1);    // USB 시리얼로 전압 전송
  BTSerial.println(voltage, 1);  // 블루투스로도 전압 전송 (필요 시)
}

// 충격 또는 초근접 거리 감지
void checkWarnings() {
  bool shock = analogRead(VIBRATION_SENSOR) < 100;
  digitalWrite(WARNING_LED, LOW);

  // 초음파 거리 측정
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH);
  int distance = duration * 0.034 / 2; // cm 단위

  if (shock || distance < 20) {
    digitalWrite(WARNING_LED, HIGH);

    // ★ 충돌 감지 메시지 추가
    BTSerial.println("충돌 감지됨");
    Serial.println("충돌 감지됨");
    delay(1000); // 1초 딜레이로 중복 전송 방지
  }
}

// 문 열렸을 때 삐삐삐 반복 소리 출력
void doorSpeakerBeep() {
  if (doorOpen) {
    unsigned long now = millis();
    if (now - lastBeepTime >= 500) { // 0.5초마다 ON/OFF
      speakerState = !speakerState;
      digitalWrite(SPEAKER, speakerState ? HIGH : LOW);
      lastBeepTime = now;
    }
  }
}

// 속도에 따라 서보모터 각도 제어
void updateSpeedServo(int speed) {
  speed = constrain(speed, 0, 120);
  int angle = map(speed, 0, 120, 0, 180);
  speedServo.write(angle);
}

// 블루투스 또는 USB 명령 처리
void processCommand(String cmd) {
  cmd.trim();

  if (cmd == "0") controlEngine(true);            // 시동 ON
  else if (cmd == "1") controlEngine(false);       // 시동 OFF
  else if (cmd == "B") notifyDoor(true);           // 문 열림
  else if (cmd == "b") notifyDoor(false);          // 문 닫힘
  else if (cmd == "C") updateFuelLED();            // 연료 전압 요청
  else if (cmd.startsWith("S")) {                  // 속도 설정
    int speed = cmd.substring(1).toInt();
    updateSpeedServo(speed);
  }
}

void loop() {
  // 충돌 감지, 스피커 제어 등
  checkWarnings();
  doorSpeakerBeep();

  // 연료 전압 측정 전송
  updateFuelLED();   // 이 함수 안에서 voltage를 Serial.println 해야 함

  // 명령 수신 처리
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    processCommand(cmd);
  }

  if (BTSerial.available()) {
    String cmd = BTSerial.readStringUntil('\n');
    processCommand(cmd);
  }

  delay(1000); // 너무 자주 전송하지 않도록
}

