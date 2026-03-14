#!/usr/bin/env python3
"""Claude Code session JSONL analyzer.

Modes:
  index     - List all sessions with metadata (date, size, first user message)
  skeleton  - Extract conversation flow: user messages, assistant text, tool names (skip bulky tool_results)
  thinking  - Extract all thinking/CoT blocks
  tools     - Summarize tool usage counts and patterns
  tokens    - Show token usage progression (input/output/cache per turn)
  search    - Search across sessions for a keyword in user messages or assistant text
  summary   - Comprehensive one-page summary of a session
  daily     - Cross-session daily summary by date (today/yesterday/YYYY-MM-DD/range)

Usage:
  python3 analyze_session.py index [--project <project-path>]
  python3 analyze_session.py skeleton <session-id-or-path> [--max-chars 200]
  python3 analyze_session.py thinking <session-id-or-path>
  python3 analyze_session.py tools <session-id-or-path>
  python3 analyze_session.py tokens <session-id-or-path>
  python3 analyze_session.py search <keyword> [--project <project-path>]
  python3 analyze_session.py summary <session-id-or-path>
  python3 analyze_session.py daily <date> [--project <project-path>] [-v]
"""

import json
import os
import sys
import glob
import argparse
from datetime import datetime
from pathlib import Path
from collections import Counter

DEFAULT_PROJECTS_DIR = os.path.expanduser("~/.claude/projects")
HISTORY_FILE = os.path.expanduser("~/.claude/history.jsonl")


def resolve_session_path(session_ref, project=None):
    """Resolve a session ID or path to the actual JSONL file path."""
    if os.path.isfile(session_ref):
        return session_ref
    # Search all project dirs
    search_dirs = []
    if project:
        search_dirs.append(os.path.join(DEFAULT_PROJECTS_DIR, project))
    else:
        search_dirs = glob.glob(os.path.join(DEFAULT_PROJECTS_DIR, "*"))
    for d in search_dirs:
        candidate = os.path.join(d, f"{session_ref}.jsonl")
        if os.path.isfile(candidate):
            return candidate
        # Partial match
        for f in glob.glob(os.path.join(d, f"{session_ref}*.jsonl")):
            return f
    return None


def iter_messages(path):
    """Yield parsed JSON objects from a JSONL file."""
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def parse_ts(ts):
    """Parse a timestamp (ISO string or milliseconds) to epoch milliseconds."""
    if not ts:
        return None
    if isinstance(ts, (int, float)):
        return int(ts)
    if isinstance(ts, str):
        # Try ISO format first
        for fmt in ("%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ",
                    "%Y-%m-%dT%H:%M:%S.%f%z", "%Y-%m-%dT%H:%M:%S%z"):
            try:
                dt = datetime.strptime(ts.replace("+00:00", "Z").replace("+0000", "Z"), fmt)
                return int(dt.timestamp() * 1000)
            except ValueError:
                continue
        # Try as numeric string
        try:
            return int(ts)
        except ValueError:
            return None
    return None


def format_ts(ts_ms):
    """Format a millisecond timestamp to readable string."""
    if not ts_ms:
        return "?"
    if isinstance(ts_ms, str):
        ts_ms = parse_ts(ts_ms)
        if not ts_ms:
            return "?"
    try:
        ts_ms = int(ts_ms)
    except (ValueError, TypeError):
        return "?"
    return datetime.fromtimestamp(ts_ms / 1000).strftime("%Y-%m-%d %H:%M:%S")


def truncate(text, max_chars=200):
    """Truncate text to max_chars."""
    if not text:
        return ""
    text = text.replace("\n", " ").strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars] + "..."


