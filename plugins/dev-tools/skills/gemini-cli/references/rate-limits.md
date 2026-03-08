# Gemini CLI Rate Limits & Model Reference

> Empirical data from testing Gemini CLI v0.30.0 on 2026-03-03.
> Auth: oauth-personal (idountang@gmail.com), Google One AI Pro tier.

## Tier Limits

| Tier | Price | Daily requests | Requests/min |
|------|-------|----------------|--------------|
| Free (Google account) | $0 | 1,000 | 60 |
| Google AI Pro | $19.99/mo | 1,500 | 120 |
| Google AI Ultra | $249.99/mo | 2,000 | 120 |

**Critical**: 1 prompt = 2+ API requests (router + main model). Effective
prompts/day is roughly **half** the stated request limit. Gemini CLI agent
mode and Gemini Code Assist share the same quota.

## Request Architecture

Every `gemini -p` call invokes two models:

| Phase | Model | Purpose | Latency |
|-------|-------|---------|---------|
| Router | gemini-2.5-flash-lite | Classify/route the request | ~1s |
| Main | gemini-3-flash-preview (auto) | Generate the answer | 9-44s |

Even "Say hi" takes ~20-40 seconds total.

## Concurrency Test Results (AI Pro, gemini-2.5-flash)

8 rounds per level, 15s between rounds, 3 min between levels.

| Concurrency | Total reqs | Wall time | Avg/req | 429 errors | Verdict |
|-------------|-----------|-----------|---------|------------|---------|
| 1 (serial) | 8 | 129s | 16.1s | 0 | Baseline |
| **2** | **16** | **122s** | **7.6s** | **0** | **Optimal** |
| 5 | 40 | 490s | 12.3s | 0 (hidden) | Unstable |
| 10 | 80 | 1027s | 12.8s | 0 (hidden) | Dangerous |
| 15 | ~15 | >56min | hung | - | Dead |

**Concurrency 2 is optimal**: 2.1x throughput vs serial, zero 429s.

Per-round wall time variance:

| Concurrency | Fastest | Slowest | Average |
|-------------|---------|---------|---------|
| 1 | 7s | 29s | 13s |
| 2 | 10s | 34s | 15s |
| 5 | 31s | 100s | 61s |
| 10 | 43s | 429s (!) | 128s |

## 429 Retry Behavior (from source code)

- Initial delay: **5 seconds**
- Backoff: 5s → 10s → 20s → 30s (cap)
- Max attempts: **10 retries**
- Behavior: 429s are silently consumed — manifests as extreme latency,
  not visible error messages. A single request can stall for minutes.

## Per-Minute Limit

- **Not exposed** in `/stats` or any CLI output
- Enforced server-side silently
- `/stats` only shows daily quota remaining percentage
- At AI Pro tier: 120 req/min stated ≈ 60 prompts/min effective

## Quota Consumption Reference

From the full test session (144 `gemini -p` calls):

| Model | Before | After | Consumed |
|-------|--------|-------|----------|
| gemini-2.5-flash | 97.6% | 79.9% | 17.7% |
| gemini-2.5-flash-lite | 98.1% | 97.5% | 0.6% |
| gemini-2.5-pro | 99.5% | 99.5% | 0% |

## Available Models

| Model | Best for | Quota pool |
|-------|----------|------------|
| `auto-gemini-3` (default) | General use, auto-routes | flash pool |
| `gemini-2.5-flash` | Batch ops, cost-sensitive | flash pool |
| `gemini-2.5-pro` | Complex reasoning, quality | separate pro pool |
| `gemini-3-flash-preview` | (auto-selected by router) | flash pool |
| `gemini-3.1-pro-preview` | (auto-selected for pro tasks) | separate pro pool |

Pro models have **independent sub-quotas**: even if total daily hasn't been
reached, a specific model can trigger 429.

## Built-in Tools

| Tool | Description |
|------|-------------|
| `read_file` | Read local files |
| `write_file` | Write local files |
| `run_shell_command` | Execute shell commands |
| `google_web_search` | Web search |
| `web_fetch` | Fetch web content |
| `grep_search` | Search file contents |

Also supports MCP servers and extensions (not tested).

## Output Formats

| Flag | Behavior | Best for |
|------|----------|----------|
| `-o text` | Streaming text | Piping, human reading |
| `-o json` | Complete JSON after finish | Structured parsing |
| `-o stream-json` | Streaming JSONL | Real-time processing |

All three have similar total latency (~22-27s for simple questions).
`-o text` is recommended for most use cases.

## `/stats` Command

**Interactive mode only** — cannot use with `-p`.

Shows:
- Auth method and tier
- Per-model daily quota remaining (percentage)
- Quota reset time
- Session performance metrics

Does NOT show: per-minute limits, absolute request counts.

## Known Issues

- [#2305](https://github.com/google-gemini/gemini-cli/issues/2305): 429 Too Many Requests
- [#12859](https://github.com/google-gemini/gemini-cli/issues/12859): Misleading quota for AI Ultra (~100 uses triggers limit)
- [#13842](https://github.com/google-gemini/gemini-cli/issues/13842): Show usage limit remaining in /stats
- "No capacity available" errors are server-side capacity issues, not personal quota
