import sounddevice as sd
import numpy as np
import requests
import base64
import wave
import io
import time
from datetime import datetime
from config import API_KEY

# 설정
SAMPLE_RATE = 22050
DURATION = 2.0
DEVICE_ID = 1

SERVER_URL = "http://34.81.221.132:8000/v1/predict"
HIVE_ID = "hive_1"

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

    try:
        response = requests.post(
            SERVER_URL,
            headers={"x-api-key": API_KEY},
            json={
                "id": HIVE_ID,
                "event_time": datetime.now().isoformat(),
                "wav_base64": wav_base64,
                "device_id": HIVE_ID,
            }
        )
        data = response.json()

        if data.get("status") == 200:
            prediction = data.get("prediction", {})
            label = prediction.get("label", "unknown")
            confidence = prediction.get("confidence", 0)
            print(f"[{datetime.now().strftime('%H:%M:%S')}] 판단: {label} | 확률: {confidence*100:.1f}%")

            if label == "hornet":
                print("🚨 말벌 감지!")
        else:
            print(f"서버 오류: {data.get('status')}")

    except Exception as e:
        print(f"연결 실패: {e}")