# ──────────────────────────────────────────────
# MODE: index
# ──────────────────────────────────────────────
def cmd_index(args):
    """List all sessions with metadata."""
    search_dirs = []
    if args.project:
        search_dirs.append(os.path.join(DEFAULT_PROJECTS_DIR, args.project))
    else:
        search_dirs = sorted(glob.glob(os.path.join(DEFAULT_PROJECTS_DIR, "*")))

    sessions = []
    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "*.jsonl")):
            size = os.path.getsize(f)
            mtime = os.path.getmtime(f)
            sid = os.path.basename(f).replace(".jsonl", "")
            project = os.path.basename(d)
            # Get first user message
            first_msg = ""
            timestamp = None
            for msg in iter_messages(f):
                if msg.get("type") == "user":
                    content = msg.get("message", {}).get("content", "")
                    ts = parse_ts(msg.get("timestamp"))
                    if isinstance(content, str) and content.strip():
                        first_msg = content.strip()
                        timestamp = ts
                        break
                    elif isinstance(content, list):
                        for b in content:
                            if isinstance(b, dict) and b.get("type") == "text":
                                first_msg = b.get("text", "").strip()
                                timestamp = ts
                                break
                        if first_msg:
                            break
            sessions.append({
                "sid": sid,
                "project": project,
                "size_mb": size / 1024 / 1024,
                "mtime": mtime,
                "first_msg": first_msg,
                "timestamp": timestamp,
            })

    sessions.sort(key=lambda x: x["mtime"], reverse=True)
    limit = args.limit or 30
    print(f"{'Date':<20} {'Size':>6} {'Project':<35} {'First Message'}")
    print("-" * 120)
    for s in sessions[:limit]:
        date = format_ts(s["timestamp"]) if s["timestamp"] else datetime.fromtimestamp(s["mtime"]).strftime("%Y-%m-%d %H:%M:%S")
        print(f"{date:<20} {s['size_mb']:>5.1f}M {s['project']:<35} {truncate(s['first_msg'], 60)}")
        if args.verbose:
            print(f"  ID: {s['sid']}")


# ──────────────────────────────────────────────
# MODE: skeleton
# ──────────────────────────────────────────────
def cmd_skeleton(args):
    """Extract conversation skeleton: user text, assistant text, tool names."""
    path = resolve_session_path(args.session)
    if not path:
        print(f"Session not found: {args.session}", file=sys.stderr)
        sys.exit(1)

    max_chars = args.max_chars or 200
    turn = 0
    for msg in iter_messages(path):
        mtype = msg.get("type")
        ts = format_ts(msg.get("timestamp"))

        if mtype == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str) and content.strip():
                # Filter out system injections
                text = content.strip()
                if text.startswith("<"):
                    continue
                print(f"\n[{ts}] USER: {truncate(text, max_chars)}")
                turn += 1
            elif isinstance(content, list):
                for b in content:
                    if isinstance(b, dict):
                        btype = b.get("type")
                        if btype == "text":
                            text = b.get("text", "").strip()
                            if text and not text.startswith("<"):
                                print(f"\n[{ts}] USER: {truncate(text, max_chars)}")
                                turn += 1
                        elif btype == "tool_result":
                            size = len(json.dumps(b))
                            print(f"         └─ [tool_result: {size // 1024}KB]")

        elif mtype == "assistant":
            content = msg.get("message", {}).get("content", [])
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict):
                        btype = b.get("type")
                        if btype == "text":
                            text = b.get("text", "").strip()
                            if text:
                                print(f"  ASSISTANT: {truncate(text, max_chars)}")
                        elif btype == "tool_use":
                            tool = b.get("name", "?")
                            inp = b.get("input", {})
                            # Show key info per tool
                            detail = ""
                            if tool in ("Read", "Glob", "Grep"):
                                detail = inp.get("file_path") or inp.get("pattern") or ""
                            elif tool == "Bash":
                                detail = truncate(inp.get("command", ""), 80)
                            elif tool == "Edit":
                                detail = inp.get("file_path", "")
                            elif tool == "Write":
                                detail = inp.get("file_path", "")
                            elif tool == "Task":
                                detail = inp.get("description", "")
                            elif tool == "WebSearch":
                                detail = inp.get("query", "")
                            elif tool == "WebFetch":
                                detail = inp.get("url", "")[:80]
                            if detail:
                                print(f"    -> [{tool}] {detail}")
                            else:
                                print(f"    -> [{tool}]")
                        elif btype == "thinking":
                            thinking = b.get("thinking", "")
                            print(f"    (thinking: {truncate(thinking, 80)})")


