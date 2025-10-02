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


def synthesize_text(client, text: str, out_path: Path, language_code: str, voice_name: str, rate: float, pitch: float):
    input_text = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(language_code=language_code, name=voice_name)
    audio_config = texttospeech.AudioConfig(audio_encoding=texttospeech.AudioEncoding.MP3,
                                             speaking_rate=rate, pitch=pitch)
    response = client.synthesize_speech(input=input_text, voice=voice, audio_config=audio_config)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('wb') as out_f:
        out_f.write(response.audio_content)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--langs', default='ja', help='Comma-separated languages to generate (e.g. ja,en)')
    p.add_argument('--out', default='tts_output', help='Base output directory for MP3 files')
    p.add_argument('--project', default=None, help='Optional GCP project id (will try to detect from credentials if omitted)')
    p.add_argument('--voice-map', default='', help='Optional mapping like "ja:ja-JP-Wavenet-A,en:en-US-Wavenet-A"')
    p.add_argument('--rate', type=float, default=1.0, help='Speaking rate (default 1.0)')
    p.add_argument('--pitch', type=float, default=2.0, help='Pitch (default 2.0 for "cute" voice)')
    args = p.parse_args()

    langs = [s.strip() for s in args.langs.split(',') if s.strip()]
    if not langs:
        print('No languages specified via --langs')
        sys.exit(2)

    # parse voice map
    voice_map = {}
    if args.voice_map:
        for part in args.voice_map.split(','):
            if ':' in part:
                k, v = part.split(':', 1)
                voice_map[k.strip()] = v.strip()

    try:
        client = texttospeech.TextToSpeechClient()
    except Exception as e:
        print("Failed to initialize TextToSpeechClient. Ensure GOOGLE_APPLICATION_CREDENTIALS is set and google-cloud-texttospeech is installed.")
        raise

    # If project id not provided, try to read from credentials JSON referenced by
    # GOOGLE_APPLICATION_CREDENTIALS environment variable.
    project_id = args.project
    if not project_id:
        creds_path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS')
        if creds_path and os.path.exists(creds_path):
            try:
                import json
                with open(creds_path, 'r', encoding='utf-8') as cf:
                    j = json.load(cf)
                    if isinstance(j, dict) and 'project_id' in j:
                        project_id = j['project_id']
                        print(f'Detected project_id from credentials: {project_id}')
            except Exception:
                pass


    for lang in langs:
        # detect strings file path for language
        strings_path = Path(f'Attimuitehoi4-ios/{lang}.lproj/Localizable.strings')
        if not strings_path.exists():
            print(f"Strings file not found for {lang}: {strings_path} - skipping")
            continue

        items = parse_strings_file(strings_path)
        if not items:
            print(f"No strings found in the file for {lang}: {strings_path}")
            continue

        # default voice per language
        default_voice = voice_map.get(lang)
        if not default_voice:
            if lang == 'ja':
                default_voice = 'ja-JP-Wavenet-A'
            elif lang == 'en':
                default_voice = 'en-US-Wavenet-A'
            else:
                default_voice = None

        out_dir_lang = Path(args.out) / lang
        out_dir_lang.mkdir(parents=True, exist_ok=True)
        print(f"Found {len(items)} strings for {lang}. Generating MP3s to: {out_dir_lang}\n")

        # determine language code for Google API
        lang_code = 'ja-JP' if lang == 'ja' else 'en-US' if lang == 'en' else lang

        for key, val in items:
            if not val.strip():
                print(f"Skipping empty: {key}")
                continue
            filename = safe_filename(key) + '.mp3'
            out_path = out_dir_lang / filename
            voice_to_use = default_voice if default_voice else ''
            print(f"Generating {lang}/{filename} <- {val}")
            try:
                synthesize_text(client, val, out_path, lang_code, voice_to_use, args.rate, args.pitch)
            except Exception as e:
                msg = str(e)
                print(f"Failed to synthesize '{key}' for {lang}: {msg}")
                # If the error indicates the Text-to-Speech API is disabled, provide a helpful URL
                if 'SERVICE_DISABLED' in msg or 'Text-to-Speech API' in msg or 'has not been used' in msg:
                    if project_id:
                        print(f"It looks like the Text-to-Speech API is disabled for project '{project_id}'.")
                        print(f"Enable it here: https://console.developers.google.com/apis/api/texttospeech.googleapis.com/overview?project={project_id}")
                    else:
                        print("The Text-to-Speech API appears disabled for the project associated with your credentials.")
                        print("Enable it in the Google Cloud Console: https://console.developers.google.com/apis/library/texttospeech.googleapis.com")

    print('\nAll done.')


if __name__ == '__main__':
    main()
