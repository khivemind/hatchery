import sounddevice as sd
import numpy as np
import requests
import base64
import wave
import io
from datetime import datetime

# 설정
SAMPLE_RATE = 22050
DURATION = 1.5
DEVICE_ID = 1
COOLDOWN_TIME = 120

SERVER_URL = "http://34.81.221.132:8000/v1/predict"  # 나중에 실제 서버로 변경
API_KEY = "zerg-spore-sunken-7fK9xP2LmQ8vT3aR"
HIVE_ID = "hive_1"

last_alert_time = {}

import time

def should_send_alert(hive_id):
    now = time.time()
    if hive_id not in last_alert_time:
        return True
    if now - last_alert_time[hive_id] > COOLDOWN_TIME:
        return True
    remaining = COOLDOWN_TIME - (now - last_alert_time[hive_id])
    print(f"⏳ 쿨다운 중... {int(remaining)}초 남음")
    return False

def record_audio():
    audio = sd.rec(
        int(DURATION * SAMPLE_RATE),
        samplerate=SAMPLE_RATE,
        channels=1,
        dtype='int16',
        device=DEVICE_ID
    )
    sd.wait()
    return audio

def audio_to_base64(audio):
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(audio.tobytes())
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode('utf-8')

print("마이크 감지 시작... (Ctrl+C로 종료)")
print("-" * 40)

while True:
    audio = record_audio()
    wav_base64 = audio_to_base64(audio)

    if should_send_alert(HIVE_ID):
        try:
            response = requests.post(
                SERVER_URL,
                headers={"x-api-key": API_KEY},
                json={
                    "id": HIVE_ID,
                    "event_time": datetime.now().isoformat(),
                    "wav_base64": wav_base64
                }
            )
            print(f"상태코드: {response.status_code}")
            print(f"응답 내용: {response.text}")
            data = response.json()

            if data.get("status") == 200:
                prediction = data.get("prediction", {})
                label = prediction.get("label", "unknown")
                confidence = prediction.get("confidence", 0)

                print(f"판단: {label} | 확률: {confidence*100:.1f}%")

                if label == "hornet":
                    last_alert_time[HIVE_ID] = time.time()
                    print("🚨 말벌 감지! 서버 알림 전송!")
            else:
                print(f"서버 응답 오류: {data.get('status')}")

        except Exception as e:
            print(f"서버 연결 실패: {e}")