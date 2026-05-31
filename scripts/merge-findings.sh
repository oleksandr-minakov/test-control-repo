#!/usr/bin/env bash
# Merge Aikido + Grype + Trivy findings into a single normalised JSON.
# Any of the three may be absent (test setup currently only runs Grype).
# Output shape:
#   {summary:{critical,high,medium,low,unknown}, findings:[{cve, severity, package, sources:[...]}]}
set -euo pipefail

aikido= ; grype= ; trivy= ; out=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --aikido) aikido="$2"; shift 2;;
    --grype)  grype="$2"; shift 2;;
    --trivy)  trivy="$2"; shift 2;;
    --out)    out="$2"; shift 2;;
    *) echo "merge-findings: unknown arg $1" >&2; exit 2;;
  esac
done
[[ -z "$out" ]] && { echo "merge-findings: --out required" >&2; exit 2; }

mkdir -p "$(dirname "$out")"

extract_grype() {
  [ -s "$1" ] || { echo '[]'; return; }
  jq '[.matches[]?
        | {cve: (.vulnerability.id // ""),
           severity: ((.vulnerability.severity // "unknown") | ascii_downcase),
           package: (.artifact.name // ""),
           source: "grype"}]' "$1"
}
extract_trivy() {
  [ -s "$1" ] || { echo '[]'; return; }
  jq '[.Results[]?.Vulnerabilities[]?
        | {cve: (.VulnerabilityID // ""),
           severity: ((.Severity // "UNKNOWN") | ascii_downcase),
           package: (.PkgName // ""),
           source: "trivy"}]' "$1"
}
extract_aikido() {
  [ -s "$1" ] || { echo '[]'; return; }
  jq '[.findings[]?
        | {cve: (.cve // ""),
           severity: ((.severity // "unknown") | ascii_downcase),
           package: (.package // ""),
           source: "aikido"}]' "$1"
}

g=$(extract_grype  "${grype:-/dev/null}")
t=$(extract_trivy  "${trivy:-/dev/null}")
a=$(extract_aikido "${aikido:-/dev/null}")

jq -n --argjson g "$g" --argjson t "$t" --argjson a "$a" '
  ($g + $t + $a) as $all
  | ($all | group_by(.cve + "|" + .package)) as $grouped
  | {
      summary: {
        critical: ([$all[] | select(.severity=="critical")] | length),
        high:     ([$all[] | select(.severity=="high")]     | length),
        medium:   ([$all[] | select(.severity=="medium")]   | length),
        low:      ([$all[] | select(.severity=="low")]      | length),
        unknown:  ([$all[] | select(.severity=="unknown")]  | length)
      },
      findings: ($grouped | map({
        cve: .[0].cve, severity: .[0].severity, package: .[0].package,
        sources: ([.[].source] | unique)
      }))
    }' > "$out"
