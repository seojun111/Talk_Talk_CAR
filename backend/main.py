from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Body
from jose import jwt, JWTError
from datetime import datetime, timedelta
import serial
import threading
import time

# AI 관련
from transformers import AutoTokenizer, AutoModelForCausalLM
from command_processor import interpret_command

# JWT 설정
SECRET_KEY = "your_secret_key"
ALGORITHM = "HS256"

def verify_jwt(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

# FastAPI 앱 초기화
app = FastAPI()

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# phi-2 모델 로딩
tokenizer = AutoTokenizer.from_pretrained("microsoft/phi-2")
model = AutoModelForCausalLM.from_pretrained("microsoft/phi-2")

def format_prompt(user_input):
    return (
    f"당신은 현재 시각장애인을 보조하는 차량 입니다. "
    f"질문에 맞는 답변을 생성해주세요. 비서 : "

    )

def generate_response(prompt):
    inputs = tokenizer(prompt, return_tensors="pt")
    outputs = model.generate(
        **inputs,
        max_new_tokens=150,
        pad_token_id=tokenizer.eos_token_id,
        temperature=0.9,
        top_p=0.95,
        do_sample=True
    )
    decoded = tokenizer.decode(outputs[0], skip_special_tokens=True)
    if "AI:" in decoded:
        return decoded.split("AI:")[-1].strip()
    return decoded.strip()

# 아두이노 시리얼 포트 초기화
try:
    arduino = serial.Serial('COM6', 9600, timeout=1)
    time.sleep(2)
    print("✅ 아두이노 연결 성공")
except Exception as e:
    arduino = None
    print(f"❌ 아두이노 연결 실패: {e}")

# 아두이노 상태 정보
status = {
    "voltage": 0.0,
    "speed": 0,
    "engine_on": False
}

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

@app.post("/token")
async def generate_token(username: str = Body(...), password: str = Body(...)):
    if username == "user" and password == "pass":
        to_encode = {
            "sub": username,
            "exp": datetime.utcnow() + timedelta(hours=1)
        }
        token = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
        return {"access_token": token}
    else:
        return {"error": "Invalid credentials"}
    
    
# 상태 확인용 (선택 사항)
@app.get("/status")
async def get_status():
    return {"status": "ok", "engine_on": status["engine_on"], "speed": status["speed"], "voltage": status["voltage"]}

# WebSocket 엔드포인트
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    token = websocket.query_params.get("token")
    user = verify_jwt(token)
    if user is None:
        await websocket.close(code=1008)
        return

    await websocket.accept()
    print("✅ WebSocket 연결됨")

    try:
        while True:
            data = await websocket.receive_text()
            print(f"📥 수신: {data}")

            # 1. AI 응답 생성
            prompt = format_prompt(data)
            ai_reply = generate_response(prompt)
            print(f"🤖 생성된 AI 응답: {ai_reply}")

            # 2. 명령 해석 및 아두이노 제어
            device_response = interpret_command(data)

            # 3. 결과 WebSocket으로 전송
            await websocket.send_json({
                "status": "ok",
                "ai_reply": ai_reply,
                "device_response": device_response
            })

    except WebSocketDisconnect:
        print("❌ WebSocket 연결 종료")