# ──────────────────────────────────────────────
# MODE: thinking
# ──────────────────────────────────────────────
def cmd_thinking(args):
    """Extract all thinking/CoT blocks."""
    path = resolve_session_path(args.session)
    if not path:
        print(f"Session not found: {args.session}", file=sys.stderr)
        sys.exit(1)

    idx = 0
    for msg in iter_messages(path):
        if msg.get("type") != "assistant":
            continue
        content = msg.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for b in content:
            if isinstance(b, dict) and b.get("type") == "thinking":
                thinking = b.get("thinking", "")
                idx += 1
                max_chars = args.max_chars or 0
                if max_chars > 0:
                    thinking = truncate(thinking, max_chars)
                print(f"\n{'='*60}")
                print(f"THINKING BLOCK #{idx} ({len(b.get('thinking', ''))} chars)")
                print(f"{'='*60}")
                print(thinking)


# ──────────────────────────────────────────────
# MODE: tools
# ──────────────────────────────────────────────
def cmd_tools(args):
    """Summarize tool usage."""
    path = resolve_session_path(args.session)
    if not path:
        print(f"Session not found: {args.session}", file=sys.stderr)
        sys.exit(1)

    tool_counts = Counter()
    tool_details = {}
    for msg in iter_messages(path):
        if msg.get("type") != "assistant":
            continue
        content = msg.get("message", {}).get("content", [])
        if not isinstance(content, list):
            continue
        for b in content:
            if isinstance(b, dict) and b.get("type") == "tool_use":
                name = b.get("name", "unknown")
                tool_counts[name] += 1
                if name not in tool_details:
                    tool_details[name] = []
                inp = b.get("input", {})
                if name == "Read":
                    tool_details[name].append(inp.get("file_path", "?"))
                elif name == "Bash":
                    tool_details[name].append(truncate(inp.get("command", ""), 60))
                elif name == "Edit":
                    tool_details[name].append(inp.get("file_path", "?"))
                elif name == "Write":
                    tool_details[name].append(inp.get("file_path", "?"))
                elif name == "Glob":
                    tool_details[name].append(inp.get("pattern", "?"))
                elif name == "Grep":
                    tool_details[name].append(inp.get("pattern", "?"))
                elif name == "Task":
                    tool_details[name].append(inp.get("description", "?"))
                elif name == "WebSearch":
                    tool_details[name].append(inp.get("query", "?"))

    print("=== Tool Usage Summary ===\n")
    for name, count in tool_counts.most_common():
        bar = "█" * count
        print(f"  {name:<20} {count:>3}  {bar}")
    print(f"\n  Total tool calls: {sum(tool_counts.values())}")

    if args.verbose:
        print("\n=== Tool Details ===\n")
        for name, details in sorted(tool_details.items()):
            print(f"  {name}:")
            for d in details[:10]:
                print(f"    - {d}")
            if len(details) > 10:
                print(f"    ... and {len(details) - 10} more")


