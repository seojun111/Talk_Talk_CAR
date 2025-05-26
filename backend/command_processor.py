from arduino_interface import ArduinoInterface
import random

arduino = ArduinoInterface()
battery_percent = random.randint(1, 100)  # 초기값

def interpret_command(text: str) -> str:
    global battery_percent

    if "시동 켜" in text:
        arduino.send("0")
        return "시동을 켰습니다."

    elif "시동 꺼" in text:
        arduino.send("1")
        return "시동을 껐습니다."

    elif "주행 시작" in text:
        arduino.send("S40")
        return "주행을 시작합니다."

    elif "천천히" in text:
        arduino.adjust_speed(-10)
        return "속도를 줄였습니다."

    elif "빨리" in text:
        arduino.adjust_speed(+10)
        return "속도를 올렸습니다."

    elif "연료" in text:
        return f"현재 배터리 잔량은 {battery_percent}%입니다."

    elif "연료 설정" in text:
        battery_percent = random.randint(1, 100)
        arduino.set_fuel_level(battery_percent)
        return f"배터리 잔량을 {battery_percent}%로 설정했습니다."

    elif "탈 거야" in text:
        arduino.send("B")
        return "앞문을 열었습니다."

    elif "탔어" in text:
        arduino.send("b")
        return "문을 닫습니다."

    elif "도와줘" in text:
        return "비상 상황입니다. 구조 요청을 시작합니다."

    else:
        return "알 수 없는 명령입니다."
