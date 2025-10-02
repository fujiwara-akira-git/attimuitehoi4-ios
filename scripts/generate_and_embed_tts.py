#!/usr/bin/env python3
"""
generate_and_embed_tts.py

Runs the `generate_tts.py` script for specified languages, then copies the generated
MP3 files into the Xcode project's resource folder so they are tracked by git.

IMPORTANT: Xcode will not automatically include arbitrary files into the app bundle
unless they are added to the target. After running this script the generated files
will be placed in `Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/` and
committed to git. You should then add that folder to the Xcode project ("Add Files...")
as a folder reference or add individual files to the target's Copy Bundle Resources
if needed. Alternatively, keep the folder and add it to the project once; files
committed later will be visible in the Project Navigator.

Usage:
  python3 scripts/generate_and_embed_tts.py --langs ja,en --out tts_output

This script will:
  - call scripts/generate_tts.py to produce MP3 files under the provided --out dir
  - copy files into Attimuitehoi4-ios/Attimuitehoi4-ios/Resources/TTS/<lang>/
  - git add/commit/push the added files with a message

Set GOOGLE_APPLICATION_CREDENTIALS before running if you haven't already.
"""
import argparse
import subprocess
import shutil
from pathlib import Path
import sys
import os


def run_generate(langs, out, voice_map, rate, pitch):
    cmd = [sys.executable, 'scripts/generate_tts.py', '--langs', ','.join(langs), '--out', out]
    if voice_map:
        cmd += ['--voice-map', voice_map]
    cmd += ['--rate', str(rate), '--pitch', str(pitch)]
    print('Running:', ' '.join(cmd))
    subprocess.check_call(cmd)


def copy_into_project(out, langs):
    project_base = Path('Attimuitehoi4-ios/Attimuitehoi4-ios')
    resources_base = project_base / 'Resources' / 'TTS'
    for lang in langs:
        src = Path(out) / lang
        if not src.exists():
            print(f'skipping {lang} — no generated files at {src}')
            continue
        dest = resources_base / lang
        dest.mkdir(parents=True, exist_ok=True)
        for f in src.iterdir():
            if f.suffix.lower() in ('.mp3', '.wav'):
                shutil.copy2(f, dest / f.name)
                print(f'copied {f} -> {dest / f.name}')


def git_commit_and_push(message):
    subprocess.check_call(['git', 'add', '.'])
    subprocess.check_call(['git', 'commit', '-m', message])
    subprocess.check_call(['git', 'push'])


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--langs', default='ja', help='Comma-separated langs to generate (e.g. ja,en)')
    p.add_argument('--out', default='tts_output', help='Output directory used by generate_tts.py')
    p.add_argument('--voice-map', default='ja:ja-JP-Wavenet-A,en:en-US-Wavenet-A', help='voice map passed to generator')
    p.add_argument('--rate', type=float, default=1.0)
    p.add_argument('--pitch', type=float, default=2.0)
    args = p.parse_args()

    langs = [s.strip() for s in args.langs.split(',') if s.strip()]
    if not langs:
        print('No langs specified')
        sys.exit(1)

    run_generate(langs, args.out, args.voice_map, args.rate, args.pitch)
    copy_into_project(args.out, langs)
    commit_msg = f'Add generated TTS for langs: {" ".join(langs)}'
    try:
        git_commit_and_push(commit_msg)
    except subprocess.CalledProcessError as e:
        print('git commit/push failed:', e)
        print('You may wish to run git add/commit/push manually.')


if __name__ == '__main__':
    main()
