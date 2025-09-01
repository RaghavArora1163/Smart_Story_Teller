#!/usr/bin/env python3
import os, uuid, asyncio, re, mimetypes
from urllib.parse import quote
from threading import Thread, Lock

from flask import Flask, request, jsonify, send_from_directory, Response, make_response
from flask_cors import CORS
import requests
from PIL import Image
from gtts import gTTS

# Neural TTS (no API key). Falls back to gTTS.
try:
    import edge_tts
    EDGE_TTS_AVAILABLE = True
except Exception:
    EDGE_TTS_AVAILABLE = False

from moviepy.editor import ImageClip, AudioFileClip, concatenate_videoclips

# ---------- Paths ----------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR  = os.path.join(BASE_DIR, "data")
IMG_DIR   = os.path.join(DATA_DIR, "images")
AUDIO_DIR = os.path.join(DATA_DIR, "audio")
VIDEO_DIR = os.path.join(DATA_DIR, "videos")
for d in [DATA_DIR, IMG_DIR, AUDIO_DIR, VIDEO_DIR]:
    os.makedirs(d, exist_ok=True)

app = Flask(__name__)
CORS(app)

# ======================================================
# Progress tracking (for async generation)
# ======================================================
PROGRESS = {}   # run_id -> {"current":int, "total":int, "message":str, "done":bool, "error":str|None}
RESULTS  = {}   # run_id -> final story JSON payload
_LOCK = Lock()

def _progress_init(run_id: str, total: int, message: str = "Starting"):
    with _LOCK:
        PROGRESS[run_id] = {
            "current": 0, "total": max(1, total), "message": message, "done": False, "error": None
        }

def _progress_step(run_id: str, step: int = 1, message: str = ""):
    with _LOCK:
        p = PROGRESS.get(run_id)
        if not p: return
        p["current"] = max(0, min(p["total"], p["current"] + step))
        if message:
            p["message"] = message

def _progress_done(run_id: str, error: str | None = None):
    with _LOCK:
        p = PROGRESS.setdefault(run_id, {"current": 1, "total": 1, "message": "Done", "done": False, "error": None})
        p["done"] = True
        if error:
            p["error"] = error

# ======================================================
# Prompt → connected story, longer captions (no hardcoded domain keywords)
# ======================================================

_STOP = {
    "a","an","the","and","or","of","to","for","with","in","on","at","by","from","over","under",
    "this","that","these","those","is","are","was","were","be","being","been","as","into","about",
    "my","our","your","their","his","her","its","it","him","her","they","them"
}

def _tokens(s: str):
    return [w for w in re.findall(r"[^\W_]+", s, flags=re.UNICODE)]

def _sentences_from_prompt(prompt: str):
    # split into meaning chunks; fallback to the whole prompt
    parts = re.split(r"[.!?;:।]+|\s+(?:and|then|but)\s+|\s+(?:और|फिर|लेकिन)\s+", prompt, flags=re.IGNORECASE)
    parts = [p.strip() for p in parts if p and p.strip()]
    return parts if parts else [prompt.strip()]

def _content_spans(prompt: str, cap: int):
    toks = [t for t in _tokens(prompt) if t.lower() not in _STOP] or _tokens(prompt)
    spans, i = [], 0
    while i < len(toks) and len(spans) < cap:
        spans.append(" ".join(toks[i:i+3]))
        i += 2
    return [s for s in spans if s.strip()] or [prompt.strip()]

def _style_from_prompt(prompt: str):
    """Very light hints (no domain tables)."""
    p = prompt.lower()
    # time-of-day & vibe (optional hints only)
    time = "soft light"
    for k in ["sunrise","dawn","morning","noon","afternoon","sunset","dusk","evening","night","twilight","moonlight","golden hour"]:
        if k in p: time = k; break
    vibe = "calm, cinematic atmosphere"
    for k in ["storm","wind","mist","fog","rain","festival","crowd","quiet","sacred","ancient","futuristic","neon","retro"]:
        if k in p: vibe = f"{k} mood"; break
    return time, vibe

