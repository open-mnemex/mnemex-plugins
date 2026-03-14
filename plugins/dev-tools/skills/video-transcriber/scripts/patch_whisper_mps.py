#!/usr/bin/env python3
"""Patch Whisper's timing.py for MPS compatibility.

Fixes: MPS tensors cannot convert to float64 directly.
Solution: Move .cpu() before .double() in the dtw() function.

Usage: python patch_whisper_mps.py
"""
import subprocess
import sys

def find_timing_py():
    """Locate whisper/timing.py in the active environment."""
    result = subprocess.run(
        [sys.executable, "-c", "import whisper.timing; print(whisper.timing.__file__)"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        # Try the whisper binary's Python
        whisper_bin = subprocess.run(["which", "whisper"], capture_output=True, text=True)
        if whisper_bin.returncode != 0:
            print("ERROR: whisper not found")
            sys.exit(1)
        # Read shebang to find Python
        with open(whisper_bin.stdout.strip()) as f:
            shebang = f.readline().strip().lstrip("#!")
        result = subprocess.run(
            [shebang, "-c", "import whisper.timing; print(whisper.timing.__file__)"],
            capture_output=True, text=True
        )
    if result.returncode != 0:
        print(f"ERROR: Cannot locate timing.py: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def patch(path):
    with open(path, "r") as f:
        content = f.read()

    old = "return dtw_cpu(x.double().cpu().numpy())"
    new = "return dtw_cpu(x.cpu().double().numpy())"

    if new in content:
        print(f"Already patched: {path}")
        return False
    if old not in content:
        print(f"WARNING: Expected pattern not found in {path}")
        print("  The file may have a different version. Manual check needed.")
        return False

    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print(f"Patched: {path}")
    print(f"  {old}")
    print(f"  -> {new}")
    return True

if __name__ == "__main__":
    timing_py = find_timing_py()
    patch(timing_py)
