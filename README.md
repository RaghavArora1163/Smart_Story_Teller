# Smart Story Teller - Comprehensive Technical Documentation

A full-stack AI-powered application that transforms text prompts into interactive multimedia stories with generated images, narrated audio, and compiled video presentations.

## 🏗️ Architecture Overview

```
┌─────────────────┐    HTTP API    ┌─────────────────┐
│  Flutter Web    │◄──────────────►│   Flask Backend │
│   (Frontend)    │                │   (API Server)  │
└─────────────────┘                └─────────────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │   AI Services   │
                                   │  - Image Gen    │
                                   │  - Text-to-Speech│
                                   │  - Story Logic  │
                                   └─────────────────┘
```

## 🎯 Key Features

- **AI-Powered Story Generation**: Converts text prompts into structured narratives with cinematic beats
- **Dynamic Image Generation**: Creates contextual images for each story segment
- **Multi-language Audio Narration**: Supports English and Hindi with realistic voice synthesis
- **Video Compilation**: Automatically stitches images and audio into MP4 videos
- **Real-time Progress Tracking**: Live updates during generation process
- **Interactive Web Interface**: Modern, responsive Flutter web application
- **Async Processing**: Non-blocking story generation with progress monitoring

---

## 🔧 Backend Technologies

### Core Framework
- **Flask** - Python web framework for API services
- **Flask-CORS** - Cross-Origin Resource Sharing support for web clients

### AI & Machine Learning
- **Pollinations AI** - Free image generation service
  - Endpoint: `https://image.pollinations.ai/`
  - Generates 1280x720 cinematic images from text prompts
  - No API key required, public access

### Text-to-Speech (TTS) Engine
**Primary**: **Edge-TTS** (Microsoft)
- Neural network-based speech synthesis
- High-quality, natural-sounding voices
- Supports multiple languages and voices
- Voices used:
  - English: `en-US-AriaNeural`
  - Hindi: `hi-IN-SwaraNeural`
- Configurable rate and pitch adjustment

**Fallback**: **gTTS** (Google Text-to-Speech)
- Backup option when Edge-TTS unavailable
- Requires internet connection

### Video Processing
- **MoviePy** - Python video editing library
- **FFmpeg** - Media processing backend (required system dependency)
- **ImageIO-FFmpeg** - Python wrapper for FFmpeg
- Features:
  - Image sequence to video conversion
  - Audio synchronization
  - MP4 encoding with H.264/AAC

### Image Processing
- **Pillow (PIL)** - Python image manipulation
- **Requests** - HTTP client for image downloads
- Fallback image generation for failed downloads

### Data Management
- **Threading** - Async task processing
- **UUID** - Unique run identifiers
- **JSON** - Data serialization
- File-based storage structure:
  ```
  backend/data/
  ├── images/
  │   └── {run_id}/
  │       ├── 01.jpg
  │       └── 02.jpg
  ├── audio/
  │   └── {run_id}/
  │       ├── 01.mp3
  │       └── 02.mp3
  └── videos/
      └── {run_id}.mp4
  ```

### Story Generation Algorithm

The backend implements a sophisticated story structure generator:

1. **Narrative Architecture**: Based on classical story beats
   - Opening (Establishing shot)
   - Inciting Event (Medium shot)
   - Rising Action (Tracking shot)
   - Midpoint (High angle)
   - Climax (Close-up)
   - Resolution (Wide shot)

2. **Smart Content Processing**:
   - Extracts key themes from user prompts
   - Generates connected narrative paragraphs
   - Creates cinematic image prompts
   - Maintains story coherence across slides

3. **Multi-language Support**:
   - Language-specific narrative templates
   - Cultural context adaptation
   - Proper voice selection based on language

### API Endpoints

#### Synchronous Generation
```http
POST /api/generate
Content-Type: application/json

{
  "prompt": "A shy cat learns to fly in Jaipur",
  "slides": 6,
  "lang": "en"
}
```