# ---------- Long, connected captions ----------
def _paragraph_en(opening: str, motif: str, role: str, time_hint: str, vibe: str) -> str:
    s1 = f"{opening.strip().capitalize()}."
    if role == "opening":
        s2 = f"In {time_hint}, the scene breathes; {motif} hangs quietly in the air while edges come into focus."
        s3 = "Distant sounds gather, textures settle underfoot, and the frame invites us to look a little longer."
        s4 = "Nothing shouts yet—only a direction begins to form, gentle but certain."
    elif role == "inciting":
        s2 = f"A small shift near {motif} breaks the stillness; something asks to be followed."
        s3 = "Footsteps answer, shoulders turn, and a line is crossed that cannot be uncrossed."
        s4 = f"The {vibe} wraps the moment with intent as the world leans forward."
    elif role == "rising":
        s2 = f"The path threads through detail; {motif} gathers weight with each breath."
        s3 = "Colors deepen, the camera glides closer, and every surface seems to remember a touch."
        s4 = "We keep moving because stopping now would mean not knowing."
    elif role == "midpoint":
        s2 = f"A new angle opens; what was hidden inside {motif} becomes legible."
        s3 = "Meaning lands with the quiet click of a lock, and the stakes shift under the light."
        s4 = "We see how far we have come, and how far we still might go."
    elif role == "climax":
        s2 = f"Energy peaks—light and motion rush around {motif} until the choice arrives, clean and bright."
        s3 = "Time narrows to a single breath, and the world holds still to hear the answer."
        s4 = "The step is taken; the scene blazes and then releases."
    else:  # resolution
        s2 = f"Echoes fall away; in {time_hint}, the air loosens its grip and the colors soften."
        s3 = f"What remains of {motif} is simple and true, not smaller but clearer."
        s4 = "We carry the quiet forward like a warm stone in the pocket."
    return " ".join([s1, s2, s3, s4])

def _paragraph_hi(opening: str, motif: str, role: str, time_hint: str, vibe: str) -> str:
    s1 = f"{opening.strip()[0].upper() + opening.strip()[1:]}."
    if role == "opening":
        s2 = f"{time_hint} में दृश्य साँस लेता है; {motif} हवा में धीमे-धीमे टँगा है और किनारे साफ़ होने लगते हैं।"
        s3 = "दूर की ध्वनियाँ जुटती हैं, सतह की बनावटें पैरों तले ठहरती हैं, और फ़्रेम हमें थोड़ी देर और देखने को कहता है।"
        s4 = "कुछ भी चिल्लाता नहीं—सिर्फ़ एक दिशा जन्म लेती है, नरम लेकिन निश्चित।"
    elif role == "inciting":
        s2 = f"{motif} के पास एक हल्की हलचल सन्नाटा तोड़ती है; कोई इशारा बुलाता है।"
        s3 = "कदम जवाब देते हैं, कंधे मुड़ते हैं, और एक ऐसी रेखा पार होती है जो वापस नहीं होती।"
        s4 = f"{vibe} इस पल को मक़सद से लपेट लेती है और दुनिया थोड़ा आगे झुक जाती है।"
    elif role == "rising":
        s2 = f"रास्ता बारीक़ियों से होकर गुजरता है; {motif} हर साँस के साथ भारी होता जाता है।"
        s3 = "रंग गाढ़े, कैमरा पास, और हर सतह जैसे स्पर्श याद कर रही हो।"
        s4 = "हम चलते रहते हैं, क्योंकि रुकना अब ‘न जानना’ होगा।"
    elif role == "midpoint":
        s2 = f"एक नया कोण खुलता है; {motif} के भीतर छिपी परतें पढ़ी जा सकती हैं।"
        s3 = "अर्थ ताले की धीमी क्लिक की तरह बैठता है और दाँव रोशनी में खिसकते हैं।"
        s4 = "समझ आता है कि कितनी दूर आ चुके हैं, और कहाँ तक जा सकते हैं।"
    elif role == "climax":
        s2 = f"ऊर्जा चरम पर—रोशनी और गति {motif} के चारों ओर उमड़ पड़ती है और निर्णय उजलेपन के साथ उतरता है।"
        s3 = "समय एक साँस में सिमटता है; दुनिया उत्तर सुनने को ठहर जाती है।"
        s4 = "कदम उठता है; दृश्य धधकता है और फिर ढीला पड़ता है।"
    else:  # resolution
        s2 = f"प्रतिध्वनियाँ थमती हैं; {time_hint} में हवा ढीली होती है और रंग नरम।"
        s3 = f"{motif} में बचा हुआ हिस्सा सरल है, छोटा नहीं—बस साफ़।"
        s4 = "हम इस शान्ति को जेब में रखे गर्म पत्थर की तरह साथ ले चलते हैं।"
    return " ".join([s1, s2, s3, s4])

