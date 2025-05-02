# command_processor.py
from arduino_interface import ArduinoInterface

arduino = ArduinoInterface()

def interpret_command(text: str) -> str:
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
        voltage = arduino.read_voltage()
        return f"현재 연료 전압은 {voltage:.1f} 볼트입니다." if voltage > 0 else "연료 상태를 확인할 수 없습니다."
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
