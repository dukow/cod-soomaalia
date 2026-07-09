# Cod Soomaali 🇸🇴

Offline Somali Text-to-Speech Android app. Uses the Meta MMS Somali model (`mms-tts-som`) converted to ONNX, running fully on-device with **sherpa-onnx** — no internet needed after install.

## How it works

- The GitHub Actions workflow creates a fresh Flutter project, copies in `app/lib` + `app/pubspec.yaml`, downloads the Somali ONNX model (~114 MB) from HuggingFace, bundles it into the APK assets, and builds release APKs.
- On first launch, the app copies the model from assets to internal storage (takes ~10–20 seconds, one time only).
- TTS generation runs in a background isolate so the UI never freezes. Long text is auto-split into sentence chunks and joined into one WAV.

## Repo structure (must be exactly like this)

```
your-repo/
├── .github/
│   └── workflows/
│       └── build-apk.yml      <-- folder name starts with a DOT: .github
├── app/
│   ├── lib/
│   │   └── main.dart
│   └── pubspec.yaml
└── README.md
```

## Setup (one time)

1. Create a new GitHub repo, e.g. `dukow/cod-soomaali`
2. Upload ALL files keeping the exact folder structure above
   - IMPORTANT: the workflows folder is `.github/workflows/` (with the dot). If uploading via web, create the file with path `.github/workflows/build-apk.yml`
3. Push to `main` — the build starts automatically (or go to Actions tab → "Build Cod Soomaali APK" → Run workflow)
4. Wait ~10–15 minutes. Download the APK from Actions → the run → Artifacts → `cod-soomaali-apks`
5. Install `app-arm64-v8a-release.apk` on your phone (use `app-armeabi-v7a-release.apk` only for very old phones)

## App features

- Somali text input (multi-line, any length — auto-chunked)
- Speed control 0.5x–2.0x
- Play / pause
- Share or save the WAV file (WhatsApp, Telegram, Files, etc.)
- 100% offline after install

## Notes

- APK is large (~130 MB) because the full model is bundled inside — this is what makes it work with zero internet.
- Model source: `willwade/mms-tts-multilingual-models-onnx` (som folder) on HuggingFace — pre-converted Meta MMS VITS model for sherpa-onnx.
- Voice quality is the standard Meta MMS Somali voice: clear but somewhat robotic. Good for news reading and long text.
