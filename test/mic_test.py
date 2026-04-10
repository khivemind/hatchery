import sounddevice as sd
import numpy as np
import requests
import base64
import wave
import io
import time
from datetime import datetime

# 설정
SAMPLE_RATE = 22050
DURATION = 2.0          # 2초로 변경
DEVICE_ID = 1
COOLDOWN_TIME = 120

SERVER_URL = "http://34.81.221.132:8000/v1/predict"
API_KEY = "zerg-spore-sunken-7fK9xP2LmQ8vT3aR"
HIVE_ID = "hive_1"

# FFT 임계치 설정
FFT_LOW_HZ = 200
FFT_HIGH_HZ = 300
FFT_THRESHOLD = 500  # 이 값 이상이면 서버 전송 (조정 가능)

last_alert_time = {}

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

def check_fft_threshold(audio):
    # FFT 계산
    fft_result = np.fft.rfft(audio.flatten())
    fft_magnitude = np.abs(fft_result)
    freqs = np.fft.rfftfreq(len(audio.flatten()), d=1/SAMPLE_RATE)

    # 200~300Hz 구간 추출
    target_range = (freqs >= FFT_LOW_HZ) & (freqs <= FFT_HIGH_HZ)
    target_magnitude = fft_magnitude[target_range]

    max_magnitude = np.max(target_magnitude) if len(target_magnitude) > 0 else 0
    print(f"📊 {FFT_LOW_HZ}~{FFT_HIGH_HZ}Hz 최대 진폭: {max_magnitude:.1f} (임계치: {FFT_THRESHOLD})")

    return max_magnitude >= FFT_THRESHOLD

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

    # FFT 임계치 체크 → 넘을 때만 서버 전송
    if not check_fft_threshold(audio):
        print("✅ 정상 범위 - 전송 안 함")
        continue

    print("⚠️ 임계치 초과 - 서버 전송 중...")

    if should_send_alert(HIVE_ID):
        wav_base64 = audio_to_base64(audio)
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