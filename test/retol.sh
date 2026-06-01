#!/bin/sh
# retol.sh -- apply realistic per-record test tolerances (see retol.awk) to the
# TEST.DAT section of regression inputs. The reference VALUES are never changed,
# only the tolerance column. Originals are tracked in git, so `git checkout -- <f>`
# reverts any file.
#
#   ./retol.sh                 rewrite every zmat.* / script.* in place
#   ./retol.sh zmat.004a ...   rewrite only the named files
#   ./retol.sh -n [files]      dry run: show which files would change (no writes)
#
# Idempotent: re-running on already-retol'd files is a no-op.

dir=$(dirname "$0")
dry=0
[ "$1" = "-n" ] && { dry=1; shift; }

if [ $# -gt 0 ]; then files="$*"; else files=$(ls "$dir"/zmat.* "$dir"/script.* 2>/dev/null | grep -vE '\.swp$'); fi

changed=0; total=0
for f in $files; do
   [ -f "$f" ] || continue
   grep -q 'TEST\.DAT' "$f" || continue          # no TEST.DAT section -> skip
   total=$((total+1))
   tmp="$f.retol.$$"
   awk -f "$dir/retol.awk" "$f" > "$tmp" || { rm -f "$tmp"; echo "awk failed on $f" >&2; continue; }
   if cmp -s "$f" "$tmp"; then rm -f "$tmp"; continue; fi
   changed=$((changed+1))
   if [ "$dry" = 1 ]; then echo "would change: $(basename "$f")"; rm -f "$tmp"
   else mv "$tmp" "$f"; fi
done
echo "retol: $changed of $total TEST.DAT files $( [ "$dry" = 1 ] && echo 'would change' || echo 'changed' )"