def _build_long_captions(prompt: str, n: int, lang: str):
    """Return n connected paragraphs (3–5 sentences each) derived from the prompt only."""
    parts   = _sentences_from_prompt(prompt)
    spans   = _content_spans(prompt, cap=n*2)
    time_hint, vibe = _style_from_prompt(prompt)

    def get_part(i): return parts[i % len(parts)]
    def get_span(i): return spans[i % len(spans)]

    roles = ["opening","inciting","rising","midpoint","climax","resolution"][:n]
    paras = []
    for i, role in enumerate(roles):
        opening = get_part(i) if i < len(parts) else f"{prompt.strip()}"
        motif   = get_span(i)
        if lang.lower().startswith("hi"):
            paras.append(_paragraph_hi(opening, motif, role, time_hint, vibe))
        else:
            paras.append(_paragraph_en(opening, motif, role, time_hint, vibe))
    return paras

# ---------- Beat & image prompt builder ----------
SHOT_STYLES = [
    ("Opening",        "establishing wide shot, sweeping scale"),
    ("Inciting Event", "medium shot, subtle motion cue"),
    ("Rising Action",  "tracking shot, forward motion"),
    ("Midpoint",       "revealing high angle, layered depth"),
    ("Climax",         "dynamic close-up, dramatic lighting"),
    ("Resolution",     "closing wide shot, quiet composition"),
]

def expand_prompt_into_beats(prompt: str, n_slides: int, lang: str):
    """Build 5–6 connected beats. Image prompt is driven by the long caption to keep picture aligned."""
    n = max(5, min(6, n_slides or 6))
    captions = _build_long_captions(prompt, n, lang)

    beats = []
    for i, (title, shot) in enumerate(SHOT_STYLES[:n]):
        caption = captions[i]
        # Use BOTH the user prompt and the long caption to guide the image
        image_prompt = (
            f"{prompt}. {caption} "
            f"-- {title.lower()}, {shot}, cinematic, photorealistic, highly detailed, 4k"
        )
        beats.append({"title": title, "text": caption, "image_prompt": image_prompt})
    return beats

# =========================
# I/O helpers
# =========================
def pollinations_url(prompt):
    return f"https://image.pollinations.ai/prompt/{quote(prompt)}?nologo=true&width=1280&height=720"

def download_image(url, out_path):
    r = requests.get(url, timeout=60); r.raise_for_status()
    with open(out_path, "wb") as f: f.write(r.content)

def pick_edge_voice(lang: str, user_voice: str | None):
    if user_voice: return user_voice
    return "hi-IN-SwaraNeural" if lang.lower().startswith("hi") else "en-US-AriaNeural"

async def _edge_tts_save(text: str, out_path: str, voice: str, rate: str, pitch: str):
    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    with open(out_path, "wb") as f:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                f.write(chunk["data"])

def tts_to_mp3(text, out_path, lang="en", user_voice=None):
    if EDGE_TTS_AVAILABLE:
        try:
            voice = pick_edge_voice(lang, user_voice)
            # Slightly slower for Hindi; mild lower pitch for warmth
            rate  = "-8%" if lang.lower().startswith("hi") else "-2%"
            pitch = "-2%"
            asyncio.run(_edge_tts_save(text, out_path, voice, rate, pitch))
            return
        except Exception:
            pass
    gTTS(text=text, lang=("hi" if lang.lower().startswith("hi") else "en")).save(out_path)

def build_video(slides, out_path):
    clips = []
    try:
        for s in slides:
            a = AudioFileClip(s["audio_path"])
            v = ImageClip(s["image_path"]).set_duration(a.duration).set_audio(a)
            clips.append(v)
        video = concatenate_videoclips(clips, method="compose")
        # Web friendly flags: faststart + yuv420p
        video.write_videofile(
            out_path,
            fps=30,
            codec="libx264",
            audio_codec="aac",
            ffmpeg_params=["-movflags", "+faststart", "-pix_fmt", "yuv420p"],
        )
    finally:
        # Close all clips to free file handles
        for c in clips:
            try: c.close()
            except: pass
        try: video.close()  # type: ignore
        except: pass

