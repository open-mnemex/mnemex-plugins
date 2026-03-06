#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MARKETPLACE="${ROOT}/.claude-plugin/marketplace.json"

echo "[validate] Parsing marketplace manifest"
jq -e . "${MARKETPLACE}" >/dev/null

count="$(jq -r '.plugins | length' "${MARKETPLACE}")"
if [[ "${count}" -lt 1 ]]; then
  echo "No plugins defined in marketplace.json" >&2
  exit 1
fi

echo "[validate] Checking plugin manifest consistency"
for i in $(seq 0 $((count - 1))); do
  name="$(jq -r ".plugins[${i}].name" "${MARKETPLACE}")"
  source_rel="$(jq -r ".plugins[${i}].source" "${MARKETPLACE}")"
  version_market="$(jq -r ".plugins[${i}].version" "${MARKETPLACE}")"

  plugin_dir="${ROOT}/${source_rel#./}"
  plugin_manifest="${plugin_dir}/.claude-plugin/plugin.json"

  if [[ ! -f "${plugin_manifest}" ]]; then
    echo "Missing plugin manifest: ${plugin_manifest}" >&2
    exit 1
  fi

  jq -e . "${plugin_manifest}" >/dev/null

  name_plugin="$(jq -r '.name' "${plugin_manifest}")"
  version_plugin="$(jq -r '.version' "${plugin_manifest}")"

  if [[ "${name}" != "${name_plugin}" ]]; then
    echo "Plugin name mismatch: marketplace=${name}, plugin=${name_plugin}" >&2
    exit 1
  fi

  if [[ "${version_market}" != "${version_plugin}" ]]; then
    echo "Version mismatch for ${name}: marketplace=${version_market}, plugin=${version_plugin}" >&2
    exit 1
  fi
done

if command -v claude >/dev/null 2>&1; then
  echo "[validate] Running claude plugin validate"
  claude plugin validate "${MARKETPLACE}"
else
  echo "[validate] claude CLI not found; skipped claude plugin validate"
fi

echo "[validate] All checks passed"

