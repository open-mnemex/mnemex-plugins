#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FACTS_ROOT="${HOME}/.mnemex/facts"
TEMPLATE="${REPO_ROOT}/templates/facts.example.yaml"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "Missing template: ${TEMPLATE}" >&2
  exit 1
fi

mkdir -p "${FACTS_ROOT}"

created=0
skipped=0

while IFS= read -r skill_md; do
  skill_dir="$(dirname "${skill_md}")"
  skill_name="$(basename "${skill_dir}")"
  dest_dir="${FACTS_ROOT}/${skill_name}"
  dest_file="${dest_dir}/facts.yaml"

  mkdir -p "${dest_dir}"
  if [[ -f "${dest_file}" ]]; then
    skipped=$((skipped + 1))
    continue
  fi

  cp "${TEMPLATE}" "${dest_file}"
  chmod 600 "${dest_file}"
  created=$((created + 1))
done < <(find "${REPO_ROOT}/plugins" -type f -name "SKILL.md" | sort)

cat <<EOF
Bootstrap complete.
Private facts root: ${FACTS_ROOT}
Created: ${created}
Skipped (already existed): ${skipped}

Next step:
1) Edit ~/.mnemex/facts/<skill-name>/facts.yaml
2) Keep personal data only in ~/.mnemex/facts (never in repo files)
EOF
