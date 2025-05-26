import serial
import threading
import time

class ArduinoInterface:
    def __init__(self, port='COM3', baudrate=9600):
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.current_speed = 40
        self.lock = threading.Lock()
        self._connect()

    def _connect(self):
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=1)
            time.sleep(2)
            print(f"[✅ 연결 성공] Arduino on {self.port}")
        except serial.SerialException as e:
            print(f"[❌ 시리얼 연결 실패] {e}")
            self.ser = None

    def send(self, cmd: str):
        if not self.ser or not self.ser.is_open:
            print("[⚠ 재연결 시도 중...]")
            self._connect()
        if self.ser and self.ser.is_open:
            with self.lock:
                try:
                    self.ser.write((cmd + '\n').encode())
                    print(f"[📤 전송됨] {cmd}")
                except Exception as e:
                    print(f"[❌ 전송 실패] {e}")

    def read_voltage(self):
        self.send("C")
        time.sleep(0.5)
        if self.ser:
            try:
                for _ in range(10):
                    if self.ser.in_waiting:
                        return float(self.ser.readline().decode().strip())
                    time.sleep(0.1)
            except Exception as e:
                print(f"[⚠ 전압 읽기 실패] {e}")
        return -1

    def adjust_speed(self, delta: int):
        self.current_speed = max(0, min(120, self.current_speed + delta))
        self.send(f"S{self.current_speed}")

    def set_fuel_level(self, percent: int):
        percent = max(0, min(100, percent))
        self.send(f"F{percent}")
        print(f"[🔋 연료 상태 설정됨] {percent}%")
