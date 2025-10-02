#!/usr/bin/env python3
"""List available Google Cloud Text-to-Speech voices.

Usage:
  python3 scripts/list_tts_voices.py

Sets GOOGLE_APPLICATION_CREDENTIALS or uses ADC. Prints available voice names and supported languages/genders.
"""
from google.cloud import texttospeech

client = texttospeech.TextToSpeechClient()
resp = client.list_voices()
voices = resp.voices

for v in voices:
    print(f"{v.name}\tgender={v.ssml_gender}\tlanguages={','.join(v.language_codes)}")
