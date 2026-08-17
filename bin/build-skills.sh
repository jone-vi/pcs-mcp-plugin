#!/usr/bin/env bash
#
# Packages the plugin's skills as ZIPs for Claude Desktop / claude.ai, which take
# an uploaded skill rather than a Claude Code plugin.
#
# One ZIP per skill, with the skill's own folder as the archive root — that is the
# layout the uploader expects, and a nested extra folder is rejected. The skills
# themselves are not copied or rewritten: the plugin directory is the single
# source of truth and these archives are built from it.
#
#   ./bin/build-skills.sh          -> dist/custom-reports.zip, ...
#
# Checks, because both failures are silent until upload time:
#   - the folder name must equal the frontmatter `name` (hard error — the
#     uploader rejects a mismatch)
#   - description length is reported against the documented 200-character limit
#     (warning only — the skills in this repo are well over it and in use, so
#     this is here to tell you the number, not to block the build)

set -euo pipefail

root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
skills="$root/plugins/telaris-pcs/skills"
dist="$root/dist"

[ -d "$skills" ] || { echo "no skills directory at $skills" >&2; exit 1; }
command -v zip >/dev/null || { echo "zip is not installed" >&2; exit 1; }

# Reads one frontmatter key, joining a folded scalar ("key: >-" followed by
# indented lines) into a single line the way YAML would.
frontmatter() {
    awk -v key="$2" '
        NR == 1 && $0 != "---" { exit 1 }
        NR > 1 && $0 == "---"  { exit }
        NR == 1 { next }

        # collecting the continuation lines of a folded scalar
        collecting {
            if( $0 ~ /^[ \t]+[^ \t]/ ) {
                line = $0
                sub( /^[ \t]+/, "", line )
                out = out == "" ? line : out " " line
                next
            }
            exit
        }

        index( $0, key ":" ) == 1 {
            value = substr( $0, length( key ) + 2 )
            sub( /^[ \t]+/, "", value )
            if( value == ">-" || value == ">" || value == "|" || value == "|-" ) {
                collecting = 1
                next
            }
            out = value
            exit
        }

        END { if( out != "" ) print out }
    ' "$1"
}

rm -rf "$dist"
mkdir -p "$dist"

status=0

for path in "$skills"/*/; do

    skill="$( basename "$path" )"
    manifest="$path/SKILL.md"

    if [ ! -f "$manifest" ]; then
        echo "FAIL $skill: no SKILL.md" >&2
        status=1
        continue
    fi

    name="$( frontmatter "$manifest" name || true )"
    description="$( frontmatter "$manifest" description || true )"

    if [ "$name" != "$skill" ]; then
        echo "FAIL $skill: frontmatter name is '$name', must match the directory name" >&2
        status=1
        continue
    fi
    if [ "${#name}" -gt 64 ]; then
        echo "FAIL $skill: name is ${#name} characters, limit is 64" >&2
        status=1
        continue
    fi
    if [ -z "$description" ]; then
        echo "FAIL $skill: no description in the frontmatter" >&2
        status=1
        continue
    fi

    ( cd "$skills" && zip -q -r "$dist/$skill.zip" "$skill" -x '.DS_Store' -x '*/.DS_Store' )

    note=''
    [ "${#description}" -gt 200 ] && note='  (over the documented 200 limit)'

    printf 'ok   %-24s %6s bytes, %2s files, description %4s chars%s\n' \
        "$skill.zip" \
        "$( wc -c < "$dist/$skill.zip" | tr -d ' ' )" \
        "$( find "$path" -type f | wc -l | tr -d ' ' )" \
        "${#description}" \
        "$note"

done

if [ "$status" -ne 0 ]; then
    echo "one or more skills would not upload" >&2
    exit "$status"
fi

echo
echo "upload from $dist via Claude > Settings > Capabilities > Skills > Upload skill"
