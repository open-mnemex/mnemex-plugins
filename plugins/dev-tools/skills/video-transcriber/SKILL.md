---
name: video-transcriber
description: >
  Transcribe video/audio to structured Markdown using yt-dlp + OpenAI Whisper.
  Handles YouTube and other video platforms. Produces timestamped, proofread transcripts.
  Use when the user wants to: (1) transcribe a video or audio file to text,
  (2) create subtitles or a transcript from a speech/lecture/podcast,
  (3) convert YouTube video to text, (4) generate SRT/VTT subtitles.
  Triggers (EN): "transcribe this video", "convert to text", "speech to text",
  "generate transcript", "create subtitles", "whisper transcribe".
  Triggers (中文): "转录", "转成文字", "语音转文字", "生成字幕", "逐字稿".
---

# Video Transcriber

Transcribe video/audio to structured Markdown via yt-dlp + OpenAI Whisper (large-v3) on Apple Silicon MPS.

## Prerequisites

- `yt-dlp` (with node for YouTube JS challenges)
- `whisper` (OpenAI Whisper CLI, `brew install openai-whisper`)
- `ffmpeg`
- Apple Silicon Mac (for MPS acceleration)

## Workflow

### 1. Download Audio

Extract audio only (no video) to save time/space:

```bash
yt-dlp --js-runtimes node -f 'ba[ext=m4a]/ba' \
  -o '~/Downloads/BASENAME.%(ext)s' "URL"
```

For local files, skip this step.

### 2. Patch Whisper for MPS

**CRITICAL**: Run `scripts/patch_whisper_mps.py` before first use with `--word_timestamps True` on MPS.
Whisper's `timing.py` calls `.double().cpu()` which fails on MPS (no float64 support).
The patch reorders to `.cpu().double()`.

```bash
python scripts/patch_whisper_mps.py
```

Only needed once per Whisper installation/upgrade.

### 2b. Test with 1-Minute Clip

Always verify MPS + parameters work before running the full file:

```bash
ffmpeg -i INPUT.m4a -t 60 -c copy /tmp/test_1min.m4a -y
whisper /tmp/test_1min.m4a --model large-v3 --device mps \
  --language LANG --temperature_increment_on_fallback 2 \
  --word_timestamps True --verbose True
```

If this crashes, fix before proceeding. Common failures: MPS patch not applied, NaN in sampling.

### 3. Transcribe

```bash
PYTHONUNBUFFERED=1 whisper INPUT.m4a \
  --model large-v3 \
  --device mps \
  --language LANG \
  --temperature_increment_on_fallback 2 \
  --initial_prompt "CONTEXT_PROMPT" \
  --word_timestamps True \
  --hallucination_silence_threshold 2 \
  --output_dir OUTPUT_DIR \
  --output_format all \
  --verbose True \
  2>&1 | tee OUTPUT_DIR/whisper_log.txt
```

Key parameters:

| Parameter | Value | Why |
|-----------|-------|-----|
| `--device mps` | Apple GPU | 3-4x faster than CPU |
| `--temperature_increment_on_fallback 2` | >1.0 | Disables fallback; MPS produces NaN with sampling. **Do NOT use 0** (ZeroDivisionError in np.arange) |
| `--initial_prompt` | Topic keywords | Guides model on domain terms, reduces errors |
| `--hallucination_silence_threshold 2` | seconds | Prevents hallucinated text during silence |
| `PYTHONUNBUFFERED=1` | env var | Prevents output buffering when piping to tee |

**Speed options** (trade quality for speed):
- `--beam_size 1 --best_of 1` — ~3x faster, greedy decoding
- `--condition_on_previous_text False` — slightly faster, less coherent across windows

### 4. Handle Failures

**Hallucination loops** (same phrase repeating): Re-transcribe the segment:

```bash
PYTHONUNBUFFERED=1 whisper INPUT.m4a \
  --clip_timestamps START_SEC,END_SEC \
  --model large-v3 --device mps --language LANG \
  --temperature_increment_on_fallback 2 \
  --initial_prompt "ADJUSTED_PROMPT_WITH_SURROUNDING_CONTEXT" \
  --word_timestamps True \
  --hallucination_silence_threshold 2 \
  --output_dir OUTPUT_DIR_RESUME \
  --output_format all --verbose True
```

Output to a separate directory to avoid overwriting the first run.

**MPS out of memory**: Fall back to `--device cpu --threads 8`.

### 5. Proofread

If a reference transcript/article exists (news articles, blog posts, etc.):
1. Search the web for the speech title + "全文" / "transcript"
2. Compare against Whisper output to fix proper nouns, technical terms, homophones
3. Mark uncertain words with `【?word】`

Common Chinese transcription errors:
- Homophones: 自身↔滋生, 显著↔显度, 家数↔加速
- Proper nouns: names, organization names
- Acronyms spoken as letters: GDP, CPI → sometimes phonetically transcribed
- Hallucination: repeated phrases at segment boundaries

### 6. Format Transcript

Produce a structured Markdown file:

```markdown
# TITLE

> 来源：SOURCE
> 演讲者：SPEAKER
> 时长：DURATION
> 转录日期：DATE
> 转录模型：OpenAI Whisper large-v3

---

**[00:00:31]**
First paragraph of speech...

**[00:03:42]**
Second paragraph...
```

Formatting rules:
- Merge consecutive short SRT segments into natural paragraphs (3-8 sentences)
- Timestamp `**[HH:MM:SS]**` at each paragraph start (from SRT)
- Audience reactions in parentheses:（掌声）（笑声）
- Uncertain words: `【?uncertain_word】`
- Use Chinese punctuation (，。！？) for Chinese content
- Preserve verbatim content; do not summarize or delete

### 7. Generate Corrected Subtitle

After proofreading and formatting the transcript, generate a corrected SRT file:

1. Use original SRT timestamps as the skeleton
2. Replace text with proofread content from the transcript
3. Merge segments from multiple runs (first run + resume + gap re-transcription)
4. Split long subtitles: max ~40 Chinese chars per line, max 2 lines per entry
5. Remove all `【?...】` markers (not needed in subtitles)
6. Ensure sequential numbering and monotonically increasing timestamps
7. Save as `BASENAME_corrected.srt` (UTF-8)

## Output Files

| File | Description |
|------|-------------|
| `BASENAME.m4a` | Downloaded audio |
| `BASENAME.txt` | Raw Whisper text |
| `BASENAME.srt` | Raw Whisper SRT |
| `BASENAME.json` | Full JSON with confidence scores |
| `BASENAME_transcript.md` | Final formatted transcript (Markdown) |
| `BASENAME_corrected.srt` | Proofread subtitle for video players |
