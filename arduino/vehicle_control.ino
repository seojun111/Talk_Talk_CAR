#include <SoftwareSerial.h>
#include <Servo.h>

SoftwareSerial BTSerial(10, 11);  // HC-06 Bluetooth
Servo speedServo;

const int START_LED = 9;
const int SERVO_PIN = 6;
const int RED_PIN = 3;
const int GREEN_PIN = 4;
const int BLUE_PIN = 5;
const int WARNING_LED = 2;
const int SPEAKER = 7;

int batteryPercent = 0;
bool engineOn = false;
bool doorOpen = false;
int currentSpeed = 0;
unsigned long lastMelodyTime = 0;

void setup() {
  pinMode(START_LED, OUTPUT);
  pinMode(RED_PIN, OUTPUT);
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
  pinMode(WARNING_LED, OUTPUT);
  pinMode(SPEAKER, OUTPUT);

  Serial.begin(9600);
  BTSerial.begin(9600);
  speedServo.attach(SERVO_PIN);

  randomSeed(analogRead(0));  // 랜덤 시드 초기화

  Serial.println("시스템 시작됨.");
  updateBatteryLED();
}

void controlEngine(bool state) {
  engineOn = state;
  digitalWrite(START_LED, state ? HIGH : LOW);
  Serial.print("시동 ");
  Serial.println(state ? "ON" : "OFF");
}

void updateBatteryLED() {
  if (batteryPercent >= 60) {
    // 초록
    digitalWrite(RED_PIN, LOW);
    digitalWrite(GREEN_PIN, HIGH);
    digitalWrite(BLUE_PIN, LOW);
  } else if (batteryPercent >= 30) {
    // 노랑 (빨강 + 초록)
    digitalWrite(RED_PIN, HIGH);
    digitalWrite(GREEN_PIN, HIGH);
    digitalWrite(BLUE_PIN, LOW);
  } else {
    // 빨강
    digitalWrite(RED_PIN, HIGH);
    digitalWrite(GREEN_PIN, LOW);
    digitalWrite(BLUE_PIN, LOW);
  }

  BTSerial.print("배터리: ");
  BTSerial.print(batteryPercent);
  BTSerial.println("%");
}


void updateSpeedServo(int speed) {
  currentSpeed = speed;
  speed = constrain(speed, 0, 120);
  int angle = map(speed, 0, 120, 90, 0);
  speedServo.write(angle);
  Serial.print("속도 설정: ");
  Serial.print(speed);
  Serial.print(" km/h → 서보 각도: ");
  Serial.println(angle);
}

void triggerEmergency() {
  Serial.println("🚨 위급 상황 발생");
  BTSerial.println("🚨 위급 상황 발생");

  digitalWrite(WARNING_LED, HIGH);
  tone(SPEAKER, 1000);
  delay(1000);
  noTone(SPEAKER);
  digitalWrite(WARNING_LED, LOW);
}

void playOpenMelody() {
  int melody[] = {262, 294, 330};
  for (int i = 0; i < 3; i++) {
    tone(SPEAKER, melody[i]);
    delay(250);
    noTone(SPEAKER);
    delay(50);
  }
}

void repeatDoorMelody() {
  if (doorOpen && millis() - lastMelodyTime >= 3000) {
    playOpenMelody();
    lastMelodyTime = millis();
  }
}

void notifyDoorOpen() {
  Serial.println("🚪 문 열림");
  BTSerial.println("문 열림");
  doorOpen = true;
  lastMelodyTime = 0;
}

void notifyDoorClose() {
  Serial.println("🚪 문 닫힘");
  BTSerial.println("문 닫힘");
  doorOpen = false;
  noTone(SPEAKER);
}

void reportStatus() {
  String status = "🚗 차량 상태:\n";
  status += "시동: " + String(engineOn ? "ON" : "OFF") + "\n";
  status += "속도: " + String(currentSpeed) + " km/h\n";
  status += "배터리 잔량: " + String(batteryPercent) + "%\n";
  status += "문: " + String(doorOpen ? "열림" : "닫힘");

  Serial.println(status);
  BTSerial.println(status);
}

void processCommand(String cmd) {
  cmd.trim();
  Serial.print("명령 수신: ");
  Serial.println(cmd);

  if (cmd == "0") controlEngine(true);
  else if (cmd == "1") controlEngine(false);
  else if (cmd == "C") updateBatteryLED();
  else if (cmd.startsWith("S")) {
    int speed = cmd.substring(1).toInt();
    updateSpeedServo(speed);
  }
  else if (cmd == "F") {  // 🎯 연료 설정 명령 → 랜덤 배터리 값 생성
    batteryPercent = random(1, 101);  // 1 ~ 100
    updateBatteryLED();
    Serial.print("새 배터리 잔량: ");
    Serial.println(batteryPercent);
  }
  else if (cmd == "B") notifyDoorOpen();
  else if (cmd == "b") notifyDoorClose();
  else if (cmd == "T") reportStatus();
  else if (cmd == "E") triggerEmergency();
  else Serial.println("⚠️ 알 수 없는 명령어");
}

void loop() {
  repeatDoorMelody();

  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    processCommand(cmd);
  }

  if (BTSerial.available()) {
    String cmd = BTSerial.readStringUntil('\n');
    processCommand(cmd);
  }

  delay(1000);
}