# ──────────────────────────────────────────────
# MODE: tokens
# ──────────────────────────────────────────────
def cmd_tokens(args):
    """Show token usage progression."""
    path = resolve_session_path(args.session)
    if not path:
        print(f"Session not found: {args.session}", file=sys.stderr)
        sys.exit(1)

    turn = 0
    total_input = 0
    total_output = 0
    total_cache_create = 0
    total_cache_read = 0

    print(f"{'Turn':>4}  {'Input':>7}  {'CacheNew':>8}  {'CacheRead':>9}  {'TotalIn':>8}  {'Output':>7}  {'Model'}")
    print("-" * 75)

    seen_ids = set()
    for msg in iter_messages(path):
        if msg.get("type") != "assistant":
            continue
        m = msg.get("message", {})
        usage = m.get("usage", {})
        msg_id = m.get("id", "")
        if not usage or msg_id in seen_ids:
            continue
        seen_ids.add(msg_id)

        inp = usage.get("input_tokens", 0)
        out = usage.get("output_tokens", 0)
        cc = usage.get("cache_creation_input_tokens", 0)
        cr = usage.get("cache_read_input_tokens", 0)
        total_in = inp + cc + cr
        model = m.get("model", "?")

        total_input += inp
        total_output += out
        total_cache_create += cc
        total_cache_read += cr

        print(f"{turn:>4}  {inp:>7}  {cc:>8}  {cr:>9}  {total_in:>8}  {out:>7}  {model}")
        turn += 1

    print("-" * 75)
    grand_total_in = total_input + total_cache_create + total_cache_read
    print(f"{'SUM':>4}  {total_input:>7}  {total_cache_create:>8}  {total_cache_read:>9}  {grand_total_in:>8}  {total_output:>7}")

    # Cost estimate (approximate)
    # Opus: $15/M input, $75/M output, cache_read $1.5/M, cache_create $18.75/M
    cost_input = total_input * 15 / 1_000_000
    cost_output = total_output * 75 / 1_000_000
    cost_cache_create = total_cache_create * 18.75 / 1_000_000
    cost_cache_read = total_cache_read * 1.5 / 1_000_000
    total_cost = cost_input + cost_output + cost_cache_create + cost_cache_read
    print(f"\nEstimated cost: ${total_cost:.3f}")
    print(f"  Input: ${cost_input:.3f}  CacheCreate: ${cost_cache_create:.3f}  CacheRead: ${cost_cache_read:.3f}  Output: ${cost_output:.3f}")


# ──────────────────────────────────────────────
# MODE: search
# ──────────────────────────────────────────────
def cmd_search(args):
    """Search across sessions for a keyword."""
    keyword = args.keyword.lower()
    search_dirs = []
    if args.project:
        search_dirs.append(os.path.join(DEFAULT_PROJECTS_DIR, args.project))
    else:
        search_dirs = sorted(glob.glob(os.path.join(DEFAULT_PROJECTS_DIR, "*")))

    # Also search history.jsonl for fast lookup
    if os.path.isfile(HISTORY_FILE):
        print("=== Matches in history.jsonl (user inputs) ===\n")
        with open(HISTORY_FILE) as f:
            for line in f:
                try:
                    d = json.loads(line)
                    display = d.get("display", "")
                    if keyword in display.lower():
                        ts = format_ts(d.get("timestamp"))
                        sid = d.get("sessionId", "?")[:12]
                        proj = d.get("project", "?")
                        print(f"  [{ts}] {sid}  {truncate(display, 80)}")
                        print(f"    project: {proj}")
                except:
                    continue
        print()

    print("=== Deep search in session files ===\n")
    hits = 0
    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for f in sorted(glob.glob(os.path.join(d, "*.jsonl")), key=os.path.getmtime, reverse=True):
            sid = os.path.basename(f).replace(".jsonl", "")[:12]
            for msg in iter_messages(f):
                mtype = msg.get("type")
                if mtype not in ("user", "assistant"):
                    continue
                content = msg.get("message", {}).get("content", "")
                text = ""
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    for b in content:
                        if isinstance(b, dict) and b.get("type") in ("text", "thinking"):
                            text += b.get("text", "") + b.get("thinking", "") + " "
                if keyword in text.lower():
                    # Find the keyword in context
                    idx = text.lower().index(keyword)
                    start = max(0, idx - 40)
                    end = min(len(text), idx + len(keyword) + 40)
                    snippet = text[start:end].replace("\n", " ")
                    ts = format_ts(msg.get("timestamp"))
                    print(f"  [{ts}] {sid} ({mtype}): ...{snippet}...")
                    hits += 1
                    if hits >= (args.limit or 20):
                        print(f"\n  (showing first {hits} hits, use --limit to see more)")
                        return
                    break  # One hit per session is enough for search


