#!/usr/bin/env python3
"""UI wrapper to run TTS generation using friendly role labels.

This script is intended to be called from the app (during local development) or from CI.
It accepts the same role labels used in the UI and maps them to generator options.

Examples:
  # Generate girl/boy/robot for Japanese into tts_output
  python3 scripts/run_tts_for_ui.py --roles girl,boy,robot --langs ja --out tts_output

The script simply forwards role, langs, out and optional overrides to generate_and_embed_tts.py
"""
import argparse
import subprocess
import sys
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--roles', default='girl', help='Comma-separated roles to generate (e.g. girl,boy,robot)')
p.add_argument('--langs', default='ja', help='Comma-separated languages (e.g. ja,en)')
p.add_argument('--out', default='tts_output', help='Output dir')
p.add_argument('--skip-generate', action='store_true', help='Skip generation (use existing files)')
# Optional overrides for rate/pitch per role (simple form: girl:1.0:0.0,boy:1.0:0.0)
p.add_argument('--overrides', default='', help='Optional per-role overrides: role:rate:pitch,...')
args = p.parse_args()

cmd = [sys.executable, 'scripts/generate_and_embed_tts.py', '--roles', args.roles, '--langs', args.langs, '--out', args.out]
if args.skip_generate:
    cmd.append('--skip-generate')

# if overrides provided, convert to friendly-map-like voice override by embedding pitch/rate in presets is not currently supported
# Instead, pass nothing and rely on built-in presets; generate_and_embed_tts.py will use args.rate/args.pitch defaults if needed.

print('Running:', ' '.join(cmd))
ret = subprocess.call(cmd)
sys.exit(ret)
