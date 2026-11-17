#!/usr/bin/env bash
# Thalia's own helper for testflight-diagnose.yml: after a failed export, finds Xcode's
# distribution logs (*.xcdistributionlogs in the temp folder) and writes Apple's reply to
#   ci-logs/distribution-<platform>.errors.txt  (lines that carry an error or reason)
#   ci-logs/distribution-<platform>.tail.txt    (the end of the standard log)
# E-mail addresses and long ids are masked: the ci-testflight branch is public.
#   usage: .github/scripts/distribution-log.sh ios|macos
set -uo pipefail
platform=${1:?ios or macos}
out="${LOG_DIR:-ci-logs}"
mkdir -p "$out"

mask() {
  sed -E \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email>/g' \
    -e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<id>/g' \
    -e 's/(Bearer|Authorization:)[[:space:]]+[^[:space:]]+/\1 <token>/g'
}

bundles=$(find "${TMPDIR:-/tmp}" /var/folders -maxdepth 6 -name '*.xcdistributionlogs' -mmin -120 2>/dev/null | sort)
if [ -z "$bundles" ]; then
  echo "No *.xcdistributionlogs found" | tee "$out/distribution-$platform.errors.txt"
  exit 0
fi
newest=$(echo "$bundles" | tail -1)
echo "Distribution log: $(basename "$newest")"
ls -la "$newest" | mask

{
  echo "== files =="
  (cd "$newest" && ls -1)
  for log in "$newest"/*.log; do
    [ -f "$log" ] || continue
    echo "== $(basename "$log") (lines with an error or reason) =="
    grep -iE "error|fail|reason|forbidden|unauthori|not (found|allowed|permitted)|agreement|status ?code|\"detail\"|\"title\"|\"code\"|invalid|denied|missing" "$log" \
      | grep -viE "^\s*$" | awk '!seen[$0]++' | head -120
  done
} | mask > "$out/distribution-$platform.errors.txt"

standard=$(ls "$newest"/IDEDistribution.standard.log 2>/dev/null || ls "$newest"/*.log 2>/dev/null | head -1)
[ -n "$standard" ] && tail -n 200 "$standard" | mask > "$out/distribution-$platform.tail.txt"

cat "$out/distribution-$platform.errors.txt"
exit 0
