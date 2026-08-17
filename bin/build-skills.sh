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
#   ./bin/build-skills.sh          -> dist/telaris-search.zip, ...
#
# The two frontmatter limits enforced here are the uploader's, not Claude Code's:
# name <= 64 characters, description <= 200. A plugin skill that overruns them
# works fine in Claude Code and fails to upload, which is a slow way to find out.

set -euo pipefail

root="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
skills="$root/plugins/telaris-pcs/skills"
dist="$root/dist"

[ -d "$skills" ] || { echo "no skills directory at $skills" >&2; exit 1; }
command -v zip >/dev/null || { echo "zip is not installed" >&2; exit 1; }

# reads one frontmatter key out of a SKILL.md
frontmatter() {
    awk -v key="$2" '
        NR == 1 && $0 != "---" { exit 1 }
        NR > 1 && $0 == "---"  { exit }
        NR > 1 {
            if( index( $0, key ": " ) == 1 ) {
                print substr( $0, length( key ) + 3 )
                exit
            }
        }
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
        # a mismatch between the folder and the declared name is an upload error
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
    if [ "${#description}" -gt 200 ]; then
        echo "FAIL $skill: description is ${#description} characters, limit is 200" >&2
        status=1
        continue
    fi

    ( cd "$skills" && zip -q -r "$dist/$skill.zip" "$skill" -x '.DS_Store' -x '*/.DS_Store' )

    printf 'ok   %-28s %6s bytes, description %3s/200\n' \
        "$skill.zip" "$( wc -c < "$dist/$skill.zip" | tr -d ' ' )" "${#description}"

done

if [ "$status" -ne 0 ]; then
    echo "one or more skills would not upload" >&2
    exit "$status"
fi

echo
echo "upload from $dist via Claude > Settings > Capabilities > Skills > Upload skill"
