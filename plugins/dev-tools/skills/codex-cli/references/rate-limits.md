# Codex CLI Rate Limits & Model Reference

> Empirical data from testing Codex CLI v0.107.0 on 2026-03-03.
> Auth: OpenAI OAuth (idountang@gmail.com), ChatGPT Pro tier.

## Auth & Tier Info

Codex CLI uses OpenAI OAuth (same account as ChatGPT). Tier determines
rate limits and available models.

| Tier | Price | Notes |
|------|-------|-------|
| ChatGPT Plus | $20/mo | Basic access, lower limits |
| ChatGPT Pro | $200/mo | Higher limits, priority access |
| API key | Pay-per-use | Separate billing, own rate limits |

## Request Architecture

Every `codex exec` call is a full agent session:

| Phase | What happens | Latency impact |
|-------|-------------|----------------|
| Boot | Load config, start sandbox | ~1s |
| File reads | Agent reads SOUL.md, USER.md, MEMORY.md etc. from working dir | ~5-15s |
| Thinking | Model reasoning + tool calls | ~10-30s |
| Response | Final answer | ~1-5s |

Even "What is 2+2?" takes 26-96s total due to agent bootstrapping.
The agent reads persona files (SOUL.md, USER.md) on every call, which
sometimes causes it to respond with onboarding text instead of the answer.

## Concurrency Test Results (ChatGPT Pro, gpt-5.1-codex-mini)

8 rounds per level, 15s between rounds, 3 min between levels.
264 total requests, **zero errors** across all levels.

| Concurrency | Total reqs | Avg/req (s) | Min (s) | Max (s) | Errors | Throughput | Verdict |
|-------------|-----------|-------------|---------|---------|--------|------------|---------|
| 1 (serial) | 8 | 51.8 | 26 | 96 | 0 | 1x baseline | Baseline |
| 2 | 16 | 54.4 | 22 | 135 | 0 | ~1.4x | Good |
| **5** | **40** | **49.0** | **21** | **76** | **0** | **~4x** | **Optimal** |
| 10 | 80 | 53.7 | 8 | 161 | 0 | ~5x | Works fine |
| 15 | 120 | 55.4 | 5 | 110 | 0 | ~8.5x | Works fine |

**Key finding: Codex handles high concurrency far better than Gemini CLI.**
No 429 errors, no hangs, no silent retries at any level tested.
Per-slot latency stays essentially flat (~50-55s avg) regardless of concurrency.

### Effective Throughput (reqs completed per round wall time)

| Concurrency | Avg round wall (s) | Reqs/round | Effective req/s | Speedup |
|-------------|-------------------|------------|-----------------|---------|
| 1 | 51.8 | 1 | 0.019 | 1.0x |
| 2 | 73.1 | 2 | 0.027 | 1.4x |
| 5 | 64.6 | 5 | 0.077 | 4.1x |
| 10 | 106.5 | 10 | 0.094 | 4.9x |
| 15 | 90.5 | 15 | 0.166 | 8.7x |

### Per-Round Wall Time Variance

| Concurrency | Fastest | Slowest | Average |
|-------------|---------|---------|---------|
| 1 | 26s | 96s | 52s |
| 2 | 46s | 135s | 73s |
| 5 | 50s | 76s | 65s |
| 10 | 70s | 161s | 107s |
| 15 | 77s | 110s | 91s |

## Concurrency Recommendations

| Use case | Concurrency | Why |
|----------|-------------|-----|
| Single task | 1 | Simple, predictable |
| Batch processing | **5** | Best throughput/overhead ratio |
| Aggressive batch | 10-15 | No errors observed, diminishing returns |
| Conservative | 2-3 | Lower resource usage |

**Concurrency 5 is recommended**: 4x throughput vs serial, zero errors,
reasonable per-round wall times (~65s). Higher concurrency works but
shows diminishing returns.

## Token Overhead

Each `codex exec` call in read-only mode consumed ~22,000 tokens for a
simple "2+2" question (observed from `--json` output). This is because
the agent reads persona files (SOUL.md, USER.md) and runs shell commands
(`pwd`, `cat`) during bootstrapping.

**Implication**: Codex exec is expensive per-call. Use batch operations
judiciously. For simple questions, the token overhead vastly exceeds the
actual answer.

## Available Models

| Model | Best for | Reasoning | Notes |
|-------|----------|-----------|-------|
| `gpt-5.3-codex` | General use, code generation | xhigh | Default |
| `gpt-5.1-codex-mini` | Batch ops, simple tasks | max: high | Fast, cheap; use `-c model_reasoning_effort=high` |
| `gpt-5.1-codex-max` | Complex reasoning | xhigh | Highest quality, most expensive |

## Codex Built-in Tools

When running with `--full-auto` or `-s workspace-write`/`danger-full-access`,
Codex has access to:

| Tool | Description |
|------|-------------|
| `shell` | Execute shell commands (sandboxed by mode) |
| `read_file` | Read local files |
| `write_file` | Write/create files |
| `apply_diff` | Apply unified diffs to files |

Even in `-s read-only` mode, the agent still uses `shell` to run read-only
commands like `pwd`, `cat`, `ls` during bootstrapping.

## Sandbox Mode Reference

| Mode | Reads | Writes | Shell | Use case |
|------|-------|--------|-------|----------|
| `read-only` | Yes | No | Read-only cmds | Q&A, analysis |
| `workspace-write` | Yes | Project dir only | Sandboxed | Code generation, review |
| `danger-full-access` | Yes | Anywhere | Unrestricted | System tasks (dangerous) |
| `--full-auto` | Yes | Project dir only | Sandboxed, auto-approve | Autonomous coding |

## Output Handling

Unlike Gemini CLI which has `-o text/json/stream-json`, Codex CLI uses:

| Flag | Behavior |
|------|----------|
| `-o FILE` | Write final agent message to file |
| `--json` | Print events to stdout as JSONL |
| (none) | Verbose agent trace to stdout (thinking, tool calls, everything) |

**Recommended pattern**: Always use `-o FILE` + `>/dev/null 2>&1` for scripted use.

## Known Quirks

- Agent reads SOUL.md/USER.md/MEMORY.md/BOOTSTRAP.md from working directory
  on every call. Sometimes responds with onboarding text instead of answering
  the actual question (~15% of calls in testing).
- `-C /tmp` can be used to run from a clean directory to avoid persona file
  interference, but then the agent can't read project files.
- `xhigh` reasoning is not supported by `gpt-5.1-codex-mini` — returns 400.
  Must override with `-c model_reasoning_effort=high`.

## Known Differences from Gemini CLI

| Aspect | Gemini CLI | Codex CLI |
|--------|-----------|-----------|
| Non-interactive | `gemini -p "prompt"` | `codex exec "prompt"` |
| Output format | `-o text/json/stream-json` | `-o FILE` (writes to file) |
| Auto-approve tools | `--yolo` | `-s read-only` or `--full-auto` |
| Code review | manual via pipe | `codex review` (built-in) |
| Sandbox | none | `read-only` / `workspace-write` / `danger-full-access` |
| Auth | Google OAuth | OpenAI OAuth |
| Default model | auto-gemini-3 | gpt-5.3-codex |
| Stderr noise | "Loaded cached credentials" | Agent trace (thinking, tool calls) |
| Prompt flag | `-p "prompt"` | Positional: `codex exec "prompt"` |
| Concurrency limit | 2 (429 at 5+) | **5+ works fine** (no 429s at 15) |
| Per-call latency | ~16s (flash) | ~52s (mini, includes agent bootstrap) |
| Token overhead | Low (direct API) | **~22k tokens** per call (agent session) |
