from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import serial
import threading
import time
import json

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 아두이노 시리얼 포트 설정
try:
    arduino = serial.Serial('COM3', 9600, timeout=1)
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

# 음성 명령 처리
@app.post("/command")
async def handle_command(request: Request):
    global status
    data = await request.json()
    command = data.get("command", "")

    mapped = ""
    command = command.strip()
    print(f"🗣 받은 음성 명령: {command}")

    if "시동켜" in command:
        mapped = "0"
        status["engine_on"] = True
    elif "시동꺼" in command:
        mapped = "1"
        status["engine_on"] = False
    elif "출발해" in command:
        status["speed"] = 40
        mapped = "S40"
    elif "빨리" in command:
        status["speed"] = min(status["speed"] + 10, 120)
        mapped = f"S{status['speed']}"
    elif "느리게" in command:
        status["speed"] = max(status["speed"] - 10, 0)
        mapped = f"S{status['speed']}"
    else:
        mapped = command  # fallback

    if arduino and arduino.is_open:
        arduino.write((mapped + "\n").encode())
        print(f"📤 명령 전송: {mapped}")

    return {"status": "ok", "command": command, "sent": mapped}

# 상태 조회용
@app.get("/status")
async def get_status():
    return status
