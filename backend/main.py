from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import serial
import threading
import time

app = FastAPI()

# CORS 설정 (웹 Flutter 앱에서 호출 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 아두이노 시리얼 포트 설정
try:
    arduino = serial.Serial('COM5', 9600, timeout=1)
    time.sleep(2)
    print("✅ 아두이노 연결 성공")
except Exception as e:
    arduino = None
    print(f"❌ 아두이노 연결 실패: {e}")

# 상태값 저장용 변수
status = {
    "voltage": 0.0,
    "speed": 0,
    "engine_on": False
}

# 아두이노에서 데이터를 읽어오는 쓰레드
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

# 음성 명령 처리용
@app.post("/command")
async def handle_command(payload: dict):
    command = payload.get("command", "")
    if arduino and arduino.is_open:
        arduino.write((command + "\n").encode())
        print(f"📤 명령 전송: {command}")

        # 내부 상태 업데이트 (선택적)
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

# ✅ 상태 조회용 엔드포인트
@app.get("/status")
async def get_status():
    return status