#### Asynchronous Generation (Recommended)
```http
POST /api/generate_async
Content-Type: application/json

{
  "prompt": "Story prompt here",
  "slides": 5,
  "lang": "hi"
}

Response: {"run_id": "abc123", "status": "started"}
```

#### Progress Monitoring
```http
GET /api/progress/{run_id}

Response: {
  "run_id": "abc123",
  "current": 8,
  "total": 13,
  "percent": 61,
  "message": "Generating slide 4/6: audio",
  "done": false,
  "error": null
}
```

#### Result Retrieval
```http
GET /api/result/{run_id}

Response: {
  "run_id": "abc123",
  "slides": [...],
  "video_url": "/videos/abc123.mp4",
  "tts_engine": "edge-tts"
}
```

#### Static File Serving
- `/images/{run_id}/{filename}` - Generated images
- `/audio/{run_id}/{filename}` - Generated audio files
- `/videos/{filename}` - Compiled video files
- `/health` - Service health check

---

## 🎨 Frontend Technologies

### Core Framework
- **Flutter 3.3+** - Google's UI toolkit for web applications
- **Dart** - Programming language for Flutter development

### HTTP Communication
- **HTTP Package** - RESTful API communication with backend
- **JSON Serialization** - Data parsing and model mapping

### UI Components & Libraries

#### Media Playback
- **Video Player** - HTML5 video playback with custom controls
  - Network video streaming
  - Playback controls (play/pause/seek/replay)
  - Progress tracking with slider
  - Time display

- **AudioPlayers** - Web-optimized audio playback
  - Streaming audio from URLs
  - Position tracking
  - Play/pause/seek controls

#### Interactive Elements
- **Carousel Slider** - Touch-friendly slide navigation
  - Horizontal scrolling
  - Center enlargement effect
  - Infinite scroll disabled for story context

### UI/UX Design System

#### Color Scheme (Dark Theme)
```dart
Primary: #3B82F6 (Blue)
Background: #0E0F12 (Dark Navy)
Cards: #171A1F (Dark Gray)
Secondary Cards: #1F2937 (Slate)
Borders: #334155 (Light Slate)
Text Primary: #FFFFFF (White)
Text Secondary: #9AA7B6 (Light Gray)
```

#### Component Architecture
- **Material Design 3** principles
- **Responsive layouts** for various screen sizes
- **Custom themed components** matching design system

#### Key UI Components

1. **StoryMakerPage** - Main application interface
   - Input form with validation
   - Async progress tracking
   - Results display

2. **SlideCard** - Individual story slide presentation
   - Image display with loading states
   - Audio playback controls
   - Text content with typography
   - Download functionality

3. **Progress Indicator** - Real-time generation tracking
   - Linear progress bar
   - Percentage display
   - Status messages

4. **Video Player Controls** - Custom video interface
   - Play/pause toggle
   - Seek slider
   - Time display
   - Replay functionality

### Web-Specific Features

#### File Downloads (Browser Integration)
```dart
// Direct binary download without new tabs
Future<void> _downloadBinary(String url, String filename) async {
  final req = await html.HttpRequest.request(
    url, 
    method: 'GET', 
    responseType: 'blob'
  );
  final blob = req.response as html.Blob;
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  // Programmatic download trigger
}
```

#### Configuration Management
- Environment-based API URL configuration
- Build-time variable injection
- Development vs production settings

### State Management
- **StatefulWidget** pattern for component-level state
- **HTTP polling** for progress updates
- **Timer-based** async operations
- **Error handling** with user feedback

### Data Models

#### StorySlide Model
```dart
class StorySlide {
  final int index;
  final String title;
  final String text;
  final String imageUrl;
  final String audioUrl;
}
```

#### StoryResponse Model
```dart
class StoryResponse {
  final String runId;
  final List<StorySlide> slides;
  final String? videoUrl;
}
```

---

## 🤖 AI Integration Details

### Image Generation Pipeline

