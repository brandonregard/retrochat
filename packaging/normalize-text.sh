#!/bin/sh
set -eu

mode=${1:?usage: normalize-text.sh lf|crlf|cr input output}
input=${2:?usage: normalize-text.sh lf|crlf|cr input output}
output=${3:?usage: normalize-text.sh lf|crlf|cr input output}

# Documentation must contain real line separators, never the two printable
# characters backslash+n. First normalize existing CR/LF combinations, then
# write the convention native to the target platform.
perl -0777 -pe 's/\r\n|\r/\n/g; s/\\n/\n/g' "$input" |
case "$mode" in
    lf) cat > "$output" ;;
    crlf) sed 's/$/\r/' > "$output" ;;
    cr) tr '\n' '\r' > "$output" ;;
    *) echo "unknown line-ending mode: $mode" >&2; exit 2 ;;
esac
