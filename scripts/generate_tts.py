#!/usr/bin/env python3
"""
generate_tts.py

Reads a Localizable.strings file (ja.lproj) and generates MP3 files for each
localized string using Google Cloud Text-to-Speech.

Auth: set the environment variable GOOGLE_APPLICATION_CREDENTIALS to point to
your service account JSON file that has access to the Text-to-Speech API.

Usage:
  python scripts/generate_tts.py \
      --strings Attimuitehoi4-ios/ja.lproj/Localizable.strings \
      --out tts_ja

Requirements:
  pip install -r requirements.txt

"""
import re
import os
import sys
import argparse
from pathlib import Path

try:
    from google.cloud import texttospeech
except Exception as e:
    print("Missing google-cloud-texttospeech. Run: pip install -r requirements.txt")
    raise


def parse_strings_file(path: Path):
    """Parse Apple .strings file into ordered (key, value) pairs."""
    pattern = re.compile(r'^\s*"(?P<key>(?:[^"\\]|\\.)+)"\s*=\s*"(?P<val>(?:[^"\\]|\\.)*)"\s*;')
    items = []
    with path.open('r', encoding='utf-8') as f:
        for line in f:
            m = pattern.match(line)
            if m:
                key = bytes(m.group('key'), 'utf-8').decode('unicode_escape')
                val = bytes(m.group('val'), 'utf-8').decode('unicode_escape')
                items.append((key, val))
    return items


def safe_filename(s: str) -> str:
    # Use key as filename; keep alnum and _-; replace others with underscore
    return re.sub(r'[^A-Za-z0-9_\-]', '_', s)


def synthesize_text(client, text: str, out_path: Path, voice_name: str, rate: float, pitch: float):
    input_text = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(language_code='ja-JP', name=voice_name)
    audio_config = texttospeech.AudioConfig(audio_encoding=texttospeech.AudioEncoding.MP3,
                                             speaking_rate=rate, pitch=pitch)
    response = client.synthesize_speech(input=input_text, voice=voice, audio_config=audio_config)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('wb') as out_f:
        out_f.write(response.audio_content)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--strings', default='Attimuitehoi4-ios/ja.lproj/Localizable.strings', help='Path to Localizable.strings (ja)')
    p.add_argument('--out', default='tts_ja', help='Output directory for MP3 files')
    p.add_argument('--voice', default='ja-JP-Wavenet-A', help='Google Cloud TTS voice name (e.g. ja-JP-Wavenet-A)')
    p.add_argument('--rate', type=float, default=1.0, help='Speaking rate (default 1.0)')
    p.add_argument('--pitch', type=float, default=2.0, help='Pitch (default 2.0 for "cute" voice)')
    args = p.parse_args()

    strings_path = Path(args.strings)
    if not strings_path.exists():
        print(f"Strings file not found: {strings_path}")
        sys.exit(2)

    items = parse_strings_file(strings_path)
    if not items:
        print("No strings found in the file.")
        sys.exit(1)

    try:
        client = texttospeech.TextToSpeechClient()
    except Exception as e:
        print("Failed to initialize TextToSpeechClient. Ensure GOOGLE_APPLICATION_CREDENTIALS is set and google-cloud-texttospeech is installed.")
        raise

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Found {len(items)} strings. Generating MP3s to: {out_dir}\n")
    for key, val in items:
        # Skip empty strings
        if not val.strip():
            print(f"Skipping empty: {key}")
            continue

        filename = safe_filename(key) + '.mp3'
        out_path = out_dir / filename
        print(f"Generating {filename} <- {val}")
        try:
            synthesize_text(client, val, out_path, args.voice, args.rate, args.pitch)
        except Exception as e:
            print(f"Failed to synthesize '{key}': {e}")

    print('\nAll done.')


if __name__ == '__main__':
    main()
