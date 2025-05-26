from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from command_processor import interpret_command, arduino, battery_percent
import random

app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# 시스템 상태 저장
status = {
    "battery": battery_percent,
    "speed": arduino.current_speed,
    "engine_on": False
}

# 음성 명령 처리
@app.post("/command")
async def handle_command(request: Request):
    global status, battery_percent
    data = await request.json()
    command = data.get("command", "")
    is_heavy_rain = data.get("is_heavy_rain", False)

    print(f"🗣 받은 음성 명령: {command}")
    print(f"🌧 폭우 상태: {is_heavy_rain}")

    if is_heavy_rain:
        return {
            "status": "skipped_due_to_heavy_rain",
            "command": command,
            "sent": None,
            "skipped": True
        }

    response = interpret_command(command)

    # 상태 업데이트
    if "시동 켜" in command:
        status["engine_on"] = True
    elif "시동 꺼" in command:
        status["engine_on"] = False
    elif "빨리" in command or "천천히" in command or "주행" in command:
        status["speed"] = arduino.current_speed
    elif "연료 설정" in command:
        status["battery"] = battery_percent

    return {
        "status": "ok",
        "response": response,
        "command": command
    }

# 수동 배터리 설정 API (테스트용)
@app.post("/set_battery")
async def set_battery_level(data: dict):
    global battery_percent
    level = int(data.get("level", random.randint(1, 100)))
    battery_percent = max(0, min(100, level))
    arduino.set_fuel_level(battery_percent)
    status["battery"] = battery_percent
    return {"message": "배터리 설정 완료", "level": battery_percent}

# 상태 조회용
@app.get("/status")
async def get_status():
    return status