# ──────────────────────────────────────────────
# MODE: summary
# ──────────────────────────────────────────────
def cmd_summary(args):
    """Comprehensive one-page summary of a session."""
    path = resolve_session_path(args.session)
    if not path:
        print(f"Session not found: {args.session}", file=sys.stderr)
        sys.exit(1)

    sid = os.path.basename(path).replace(".jsonl", "")
    size_mb = os.path.getsize(path) / 1024 / 1024
    tool_counts = Counter()
    user_messages = []
    assistant_texts = []
    thinking_blocks = []
    first_ts = None
    last_ts = None
    total_output_tokens = 0
    total_input_tokens = 0
    model_used = "?"

    seen_ids = set()
    for msg in iter_messages(path):
        mtype = msg.get("type")
        ts = parse_ts(msg.get("timestamp"))
        if ts:
            if not first_ts or ts < first_ts:
                first_ts = ts
            if not last_ts or ts > last_ts:
                last_ts = ts

        if mtype == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str) and content.strip() and not content.strip().startswith("<"):
                user_messages.append(content.strip())
            elif isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "text":
                        t = b.get("text", "").strip()
                        if t and not t.startswith("<"):
                            user_messages.append(t)

        elif mtype == "assistant":
            m = msg.get("message", {})
            usage = m.get("usage", {})
            msg_id = m.get("id", "")
            if usage and msg_id not in seen_ids:
                seen_ids.add(msg_id)
                total_output_tokens += usage.get("output_tokens", 0)
                total_input_tokens += (
                    usage.get("input_tokens", 0)
                    + usage.get("cache_creation_input_tokens", 0)
                    + usage.get("cache_read_input_tokens", 0)
                )
                model_used = m.get("model", model_used)

            content = m.get("content", [])
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict):
                        btype = b.get("type")
                        if btype == "tool_use":
                            tool_counts[b.get("name", "?")] += 1
                        elif btype == "text":
                            t = b.get("text", "").strip()
                            if t:
                                assistant_texts.append(t)
                        elif btype == "thinking":
                            thinking_blocks.append(b.get("thinking", ""))

    # Check subagents
    subagent_dir = path.replace(".jsonl", "") + "/subagents"
    subagent_count = 0
    if os.path.isdir(subagent_dir):
        subagent_count = len(glob.glob(os.path.join(subagent_dir, "*.jsonl")))

    duration_min = (last_ts - first_ts) / 1000 / 60 if first_ts and last_ts else 0

    print(f"{'='*60}")
    print(f"SESSION SUMMARY")
    print(f"{'='*60}")
    print(f"  ID:        {sid}")
    print(f"  Model:     {model_used}")
    print(f"  Size:      {size_mb:.1f} MB")
    print(f"  Duration:  {duration_min:.0f} min")
    print(f"  Time:      {format_ts(first_ts)} → {format_ts(last_ts)}")
    print(f"  Turns:     {len(user_messages)} user / {len(assistant_texts)} assistant")
    print(f"  Thinking:  {len(thinking_blocks)} blocks ({sum(len(t) for t in thinking_blocks)//1000}K chars)")
    print(f"  Tokens:    {total_input_tokens:,} in / {total_output_tokens:,} out")
    print(f"  Subagents: {subagent_count}")
    print()

    print("--- User Messages ---")
    for i, m in enumerate(user_messages):
        print(f"  {i+1}. {truncate(m, 100)}")
    print()

    if tool_counts:
        print("--- Tool Usage ---")
        for name, count in tool_counts.most_common():
            print(f"  {name:<20} {count:>3}")
    print()

    if thinking_blocks:
        print("--- Thinking Preview (first 3) ---")
        for i, t in enumerate(thinking_blocks[:3]):
            print(f"  #{i+1}: {truncate(t, 150)}")


# ──────────────────────────────────────────────
# MODE: daily
# ──────────────────────────────────────────────
def parse_date_range(date_str):
    """Parse date input into (start_date, end_date) as datetime objects.

    Accepts: today, yesterday, YYYY-MM-DD, YYYY-MM-DD:YYYY-MM-DD
    """
    from datetime import timedelta
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

    if date_str == "today":
        return today, today + timedelta(days=1)
    elif date_str == "yesterday":
        return today - timedelta(days=1), today
    elif ":" in date_str:
        parts = date_str.split(":")
        start = datetime.strptime(parts[0], "%Y-%m-%d")
        end = datetime.strptime(parts[1], "%Y-%m-%d") + timedelta(days=1)
        return start, end
    else:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d, d + timedelta(days=1)