1. **Prompt Enhancement**:
   ```python
   # Original prompt + story context + cinematic direction
   image_prompt = (
       f"{user_prompt}. {generated_caption} "
       f"-- {story_beat}, {camera_angle}, cinematic, "
       f"photorealistic, highly detailed, 4k"
   )
   ```

2. **Style Adaptation**:
   - Time-of-day detection (sunrise, noon, dusk, etc.)
   - Mood inference (calm, dramatic, mysterious)
   - Cultural context preservation

3. **Quality Parameters**:
   - Resolution: 1280x720 (16:9 aspect ratio)
   - Style: Photorealistic, cinematic
   - No watermarks or logos

### Natural Language Processing

#### Story Structure Generator
```python
def expand_prompt_into_beats(prompt: str, n_slides: int, lang: str):
    # 1. Parse user prompt into semantic components
    # 2. Generate connected narrative beats
    # 3. Create cinematic shot descriptions
    # 4. Build cohesive image prompts
    # 5. Return structured story data
```

#### Multi-language Narrative Templates
- **English**: Cinematic, descriptive language with literary flourishes
- **Hindi**: Cultural context-aware narratives with appropriate vocabulary
- Language-specific sentence structures and storytelling patterns

### Voice Synthesis Configuration

#### Edge-TTS Parameters
```python
# Voice selection
english_voice = "en-US-AriaNeural"
hindi_voice = "hi-IN-SwaraNeural"

# Audio quality settings
rate = "-8%" if lang == "hindi" else "-2%"  # Slower for Hindi
pitch = "-2%"  # Slight warmth adjustment
```

#### Audio Processing
- Format: MP3 (web-compatible)
- Quality: High-definition neural synthesis
- Fallback: Google TTS for reliability

---

## 🚀 Installation & Setup

### Backend Setup

#### Prerequisites
```bash
# Python 3.8+ required
python --version

# FFmpeg installation (required for video processing)
# Windows (using Chocolatey)
choco install ffmpeg

# macOS (using Homebrew)
brew install ffmpeg

# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg
```

#### Installation Steps
```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run development server
python app.py
```

#### Backend Configuration
- **Port**: 5000 (configurable via `PORT` environment variable)
- **Host**: 0.0.0.0 (accepts connections from any IP)
- **Debug**: Enabled in development mode
- **CORS**: Enabled for web client access

### Frontend Setup

#### Prerequisites
```bash
# Flutter SDK installation
# Download from: https://flutter.dev/docs/get-started/install

# Verify installation
flutter --version
flutter doctor
```

#### Installation Steps
```bash
# Navigate to Flutter app directory
cd flutter_app

# Get dependencies
flutter pub get

# Run web development server
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000

# Build for production
flutter build web --dart-define=API_BASE_URL=https://your-api-domain.com
```

#### Frontend Configuration
- **API Base URL**: Configurable via environment variable
- **Target Platform**: Web (Chrome recommended)
- **Build Output**: `build/web/` directory

---

## 📁 Project Structure

```
Smart_Story_Teller/
├── backend/
│   ├── app.py                 # Main Flask application
│   ├── requirements.txt       # Python dependencies
│   ├── fonts/
│   │   └── Inter-Regular.ttf  # Typography assets
│   └── data/                  # Generated content storage
│       ├── images/
│       ├── audio/
│       └── videos/
│
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── config.dart        # Configuration management
│   │   ├── api/
│   │   │   └── story_api.dart # Backend communication
│   │   ├── models/
│   │   │   └── story_models.dart # Data models
│   │   ├── screens/
│   │   │   └── story_maker_page.dart # Main interface
│   │   └── widgets/
│   │       └── slide_card.dart # Slide components
│   ├── pubspec.yaml           # Flutter dependencies
│   └── build/                 # Compiled web assets
│
├── README.md                  # Basic setup instructions
└── .gitignore                # Version control exclusions
```

---

## 🔄 Workflow & Processing Pipeline

### 1. User Input Processing
```
User Prompt → Semantic Analysis → Story Beat Generation
```

