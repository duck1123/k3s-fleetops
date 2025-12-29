{ inputs, system, pkgs, ... }:
  pkgs.writeShellScript "generate-docs" ''
    set -euo pipefail
    # Change to the project root (where the script is run from)
    cd "$(dirname "$0")/../.." || exit 1
    OUTPUT_FILE="''${1:-docs/module-docs.md}"
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    cat > "$OUTPUT_FILE" <<'HEADER'
    # Module Documentation
    
    This documentation is automatically generated. See individual module files for option details.
    
    ---
    
    HEADER
    for d in modules/*/; do
      [ -f "$d/default.nix" ] && echo "## $(basename "$d")" >> "$OUTPUT_FILE" && echo "See \`$d/default.nix\`" >> "$OUTPUT_FILE" && echo "" >> "$OUTPUT_FILE"
    done
    echo "Generated: $(date)" >> "$OUTPUT_FILE"
    echo "Done: $OUTPUT_FILE"
  ''
