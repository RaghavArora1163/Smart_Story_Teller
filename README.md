Sure thing 👍 — here’s your **final `README.md`** in pure Markdown format, ready to paste into your repo.

```markdown
# 🎥 Story Teller — Full Stack (Free)

Turn a single prompt into **5–6 descriptive slides** with AI images, per-slide narration, and a stitched MP4 video.  

---

## 🚀 Features
- 🖼️ AI Image Generation (via Pollinations, free & public).
- 🎙️ Text-to-Speech Narration (gTTS, multilingual).
- 🎬 Automatic Video Stitching (MoviePy + ffmpeg).
- 🌐 Flutter Web App frontend.
- 🔧 Flask backend with async job handling.
- 📊 Progress tracking API.

---

## 📂 Project Structure
```

Story\_Teller/
├── backend/               # Flask API & media generation
│   ├── app.py
│   ├── requirements.txt
│   └── data/              # generated images/audio/videos (gitignored)
│
├── flutter\_app/           # Flutter web frontend
│   ├── lib/
│   ├── pubspec.yaml
│   └── build/             # build output (gitignored)
│
├── README.md
└── .gitignore

````

---

## 🛠️ Setup & Run Locally

### Backend (Flask)
```bash
cd backend
python -m venv venv
# Windows: venv\Scripts\activate
# macOS/Linux: source venv/bin/activate
pip install -r requirements.txt

# ensure ffmpeg is installed on your system
python app.py
# -> runs on http://localhost:5000
````

### Frontend (Flutter Web)

```bash
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

➡️ Open `http://localhost:8080` in your browser.

* Enter a prompt, choose **5–6 slides**, pick a narration voice (en/hi/es/fr), and hit **Generate**.
* Slides show **image + descriptive text + audio controls**.
* Final MP4 video appears below.

---

## 📦 API Endpoints

| Method | Endpoint                 | Description                |
| ------ | ------------------------ | -------------------------- |
| POST   | `/api/generate`          | Generate story (blocking)  |
| POST   | `/api/generate_async`    | Start async generation     |
| GET    | `/api/progress/<run_id>` | Check job progress         |
| GET    | `/api/result/<run_id>`   | Get results (images/audio) |
| GET    | `/images/<run_id>/<f>`   | Fetch image                |
| GET    | `/audio/<run_id>/<f>`    | Fetch audio                |
| GET    | `/videos/<f>`            | Fetch video                |

---

## 📊 Example Datasets (for testing)

### `prompts.json`

```json
[
  { "id": "001", "prompt": "A brave cat explores space." },
  { "id": "002", "prompt": "A little girl finds a magical book." }
]
```

### `captions.json`

```json
[
  { "run_id": "abc123", "slide": 1, "caption": "The cat looks at the stars." },
  { "run_id": "abc123", "slide": 2, "caption": "It builds a rocket out of cardboard." }
]
```

### `progress.json`

```json
{
  "run_id": "abc123",
  "status": "in_progress",
  "steps": {
    "text_to_story": "done",
    "story_to_images": "done",
    "audio_generation": "in_progress",
    "video_composition": "pending"
  }
}
```

---

## 🌐 Deployment Options

* **Frontend (Flutter Web):** Firebase Hosting or Vercel.
* **Backend (Flask):** Render / Railway / Heroku.
* Update `API_BASE_URL` in Flutter build:

  ```bash
  flutter build web --dart-define=API_BASE_URL=https://your-backend.com
  ```

---

## 📸 Screenshots

![UI Preview](https://via.placeholder.com/800x400?text=Flutter+Web+UI+Preview)
![Generated Story](https://via.placeholder.com/800x400?text=Generated+Story+Slides)

---

## 🤝 Contributing

1. Fork this repo
2. Create a feature branch: `git checkout -b feat/amazing-feature`
3. Commit changes: `git commit -m "Add amazing feature"`
4. Push branch: `git push origin feat/amazing-feature`
5. Open a Pull Request

---

## 📜 License

MIT License © 2025 \[Your Name]

---

## 🙌 Acknowledgements

* [MoviePy](https://zulko.github.io/moviepy/)
* [Pollinations AI](https://pollinations.ai/)
* [gTTS](https://pypi.org/project/gTTS/)
* [Flutter](https://flutter.dev/)
* [Flask](https://flask.palletsprojects.com/)

---

# 🟢 Steps to Push on GitHub

```bash
# 1. Initialize repo
git init

# 2. Add remote (replace with your repo URL)
git remote add origin https://github.com/<your-username>/story-teller.git

# 3. Add files & commit
git add .
git commit -m "Initial commit: Story Teller full stack"

# 4. Set main branch
git branch -M main

# 5. Push to GitHub
git push -u origin main
```

✔️ After pushing, visit your GitHub repo link to confirm.

```

---

Would you like me to also draft a **`.gitignore` file in Markdown code block** so you can just copy-paste that too before committing?
```