### 2. Content Generation Pipeline
```
For each story beat:
├── Generate narrative text (3-4 sentences)
├── Create enhanced image prompt
├── Download/generate image
├── Synthesize audio narration
└── Store with metadata
```

### 3. Media Compilation
```
All slides ready → Video compilation → MP4 output
```

### 4. Delivery
```
JSON response → Frontend rendering → User interaction
```

---

## ⚡ Performance Optimizations

### Backend Optimizations
- **Async Processing**: Non-blocking generation with progress tracking
- **Resource Management**: Automatic cleanup of media processing objects
- **Error Handling**: Graceful fallbacks for failed AI services
- **Caching**: File-based storage prevents regeneration

### Frontend Optimizations
- **Lazy Loading**: Images load progressively with loading states
- **Progress Indicators**: Real-time feedback during generation
- **Memory Management**: Proper disposal of media controllers
- **Network Optimization**: Efficient HTTP polling intervals

### AI Service Optimizations
- **Prompt Engineering**: Optimized prompts for consistent quality
- **Fallback Systems**: Multiple TTS options for reliability
- **Batch Processing**: Efficient resource utilization
- **Quality Control**: Error handling for failed generations

---

## 🛠️ Troubleshooting

### Common Issues

#### FFmpeg Not Found
```bash
# Error: MoviePy cannot find FFmpeg
# Solution: Install FFmpeg and ensure it's in system PATH
```

#### CORS Issues
```bash
# Error: Access blocked by CORS policy
# Solution: Verify Flask-CORS configuration and API URLs
```

#### TTS Service Failures
```python
# Error: edge-tts connection timeout
# Solution: Automatic fallback to gTTS implemented
```

#### Flutter Web Build Issues
```bash
# Error: Build failures or missing dependencies
flutter clean
flutter pub get
flutter build web
```

### Performance Tuning

#### Backend Scaling
- Increase timeout values for slow AI services
- Configure multiple workers for concurrent processing
- Implement Redis for production progress tracking

#### Frontend Optimization
- Enable Flutter web renderers for better performance
- Implement proper error boundaries
- Add offline capability for generated content

---

## 🚦 API Rate Limits & Constraints

### Pollinations AI
- **Rate Limit**: Generally unrestricted for public use
- **Image Size**: 1280x720 pixels
- **Format**: JPEG
- **Timeout**: 60 seconds per request

### Edge-TTS
- **Rate Limit**: Microsoft's fair use policy
- **Audio Length**: No specific limits
- **Format**: MP3
- **Quality**: Neural voice synthesis

### Resource Limitations
- **Concurrent Generations**: Limited by system resources
- **Storage**: Temporary files auto-managed
- **Memory**: MoviePy requires sufficient RAM for video processing

---

## 🔮 Future Enhancements

### Planned Features
- **Custom Voice Upload**: User-provided voice samples
- **Advanced Story Structures**: Non-linear narratives
- **Multi-character Stories**: Different voices per character
- **Background Music**: AI-generated soundtracks
- **Export Formats**: Additional video/audio formats
- **Batch Processing**: Multiple stories from single prompt

### Technical Improvements
- **Database Integration**: Persistent story storage
- **User Authentication**: Personal story libraries
- **Cloud Deployment**: Scalable infrastructure
- **Mobile Apps**: Native iOS/Android versions
- **Real-time Collaboration**: Multi-user story creation

---

## 📄 License & Credits

### Third-party Services
- **Pollinations AI** - Free image generation
- **Microsoft Edge-TTS** - Neural voice synthesis
- **Google TTS** - Fallback voice service

### Open Source Libraries
- **Flask** - Web framework
- **Flutter** - Frontend framework  
- **MoviePy** - Video processing
- **FFmpeg** - Media encoding

### Development
Created as a demonstration of modern AI integration with web technologies, showcasing the seamless combination of multiple AI services in a production-ready application.

---

**Note**: This application demonstrates the integration of multiple AI services (image generation, text-to-speech, natural language processing) with modern web technologies to create an engaging multimedia storytelling platform.
