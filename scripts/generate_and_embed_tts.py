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
                # Ensure filename includes language suffix to avoid collisions when both en/ja exist
                name = f.name
                stem = Path(name).stem
                # If filename already ends with _<lang>, keep it; else append
                if not stem.endswith(f'_{lang}'):
                    new_name = f"{stem}_{lang}{f.suffix}"
                else:
                    new_name = name
                shutil.copy2(f, dest / new_name)
                print(f'copied {f} -> {dest / new_name}')


def rename_existing_project_files(langs):
    """Rename any existing project TTS files that don't have language suffixes by appending _<lang> to basename.
    This helps migrate previously generated files into the new naming scheme."""
    project_base = Path('Attimuitehoi4-ios/Attimuitehoi4-ios')
    resources_base = project_base / 'Resources' / 'TTS'
    if not resources_base.exists():
        return
    # For each lang subdir, rename files that don't include the lang suffix
    for lang in langs:
        lang_dir = resources_base / lang
        if not lang_dir.exists():
            continue
        for f in list(lang_dir.iterdir()):
            if f.is_file() and f.suffix.lower() in ('.mp3', '.wav'):
                stem = f.stem
                if not stem.endswith(f'_{lang}'):
                    new_name = f"{stem}_{lang}{f.suffix}"
                    new_path = lang_dir / new_name
                    print(f'Renaming existing resource {f} -> {new_path}')
                    f.rename(new_path)


def git_commit_and_push(message):
    subprocess.check_call(['git', 'add', '.'])
    subprocess.check_call(['git', 'commit', '-m', message])
    subprocess.check_call(['git', 'push'])


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--langs', default='ja', help='Comma-separated langs to generate (e.g. ja,en)')
    p.add_argument('--out', default='tts_output', help='Output directory used by generate_tts.py')
    p.add_argument('--skip-generate', action='store_true', help='Skip calling the generator and just rename/copy existing files')
    p.add_argument('--voice-map', default='ja:ja-JP-Wavenet-A,en:en-US-Wavenet-A', help='voice map passed to generator')
    p.add_argument('--friendly-map', default='', help="Friendly mapping like 'girl:ja:ja-JP-Neural2-C,boy:ja:ja-JP-Neural2-B,robot:ja:ja-JP-Chirp3-HD-Achernar' or leave empty to use built-in defaults.")
    p.add_argument('--project', default=None, help='Optional GCP project id to pass to generator')
    p.add_argument('--rate', type=float, default=1.0)
    p.add_argument('--pitch', type=float, default=2.0)
    args = p.parse_args()

    langs = [s.strip() for s in args.langs.split(',') if s.strip()]
    if not langs:
        print('No langs specified')
        sys.exit(1)

    # Build effective voice_map: --voice-map has priority. If not provided, expand friendly_map defaults.
    effective_voice_map = args.voice_map.strip() if args.voice_map else ''

    # parse friendly_map if provided and voice_map wasn't explicitly set
    if not effective_voice_map and args.friendly_map:
        # friendly_map format: 'label:lang:voice,...'
        parts = [p.strip() for p in args.friendly_map.split(',') if p.strip()]
        fm = {}
        for part in parts:
            # accept two forms: 'label:lang:voice' or 'label:voice' (assume first lang in langs)
            segs = part.split(':')
            if len(segs) == 3:
                label, lang_k, voice_id = segs
            elif len(segs) == 2 and len(langs) == 1:
                label, voice_id = segs
                lang_k = langs[0]
            else:
                print(f'Ignoring malformed friendly-map segment: {part}')
                continue
            fm.setdefault(lang_k, {})[label.strip()] = voice_id.strip()
        # Construct voice_map string like 'ja:ja-JP-Neural2-C,en:en-US-Neural2-C' using labels for default role names
        # For convenience, if user passed 'girl,boy,robot' as labels without explicit mapping, we will map them to built-in defaults below.
        # We'll set effective_voice_map as comma-separated lang:voice entries using the 'girl' label if present.
        # We'll also export the fm structure for later use by this script when copying files.
        # Build a fallback voice_map from known friendly labels if available
        builtins = {
            'girl': {'ja': 'ja-JP-Neural2-C', 'en': 'en-US-Neural2-C'},
            'boy': {'ja': 'ja-JP-Neural2-B', 'en': 'en-US-Neural2-B'},
            'robot': {'ja': 'ja-JP-Chirp3-HD-Achernar', 'en': 'en-US-Chirp3-HD-Achernar'},
        }
        # If friendly_map specified explicit voice IDs, use them; otherwise use builtins for labels present in fm
        entries = []
        for lang_k in langs:
            # pick label 'girl' if available else first label defined
            if lang_k in fm:
                # if mapping provided for this lang, choose the first label's voice as default
                # (this behavior is simple — UI should pass explicit mapping for clarity)
                first_label = next(iter(fm[lang_k]))
                entries.append(f"{lang_k}:{fm[lang_k][first_label]}")
            else:
                # try builtins
                if 'girl' in builtins and lang_k in builtins['girl']:
                    entries.append(f"{lang_k}:{builtins['girl'][lang_k]}")
        if entries:
            effective_voice_map = ','.join(entries)

    if not args.skip_generate:
        run_generate(langs, args.out, effective_voice_map, args.rate, args.pitch)
    else:
        print('Skipping generation step as requested (--skip-generate)')

    # If project already has TTS files, attempt to rename them into the new suffix scheme
    rename_existing_project_files(langs)

    copy_into_project(args.out, langs)
    commit_msg = f'Add generated TTS for langs: {" ".join(langs)}'
    try:
        git_commit_and_push(commit_msg)
    except subprocess.CalledProcessError as e:
        print('git commit/push failed:', e)
        print('You may wish to run git add/commit/push manually.')


if __name__ == '__main__':
    main()
