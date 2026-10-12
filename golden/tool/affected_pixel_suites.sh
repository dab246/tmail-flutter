#!/usr/bin/env bash
# Prints, as a JSON array, the pixel suites a change affects.
#   golden/tool/affected_pixel_suites.sh <base-ref>        files changed since <base-ref>
#   golden/tool/affected_pixel_suites.sh --all             every pixel suite
#   golden/tool/affected_pixel_suites.sh --files <file>... the given changed files
# A suite is affected when a changed file matches one of its suite.json
# triggerPaths, lies in the suite, or lies in the shared golden code and data.
set -euo pipefail

golden="$(cd "$(dirname "$0")/.." && pwd)"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

# Quoted: these are match patterns, not paths to expand now.
shared=('golden/kit/*' 'golden/adapters/*' 'golden/corpus/*' 'golden/playwright/*' 'golden/run.sh' 'golden/tool/*'
  '.github/workflows/golden.yaml' 'pubspec.lock')

pixel_suites() {
  for descriptor in "$golden"/suites/*/suite.json; do
    jq -e '.kinds | index("pixel")' "$descriptor" >/dev/null && jq -r .id "$descriptor"
  done
}

matches_any() {
  local file=$1; shift
  local pattern
  for pattern in "$@"; do
    # Inside [[ ]], * also matches "/", so "dir/**" covers every file below dir.
    # shellcheck disable=SC2053
    [[ $file == $pattern ]] && return 0
  done
  return 1
}

affected() {
  local suite=$1; shift
  local patterns=("${shared[@]}" "golden/suites/$suite/*") trigger file
  while IFS= read -r trigger; do patterns+=("$trigger"); done \
    < <(jq -r '.triggerPaths[]' "$golden/suites/$suite/suite.json")
  for file in "$@"; do matches_any "$file" "${patterns[@]}" && return 0; done
  return 1
}

(($#)) || { echo "usage: $0 <base-ref> | --all | --files <file>..." >&2; exit 2; }
changed=()
case $1 in
  --all) pixel_suites | jq -R . | jq -sc .; exit 0 ;;
  --files) shift; changed=("$@") ;;
  *) while IFS= read -r file; do changed+=("$file"); done < <(git diff --name-only "$1"...HEAD) ;;
esac
for suite in $(pixel_suites); do
  if affected "$suite" "${changed[@]+"${changed[@]}"}"; then echo "$suite"; fi
done | jq -R . | jq -sc .