def extract_session_digest(path):
    """Extract a lightweight digest from a session JSONL.

    Skips thinking blocks and tool_result blocks (the two biggest sources of bloat).
    Returns a dict with all the signals needed for a daily summary.
    """
    sid = os.path.basename(path).replace(".jsonl", "")
    project = os.path.basename(os.path.dirname(path))
    size_mb = os.path.getsize(path) / 1024 / 1024

    user_messages = []
    assistant_texts = []
    tool_calls = []
    files_touched = set()
    git_commits = []
    tool_counts = Counter()
    first_ts = None
    last_ts = None
    total_input = 0
    total_output = 0
    total_cache_create = 0
    total_cache_read = 0
    model_used = "?"
    seen_ids = set()

    for msg in iter_messages(path):
        mtype = msg.get("type")
        ts = parse_ts(msg.get("timestamp"))
        if ts:
            if not first_ts or ts < first_ts:
                first_ts = ts
            if not last_ts or ts > last_ts:
                last_ts = ts

        if mtype == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str) and content.strip() and not content.strip().startswith("<"):
                user_messages.append(content.strip())
            elif isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "text":
                        t = b.get("text", "").strip()
                        if t and not t.startswith("<"):
                            user_messages.append(t)
                    # skip tool_result blocks entirely

        elif mtype == "assistant":
            m = msg.get("message", {})
            usage = m.get("usage", {})
            msg_id = m.get("id", "")
            if usage and msg_id not in seen_ids:
                seen_ids.add(msg_id)
                total_input += usage.get("input_tokens", 0)
                total_output += usage.get("output_tokens", 0)
                total_cache_create += usage.get("cache_creation_input_tokens", 0)
                total_cache_read += usage.get("cache_read_input_tokens", 0)
                model_used = m.get("model", model_used)

            content = m.get("content", [])
            if isinstance(content, list):
                for b in content:
                    if not isinstance(b, dict):
                        continue
                    btype = b.get("type")
                    if btype == "text":
                        t = b.get("text", "").strip()
                        if t:
                            assistant_texts.append(t)
                    elif btype == "tool_use":
                        name = b.get("name", "?")
                        inp = b.get("input", {})
                        tool_counts[name] += 1
                        # Extract key details per tool
                        if name in ("Edit", "Write"):
                            fp = inp.get("file_path", "")
                            if fp:
                                files_touched.add(fp)
                        elif name == "Read":
                            fp = inp.get("file_path", "")
                            if fp:
                                tool_calls.append(f"Read {fp}")
                        elif name == "Bash":
                            cmd = inp.get("command", "")
                            # Extract git commit messages
                            if "git commit" in cmd:
                                git_commits.append(cmd)
                            tool_calls.append(f"Bash: {truncate(cmd, 80)}")
                        elif name == "Glob":
                            tool_calls.append(f"Glob: {inp.get('pattern', '?')}")
                        elif name == "Grep":
                            tool_calls.append(f"Grep: {inp.get('pattern', '?')}")
                    # skip thinking blocks entirely

    # Cost estimate
    cost_input = total_input * 15 / 1_000_000
    cost_output = total_output * 75 / 1_000_000
    cost_cache_create = total_cache_create * 18.75 / 1_000_000
    cost_cache_read = total_cache_read * 1.5 / 1_000_000
    total_cost = cost_input + cost_output + cost_cache_create + cost_cache_read

    duration_min = (last_ts - first_ts) / 1000 / 60 if first_ts and last_ts else 0

    return {
        "sid": sid,
        "path": path,
        "project": project,
        "size_mb": size_mb,
        "model": model_used,
        "first_ts": first_ts,
        "last_ts": last_ts,
        "duration_min": duration_min,
        "user_messages": user_messages,
        "assistant_texts": assistant_texts,
        "tool_counts": tool_counts,
        "files_touched": sorted(files_touched),
        "git_commits": git_commits,
        "total_input": total_input,
        "total_output": total_output,
        "total_cache_create": total_cache_create,
        "total_cache_read": total_cache_read,
        "total_cost": total_cost,
    }


