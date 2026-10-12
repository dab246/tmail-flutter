#!/usr/bin/env bash
# Golden tests of every suite under golden/suites.
#
#   bash golden/run.sh                      verify text and pixel goldens
#   bash golden/run.sh --update             regenerate them; review the diff before committing
#   bash golden/run.sh --mutation           prove the pixel goldens notice each removed viewer block
#   bash golden/run.sh --suite email_view_html --pixel
#
# Text goldens run with `flutter test` in each suite. Pixel goldens render in
# the pinned image of golden/playwright/Dockerfile (linux/amd64), so local and
# CI pixels are identical.
set -euo pipefail

golden="$(cd "$(dirname "$0")" && pwd)"
flutter_cmd="${FLUTTER:-flutter}"
mode=verify
kinds="text pixel"
suites=()

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while (($#)); do
  case "$1" in
    --update) mode=update ;;
    --mutation) mode=mutation; kinds=pixel ;;
    --suite) shift; suites+=("${1:?--suite needs a name}") ;;
    --text) kinds=text ;;
    --pixel) kinds=pixel ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage 2 ;;
  esac
  shift
done

if ((${#suites[@]} == 0)); then
  for dir in "$golden"/suites/*/; do suites+=("$(basename "$dir")"); done
fi

has_kind() { grep -q "\"$2\"" "$golden/suites/$1/suite.json"; }

run_text() {
  local suite=$1
  [[ -f "$golden/suites/$suite/test/text_goldens_test.dart" ]] || return 0
  echo "== text goldens: $suite"
  (cd "$golden/suites/$suite" &&
    GOLDEN_UPDATE=$([[ $mode == update ]] && echo 1 || echo 0) "$flutter_cmd" test test/text_goldens_test.dart)
}

export_pixel() {
  local suite=$1
  echo "== export: $suite"
  (cd "$golden/suites/$suite" &&
    GOLDEN_EXPORT_DIR="$golden/playwright/.export" "$flutter_cmd" test test/export_documents_test.dart)
}

run_pixel() {
  local projects=() update_flag
  for suite in "$@"; do projects+=(--project "$suite:*"); done
  case $mode in
    update) update_flag=--update-snapshots=all ;;
    *) update_flag=--update-snapshots=none ;;
  esac
  if [[ $mode == update ]]; then
    # Regenerated from scratch, so goldens of removed cases do not linger.
    for suite in "$@"; do rm -rf "$golden/suites/$suite/goldens/pixel"; done
  else
    projects+=(--project golden-orphans)
  fi
  local image
  image=$(docker build --platform linux/amd64 -q "$golden/playwright")
  echo "== pixel goldens ($mode): $*"
  docker run --rm --platform linux/amd64 --ipc=host \
    -v "$golden:/golden" -w /golden/playwright \
    -e GOLDEN_EXPORT_DIR=/golden/playwright/.export \
    -e GOLDEN_MODE="$mode" -e CI="${CI:-}" \
    "$image" bash -c 'npm install --no-package-lock --no-audit --no-fund >/dev/null && npx playwright test "$@"' \
    _ "${projects[@]}" "$update_flag"
}

status=0
pixel_suites=()
for suite in "${suites[@]}"; do
  [[ -f "$golden/suites/$suite/suite.json" ]] || { echo "no suite named $suite" >&2; exit 2; }
  if [[ " $kinds " == *" text "* ]]; then run_text "$suite" || status=1; fi
  if [[ " $kinds " == *" pixel "* ]] && has_kind "$suite" pixel; then pixel_suites+=("$suite"); fi
done

if ((${#pixel_suites[@]})); then
  rm -rf "$golden/playwright/.export"
  for suite in "${pixel_suites[@]}"; do export_pixel "$suite"; done
  run_pixel "${pixel_suites[@]}" || status=1
fi

exit $status