# ======================================================
# Background worker used by async API
# ======================================================
def _generate_story_task(run_id: str, prompt: str, n_slides: int, lang: str, voice: str | None):
    """
    Performs generation while updating PROGRESS and saves final payload in RESULTS.
    """
    try:
        n = max(5, min(6, n_slides or 6))
        # total steps = plan(1) + per-slide image+audio (2*n) + video(1)
        total = 1 + 2 * n + 1
        _progress_init(run_id, total, "Planning story")

        # ---- paths
        run_img = os.path.join(IMG_DIR, run_id); os.makedirs(run_img, exist_ok=True)
        run_aud = os.path.join(AUDIO_DIR, run_id); os.makedirs(run_aud, exist_ok=True)

        # ---- plan
        beats = expand_prompt_into_beats(prompt, n, lang)
        _progress_step(run_id, 1, "Generating slides")

        slides = []
        for i, b in enumerate(beats, 1):
            # image
            img_path = os.path.join(run_img, f"{i:02d}.jpg")
            try:
                download_image(pollinations_url(b["image_prompt"]), img_path)
            except Exception:
                Image.new("RGB", (1280, 720), (20,20,20)).save(img_path, "JPEG", quality=90)
            _progress_step(run_id, 1, f"Slide {i}/{n}: image")

            # audio
            aud_path = os.path.join(run_aud, f"{i:02d}.mp3")
            try:
                tts_to_mp3(b["text"], aud_path, lang=lang, user_voice=voice)
            except Exception:
                open(aud_path, "wb").close()
            _progress_step(run_id, 1, f"Slide {i}/{n}: audio")

            slides.append({
                "index": i,
                "title": b["title"],
                "text":  b["text"],
                "image_path": img_path,
                "audio_path": aud_path,
                "image_url": f"/images/{run_id}/{i:02d}.jpg",
                "audio_url": f"/audio/{run_id}/{i:02d}.mp3",
            })

        # ---- video
        video_url = None
        try:
            video_name = f"{run_id}.mp4"
            _progress_step(run_id, 0, "Rendering video")
            build_video(slides, os.path.join(VIDEO_DIR, video_name))
            video_url = f"/videos/{video_name}"
        except Exception:
            pass
        _progress_step(run_id, 1, "Finalizing")

        # ---- store result (same shape as /api/generate)
        result_payload = {
            "run_id": run_id,
            "slides": [{"index": s["index"], "title": s["title"], "text": s["text"],
                        "image_url": s["image_url"], "audio_url": s["audio_url"]} for s in slides],
            "video_url": video_url,
            "tts_engine": "edge-tts" if EDGE_TTS_AVAILABLE else "gtts",
        }
        with _LOCK:
            RESULTS[run_id] = result_payload

        _progress_done(run_id, None)
    except Exception as e:
        _progress_done(run_id, str(e))

# ======================================================
# Routes (sync + async)
# ======================================================
@app.route("/api/generate_async", methods=["POST"])
def generate_async():
    """
    Start generation in background and return run_id immediately.
    """
    data = request.get_json(force=True, silent=True) or {}
    prompt = (data.get("prompt") or "").strip()
    n_slides = int(data.get("slides") or 6)
    lang  = (data.get("lang") or "en").strip() or "en"
    voice = (data.get("voice") or "").strip() or None
    if not prompt:
        return jsonify({"error": "Missing 'prompt'"}), 400

    run_id = str(uuid.uuid4())[:8]
    # initialize progress so UI has immediate values
    _progress_init(run_id, 1 + 2*max(5, min(6, n_slides)) + 1, "Queued")
    Thread(target=_generate_story_task, args=(run_id, prompt, n_slides, lang, voice), daemon=True).start()
    return jsonify({"run_id": run_id, "status": "started"}), 202

@app.route("/api/progress/<run_id>", methods=["GET"])
def progress(run_id):
    p = PROGRESS.get(run_id)
    if not p:
        return jsonify({"error": "unknown run_id"}), 404
    percent = int(round(100.0 * p["current"] / float(p["total"] if p["total"] else 1)))
    return jsonify({
        "run_id": run_id,
        "current": p["current"],
        "total": p["total"],
        "percent": percent,
        "message": p.get("message", ""),
        "done": p.get("done", False),
        "error": p.get("error"),
    })

@app.route("/api/result/<run_id>", methods=["GET"])
def result(run_id):
    r = RESULTS.get(run_id)
    if not r:
        # allow clients to poll until done
        p = PROGRESS.get(run_id)
        if p and not p.get("done"):
            return jsonify({"status": "pending"}), 202
        return jsonify({"status": "missing"}), 404
    return jsonify(r)

