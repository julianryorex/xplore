#!/usr/bin/env bash
# Reports imports that break the module-boundary rule in docs/PATTERNS.md
# ("Module boundaries: three layers, imports point down") and fails only when
# a violation appears that is not in the checked-in baseline, so the number of
# violations can go down but never up.
#
# Usage: scripts/check-imports.sh [--list] [--update-baseline]
set -euo pipefail

# ---- Layer membership: edit here when a folder changes layer ---------------
# Folders under lib/features/ that stitch features together; they may import
# any feature.
COMPOSITION_FEATURES="home agent onboarding dev"
# Folders under lib/features/ that may import the shared layer only, never
# another folder under lib/features/.
FEATURE_LAYER_FEATURES="trip itinerary gallery profile map location auth"
# The shared layer, and what it must not import besides features.
SHARED_DIR="lib/shared"
SHARED_FORBIDDEN_IMPORTS="package:flutter_bloc/ package:flutter/widgets.dart package:flutter/material.dart package:flutter/cupertino.dart"
# -----------------------------------------------------------------------------

FEATURES_DIR="lib/features"
GENERATED_DIR="lib/generated"
BASELINE="scripts/check-imports-baseline.txt"

LIST_ALL=0
UPDATE_BASELINE=0
for arg in "$@"; do
  case "$arg" in
    --list) LIST_ALL=1 ;;
    --update-baseline) UPDATE_BASELINE=1 ;;
    -h | --help)
      sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
      cat <<EOF

  --list             Print every violation, not just the per-feature summary.
  --update-baseline  Rewrite $BASELINE with the current violations.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (see --help)" >&2
      exit 2
      ;;
  esac
done

cd "$(dirname "$0")/.."
export LC_ALL=C # one sort order everywhere, so the baseline diffs cleanly

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
current="$work_dir/current"
allowed="$work_dir/allowed"

