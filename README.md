# Story Teller — Full Stack (Free)
Create 5–6 descriptive slides from a prompt with AI images, per-slide narration, and an MP4 video.

## Backend (Flask)
```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate
# macOS/Linux: source venv/bin/activate
pip install -r requirements.txt

# ensure ffmpeg is installed on your machine
python app.py
# -> http://localhost:5000
```

## Flutter Web App
```bash
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```
- Enter a prompt, pick 5 or 6 slides, choose voice (en/hi/es/fr), then **Generate**.
- Slides show image + descriptive text + audio controls; stitched video appears below.

## Notes
- Images: Pollinations (free, public). You can swap in another generator later.
- TTS: gTTS (free). If offline, TTS may fail.
- Video stitching: moviepy (needs ffmpeg). If video fails, images+audio still return.