def cmd_daily(args):
    """Cross-session daily summary for a date or date range."""
    start_dt, end_dt = parse_date_range(args.date)
    start_ms = int(start_dt.timestamp() * 1000)
    end_ms = int(end_dt.timestamp() * 1000)

    # Find all session files
    search_dirs = []
    if args.project:
        search_dirs.append(os.path.join(DEFAULT_PROJECTS_DIR, args.project))
    else:
        search_dirs = sorted(glob.glob(os.path.join(DEFAULT_PROJECTS_DIR, "*")))

    # Quick filter: use file mtime to narrow candidates
    candidate_files = []
    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "*.jsonl")):
            # Subagent files are in subdirectories, skip them
            parent = os.path.basename(os.path.dirname(f))
            if parent == "subagents":
                continue
            mtime_ms = int(os.path.getmtime(f) * 1000)
            # Generous filter: include if mtime is within 2 days of range
            if mtime_ms >= start_ms - 86400000 * 2 and mtime_ms <= end_ms + 86400000:
                candidate_files.append(f)

    # Extract digests and filter by actual timestamp
    digests = []
    for f in candidate_files:
        d = extract_session_digest(f)
        if not d["first_ts"]:
            continue
        # Session overlaps with date range if it started before end and ended after start
        if d["first_ts"] < end_ms and (d["last_ts"] or d["first_ts"]) >= start_ms:
            digests.append(d)

    digests.sort(key=lambda x: x["first_ts"])

    if not digests:
        date_label = args.date
        print(f"No sessions found for {date_label}")
        return

    # Header
    from datetime import timedelta
    if start_dt.date() == (end_dt - timedelta(days=1)).date():
        date_label = start_dt.strftime("%Y-%m-%d (%A)")
    else:
        date_label = f"{start_dt.strftime('%Y-%m-%d')} → {(end_dt - timedelta(days=1)).strftime('%Y-%m-%d')}"

    print(f"{'='*70}")
    print(f"  DAILY SUMMARY: {date_label}")
    print(f"{'='*70}")

    # Aggregate stats
    total_sessions = len(digests)
    total_duration = sum(d["duration_min"] for d in digests)
    total_cost = sum(d["total_cost"] for d in digests)
    total_input_all = sum(d["total_input"] + d["total_cache_create"] + d["total_cache_read"] for d in digests)
    total_output_all = sum(d["total_output"] for d in digests)
    all_tool_counts = Counter()
    all_files = set()
    all_commits = []
    for d in digests:
        all_tool_counts += d["tool_counts"]
        all_files.update(d["files_touched"])
        all_commits.extend(d["git_commits"])

    print(f"\n  Sessions: {total_sessions}    Duration: {total_duration:.0f} min    Cost: ${total_cost:.3f}")
    print(f"  Tokens:   {total_input_all:,} in / {total_output_all:,} out")
    print(f"  Files modified: {len(all_files)}    Tool calls: {sum(all_tool_counts.values())}")

    # Git commits
    if all_commits:
        print(f"\n{'─'*70}")
        print("  GIT COMMITS")
        print(f"{'─'*70}")
        for c in all_commits:
            print(f"  {truncate(c, 120)}")

    # Group by project
    by_project = {}
    for d in digests:
        by_project.setdefault(d["project"], []).append(d)

    for project, sessions in by_project.items():
        print(f"\n{'─'*70}")
        print(f"  PROJECT: {project}")
        print(f"{'─'*70}")

        for d in sessions:
            time_str = format_ts(d["first_ts"])
            dur = f"{d['duration_min']:.0f}min"
            cost = f"${d['total_cost']:.3f}"
            print(f"\n  [{time_str}] {dur} {cost} ({d['size_mb']:.1f}MB)")

            # User messages (intent)
            for i, m in enumerate(d["user_messages"]):
                prefix = "  Q:" if i == 0 else "    "
                print(f"    {prefix} {truncate(m, 100)}")

            # Assistant key responses (first and last, to show intent→outcome)
            if d["assistant_texts"]:
                if len(d["assistant_texts"]) == 1:
                    print(f"    A: {truncate(d['assistant_texts'][0], 100)}")
                else:
                    print(f"    A: {truncate(d['assistant_texts'][0], 100)}")
                    if len(d["assistant_texts"]) > 2:
                        print(f"       ... ({len(d['assistant_texts'])-2} more responses)")
                    print(f"    A: {truncate(d['assistant_texts'][-1], 100)}")

            # Files touched
            if d["files_touched"]:
                if len(d["files_touched"]) <= 5:
                    for fp in d["files_touched"]:
                        print(f"      M {fp}")
                else:
                    for fp in d["files_touched"][:3]:
                        print(f"      M {fp}")
                    print(f"      ... and {len(d['files_touched'])-3} more files")

            # Tool summary (compact)
            if d["tool_counts"]:
                tools_str = " | ".join(f"{n}:{c}" for n, c in d["tool_counts"].most_common(5))
                print(f"      Tools: {tools_str}")

    # Overall tool distribution
    if args.verbose and all_tool_counts:
        print(f"\n{'─'*70}")
        print("  TOOL DISTRIBUTION (ALL SESSIONS)")
        print(f"{'─'*70}")
        for name, count in all_tool_counts.most_common():
            bar = "█" * min(count, 50)
            print(f"  {name:<20} {count:>4}  {bar}")

    # All files modified
    if args.verbose and all_files:
        print(f"\n{'─'*70}")
        print("  ALL FILES MODIFIED")
        print(f"{'─'*70}")
        for fp in sorted(all_files):
            print(f"  {fp}")

    print()


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Claude Code session analyzer")
    sub = parser.add_subparsers(dest="mode", help="Analysis mode")

    p_index = sub.add_parser("index", help="List all sessions")
    p_index.add_argument("--project", help="Filter by project dir name")
    p_index.add_argument("--limit", type=int, default=30)
    p_index.add_argument("-v", "--verbose", action="store_true")

    p_skel = sub.add_parser("skeleton", help="Conversation skeleton")
    p_skel.add_argument("session", help="Session ID or path")
    p_skel.add_argument("--max-chars", type=int, default=200)

    p_think = sub.add_parser("thinking", help="Extract thinking blocks")
    p_think.add_argument("session", help="Session ID or path")
    p_think.add_argument("--max-chars", type=int, default=0, help="0 = full text")

    p_tools = sub.add_parser("tools", help="Tool usage summary")
    p_tools.add_argument("session", help="Session ID or path")
    p_tools.add_argument("-v", "--verbose", action="store_true")

    p_tokens = sub.add_parser("tokens", help="Token usage progression")
    p_tokens.add_argument("session", help="Session ID or path")

    p_search = sub.add_parser("search", help="Search across sessions")
    p_search.add_argument("keyword", help="Keyword to search for")
    p_search.add_argument("--project", help="Filter by project dir name")
    p_search.add_argument("--limit", type=int, default=20)

    p_summary = sub.add_parser("summary", help="Session summary")
    p_summary.add_argument("session", help="Session ID or path")

    p_daily = sub.add_parser("daily", help="Cross-session daily summary")
    p_daily.add_argument("date", help="Date: today, yesterday, YYYY-MM-DD, or YYYY-MM-DD:YYYY-MM-DD")
    p_daily.add_argument("--project", help="Filter by project dir name")
    p_daily.add_argument("-v", "--verbose", action="store_true", help="Show tool distribution and all files")

    args = parser.parse_args()
    if not args.mode:
        parser.print_help()
        sys.exit(1)

    dispatch = {
        "index": cmd_index,
        "skeleton": cmd_skeleton,
        "thinking": cmd_thinking,
        "tools": cmd_tools,
        "tokens": cmd_tokens,
        "search": cmd_search,
        "summary": cmd_summary,
        "daily": cmd_daily,
    }
    dispatch[args.mode](args)


if __name__ == "__main__":
    main()
