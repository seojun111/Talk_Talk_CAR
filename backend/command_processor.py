from arduino_interface import ArduinoInterface
import random

# ✅ 아두이노 포트 지정
arduino = ArduinoInterface(port='COM6')

# ✅ 배터리 초기값 전역 변수로 선언
battery_percent = random.randint(1, 100)

def interpret_command(text: str) -> str:
    global battery_percent

    if "켜" in text:
        arduino.send("0")
        status["engine_on"] = True
        return "시동을 켰습니다."

    elif "꺼" in text:
        arduino.send("1")
        status["engine_on"] = False
        return "시동을 껐습니다."

    elif "주행" in text:
        arduino.send("S40")
        arduino.current_speed = 40
        status["speed"] = 40
        return "주행을 시작합니다."

    elif "천천히" in text:
        arduino.adjust_speed(-10)
        status["speed"] = arduino.current_speed
        return "속도를 줄였습니다."

    elif "빨리" in text:
        arduino.adjust_speed(+10)
        status["speed"] = arduino.current_speed
        return "속도를 올렸습니다."

    elif "연료 설정" in text:
        arduino.send("F")
        return "배터리 잔량을 새로 설정했습니다."

    elif "탑승" in text:
        arduino.send("B")
        return "앞문을 열었습니다."

    elif "탔어" in text:
        arduino.send("b")
        return "문을 닫습니다."

    elif "응급상황" in text:
        arduino.send("E")
        return "비상 상황입니다. 구조 요청을 시작합니다."

    else:
        return "알 수 없는 명령입니다."