# --- Existing synchronous endpoint (kept for compatibility) ---
@app.route("/api/generate", methods=["POST"])
def generate():
    data = request.get_json(force=True, silent=True) or {}
    prompt = (data.get("prompt") or "").strip()
    n_slides = int(data.get("slides") or 6)
    lang  = (data.get("lang") or "en").strip() or "en"
    voice = (data.get("voice") or "").strip() or None

    if not prompt:
        return jsonify({"error": "Missing 'prompt'"}), 400

    uid = str(uuid.uuid4())[:8]
    run_img = os.path.join(IMG_DIR, uid); os.makedirs(run_img, exist_ok=True)
    run_aud = os.path.join(AUDIO_DIR, uid); os.makedirs(run_aud, exist_ok=True)

    beats = expand_prompt_into_beats(prompt, n_slides, lang)
    slides = []

    for i, b in enumerate(beats, 1):
        img_path = os.path.join(run_img, f"{i:02d}.jpg")
        try:
            download_image(pollinations_url(b["image_prompt"]), img_path)
        except Exception:
            Image.new("RGB", (1280, 720), (20,20,20)).save(img_path, "JPEG", quality=90)

        aud_path = os.path.join(run_aud, f"{i:02d}.mp3")
        try:
            tts_to_mp3(b["text"], aud_path, lang=lang, user_voice=voice)
        except Exception:
            open(aud_path, "wb").close()

        slides.append({
            "index": i,
            "title": b["title"],
            "text":  b["text"],
            "image_path": img_path,
            "audio_path": aud_path,
            "image_url": f"/images/{uid}/{i:02d}.jpg",
            "audio_url": f"/audio/{uid}/{i:02d}.mp3",
        })

    video_url = None
    try:
        video_name = f"{uid}.mp4"
        build_video(slides, os.path.join(VIDEO_DIR, video_name))
        video_url = f"/videos/{video_name}"
    except Exception:
        pass

    return jsonify({
        "run_id": uid,
        "slides": [{"index": s["index"], "title": s["title"], "text": s["text"],
                    "image_url": s["image_url"], "audio_url": s["audio_url"]} for s in slides],
        "video_url": video_url,
        "tts_engine": "edge-tts" if EDGE_TTS_AVAILABLE else "gtts",
    })

# --- Static media + health ---
@app.route("/images/<run_id>/<filename>")
def serve_image(run_id, filename):
    return send_from_directory(os.path.join(IMG_DIR, run_id), filename, as_attachment=False)

@app.route("/audio/<run_id>/<filename>")
def serve_audio(run_id, filename):
    return send_from_directory(os.path.join(AUDIO_DIR, run_id), filename, as_attachment=False)

def _iter_file_range(path, start, end, block_size=8192):
    with open(path, 'rb') as f:
        f.seek(start)
        remaining = end - start + 1
        while remaining > 0:
            chunk = f.read(min(block_size, remaining))
            if not chunk:
                break
            yield chunk
            remaining -= len(chunk)

@app.route("/videos/<filename>")
def serve_video(filename):
    # Full path & size
    path = os.path.join(VIDEO_DIR, filename)
    if not os.path.isfile(path):
        return jsonify({"error": "not found"}), 404

    file_size = os.path.getsize(path)
    range_header = request.headers.get('Range', None)

    # Default content-type
    ctype = mimetypes.guess_type(path)[0] or 'video/mp4'

    if range_header:
        # Parse Range: bytes=start-end
        m = re.match(r"bytes=(\d*)-(\d*)", range_header)
        if m:
            start_s, end_s = m.groups()
            try:
                start = int(start_s) if start_s else 0
            except ValueError:
                start = 0
            try:
                end = int(end_s) if end_s else file_size - 1
            except ValueError:
                end = file_size - 1

            start = max(0, start)
            end = min(file_size - 1, end)
            if start > end:
                # Invalid range
                resp = make_response('', 416)
                resp.headers["Content-Range"] = f"bytes */{file_size}"
                return resp

            length = (end - start) + 1
            resp = Response(_iter_file_range(path, start, end), status=206, mimetype=ctype)
            resp.headers.add('Content-Range', f'bytes {start}-{end}/{file_size}')
            resp.headers.add('Accept-Ranges', 'bytes')
            resp.headers.add('Content-Length', str(length))
            return resp

    # No Range: return whole file
    resp = send_from_directory(VIDEO_DIR, filename, as_attachment=False, mimetype=ctype)
    resp.headers["Accept-Ranges"] = "bytes"
    return resp

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    # On some hosts (Render/Heroku), PORT is injected
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")), debug=True)
