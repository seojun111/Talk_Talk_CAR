from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import serial
import threading
import time

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 아두이노 연결 시도
try:
    arduino = serial.Serial('COM3', 9600, timeout=1)
    time.sleep(2)
    print("✅ 아두이노 연결 성공")
except Exception as e:
    arduino = None
    print(f"❌ 아두이노 연결 실패: {e}")

# 차량 상태 저장
status = {
    "voltage": 0.0,
    "speed": 0,
    "engine_on": False
}

# 아두이노로부터 상태 읽기
def read_from_arduino():
    global status
    while arduino and arduino.is_open:
        try:
            if arduino.in_waiting:
                line = arduino.readline().decode().strip()
                print(f"📥 아두이노 수신: {line}")
                try:
                    voltage = float(line)
                    status["voltage"] = round(voltage, 1)
                except ValueError:
                    pass
        except Exception as e:
            print(f"⚠️ 읽기 오류: {e}")
        time.sleep(0.1)

if arduino:
    threading.Thread(target=read_from_arduino, daemon=True).start()

# 명령 수신
@app.post("/command")
async def handle_command(payload: dict):
    command = payload.get("command", "")
    if arduino and arduino.is_open:
        arduino.write((command + "\n").encode())
        print(f"📤 명령 전송: {command}")

        if command == "0":
            status["engine_on"] = True
        elif command == "1":
            status["engine_on"] = False
        elif command.startswith("S"):
            try:
                speed = int(command[1:])
                status["speed"] = speed
            except:
                pass

    return {"status": "ok", "command": command}

# 상태 조회
@app.get("/status")
async def get_status():
    return status

# ✅ 위급상황 처리
@app.post("/emergency")
async def emergency_alert():
    if arduino and arduino.is_open:
        arduino.write(b"E\n")  # E는 위급상황 알림 신호
        print("🚨 아두이노에 위급상황(E) 전송 완료")
    return {"status": "emergency_sent"}
