#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $desc"
        ((++PASS))
    else
        echo "  FAIL: $desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        ((++FAIL))
    fi
}

# --- URL encoding ---
echo "==> URL encoding"

assert_eq "simple path" \
    "%2Fhome%2Fadmin%2Fmy-project" \
    "$(jq -rn --arg p "/home/admin/my-project" '$p | @uri')"

assert_eq "path with spaces" \
    "%2Fhome%2Fadmin%2Fmy%20project" \
    "$(jq -rn --arg p "/home/admin/my project" '$p | @uri')"

assert_eq "path with special chars" \
    "%2Fhome%2Fadmin%2Fproject%40v2%2B1" \
    "$(jq -rn --arg p "/home/admin/project@v2+1" '$p | @uri')"

# --- remote_projects.json filtering ---
echo "==> remote_projects.json filtering"

SAMPLE_PROJECTS='[
  {"environmentId": "ssh://192.168.64.5:22/home/admin/proj1", "name": "proj1"},
  {"environmentId": "ssh://192.168.64.10:22/home/admin/proj2", "name": "proj2"},
  {"environmentId": "ssh://192.168.64.5:22/home/admin/proj3", "name": "proj3"}
]'

FILTERED=$(echo "$SAMPLE_PROJECTS" | jq --arg ip "192.168.64.5" \
    '[.[] | select(.environmentId // "" | contains($ip) | not)]')

assert_eq "filters matching IP entries" \
    "1" \
    "$(echo "$FILTERED" | jq length)"

assert_eq "keeps non-matching entry" \
    "proj2" \
    "$(echo "$FILTERED" | jq -r '.[0].name')"

EMPTY_ENV='[{"name": "no-env"}, {"environmentId": "ssh://10.0.0.1/x"}]'
FILTERED_EMPTY=$(echo "$EMPTY_ENV" | jq --arg ip "10.0.0.1" \
    '[.[] | select(.environmentId // "" | contains($ip) | not)]')

assert_eq "handles missing environmentId" \
    "1" \
    "$(echo "$FILTERED_EMPTY" | jq length)"

assert_eq "keeps entry without environmentId" \
    "no-env" \
    "$(echo "$FILTERED_EMPTY" | jq -r '.[0].name')"

# --- JetBrains API response parsing ---
echo "==> JetBrains API response parsing"

SAMPLE_RELEASE='{
  "IIU": [{
    "build": "251.25410.129",
    "downloads": {
      "linux": {"link": "https://download.jetbrains.com/idea/ideaIU-2025.1.4.tar.gz"},
      "linuxARM64": {"link": "https://download.jetbrains.com/idea/ideaIU-2025.1.4-aarch64.tar.gz"}
    }
  }]
}'

assert_eq "extracts download URL" \
    "https://download.jetbrains.com/idea/ideaIU-2025.1.4-aarch64.tar.gz" \
    "$(echo "$SAMPLE_RELEASE" | jq -r '.IIU[0].downloads.linuxARM64.link // empty')"

assert_eq "extracts build number" \
    "251.25410.129" \
    "$(echo "$SAMPLE_RELEASE" | jq -r '.IIU[0].build')"

NO_ARM='{"IIU": [{"build": "251.25410.129", "downloads": {"linux": {"link": "https://example.com/x.tar.gz"}}}]}'

assert_eq "missing ARM64 returns empty" \
    "" \
    "$(echo "$NO_ARM" | jq -r '.IIU[0].downloads.linuxARM64.link // empty')"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