# One line per violation: "<source file> -> <imported file or package URI>".
find lib -name '*.dart' -not -path "$GENERATED_DIR/*" -print0 |
  xargs -0 awk \
    -v feature_layer="$FEATURE_LAYER_FEATURES" \
    -v features_dir="$FEATURES_DIR" \
    -v shared_dir="$SHARED_DIR" \
    -v shared_forbidden="$SHARED_FORBIDDEN_IMPORTS" '
    BEGIN {
      count = split(feature_layer, names, " ")
      for (i = 1; i <= count; i++) in_feature_layer[names[i]] = 1
      forbidden_count = split(shared_forbidden, forbidden, " ")
    }

    # Collapses "." and ".." segments so relative imports compare by real path.
    function normalize(path,    parts, n, i, depth, stack, out) {
      n = split(path, parts, "/")
      depth = 0
      for (i = 1; i <= n; i++) {
        if (parts[i] == "" || parts[i] == ".") continue
        if (parts[i] == ".." && depth > 0) { depth--; continue }
        stack[++depth] = parts[i]
      }
      out = stack[1]
      for (i = 2; i <= depth; i++) out = out "/" stack[i]
      return out
    }

    # Name of the folder directly under lib/features/, or "" for other paths.
    function feature_of(path,    rest) {
      if (index(path, features_dir "/") != 1) return ""
      rest = substr(path, length(features_dir) + 2)
      return index(rest, "/") ? substr(rest, 1, index(rest, "/") - 1) : ""
    }

    /^[ \t]*(import|export)[ \t]+["\047]/ {
      uri = $0
      sub(/^[ \t]*(import|export)[ \t]+["\047]/, "", uri)
      sub(/["\047].*$/, "", uri)

      if (index(uri, "package:xplore/") == 1) {
        target = "lib/" substr(uri, length("package:xplore/") + 1)
      } else if (uri ~ /^[a-z_]+:/) {
        target = uri
      } else {
        source_dir = FILENAME
        sub(/\/[^\/]*$/, "", source_dir)
        target = normalize(source_dir "/" uri)
      }

      source_feature = feature_of(FILENAME)
      target_feature = feature_of(target)
      violation = 0

      if (source_feature in in_feature_layer) {
        violation = (target_feature != "" && target_feature != source_feature)
      } else if (index(FILENAME, shared_dir "/") == 1) {
        violation = (target_feature != "")
        for (i = 1; i <= forbidden_count; i++) {
          if (index(target, forbidden[i]) == 1) violation = 1
        }
      }

      if (violation) print FILENAME " -> " target
    }
  ' | sort -u >"$current"

if [ "$UPDATE_BASELINE" -eq 1 ]; then
  {
    echo "# Module-boundary violations that existed when this file was last regenerated."
    echo "# make check-imports fails on any violation not listed here. Remove lines as"
    echo "# imports are fixed (make check-imports-baseline); never add lines by hand."
    cat "$current"
  } >"$BASELINE"
  echo "Wrote $(wc -l <"$current" | tr -d ' ') allowed violations to $BASELINE"
  exit 0
fi

if [ -f "$BASELINE" ]; then
  grep -v '^#' "$BASELINE" | grep -v '^$' | sort -u >"$allowed" || true
else
  : >"$allowed"
fi

# Prints "<group> (<n> imports in <m> files) -> <target>: <n>, ..." per source
# group, where the group is the source feature or the shared layer.
summarize() {
  awk -v features_dir="$FEATURES_DIR" -v shared_dir="$SHARED_DIR" '
    function group_of(path,    rest) {
      if (index(path, shared_dir "/") == 1) return "shared"
      rest = substr(path, length(features_dir) + 2)
      return substr(rest, 1, index(rest, "/") - 1)
    }
    {
      source = $1
      target = $3
      group = group_of(source)
      target_group = (index(target, features_dir "/") == 1) ? group_of(target) : target
      imports[group]++
      if (!((group, source) in seen_file)) { seen_file[group, source] = 1; files[group]++ }
      if (!((group, target_group) in per_target)) targets[group] = targets[group] " " target_group
      per_target[group, target_group]++
    }
    END {
      for (group in imports) {
        line = sprintf("  %-10s %3d imports in %2d files  ->", group, imports[group], files[group])
        n = split(substr(targets[group], 2), list, " ")
        for (i = 1; i <= n; i++) {
          line = line sprintf("%s %s %d", (i > 1 ? "," : ""), list[i], per_target[group, list[i]])
        }
        print line
      }
    }
  ' "$1" | sort
}

total=$(wc -l <"$current" | tr -d ' ')
violating_files=$(cut -d' ' -f1 "$current" | sort -u | wc -l | tr -d ' ')

echo "Module-boundary violations by source (rule: docs/PATTERNS.md):"
if [ "$total" -eq 0 ]; then
  echo "  none"
else
  summarize "$current"
fi
if [ "$LIST_ALL" -eq 1 ] && [ "$total" -gt 0 ]; then
  echo
  sed 's/^/  /' "$current"
fi

echo
echo "Total: $total violations in $violating_files files ($(wc -l <"$allowed" | tr -d ' ') allowed by $BASELINE)"
if [ -d "$SHARED_DIR" ]; then
  echo "Shared layer: $(find "$SHARED_DIR" -name '*.dart' | wc -l | tr -d ' ') files in $SHARED_DIR"
else
  echo "Shared layer: $SHARED_DIR does not exist yet (0 files)"
fi

# A folder in neither list is silently exempt from the rule, so make it visible.
for dir in "$FEATURES_DIR"/*/; do
  name=$(basename "$dir")
  case " $COMPOSITION_FEATURES $FEATURE_LAYER_FEATURES " in
    *" $name "*) ;;
    *) echo "Note: $FEATURES_DIR/$name is in no layer list in scripts/check-imports.sh, so its imports are not checked" ;;
  esac
done

new_violations=$(comm -23 "$current" "$allowed")
fixed_violations=$(comm -13 "$current" "$allowed")

if [ -n "$fixed_violations" ]; then
  echo
  echo "$(echo "$fixed_violations" | wc -l | tr -d ' ') baseline entries no longer occur. Run 'make check-imports-baseline' to lock in the progress."
fi

if [ -n "$new_violations" ]; then
  echo
  echo "FAILED: new module-boundary violations (not in $BASELINE):" >&2
  echo "$new_violations" | sed 's/^/  /' >&2
  echo "Fix the import (see 'When a feature needs something from another feature' in docs/PATTERNS.md)." >&2
  exit 1
fi
