# Noctalia setup helpers for niri

[group('niri')]
setup-noctalia:
    #!/usr/bin/env bash
    set -euo pipefail
    NIRI_DIR="$HOME/.config/niri"
    CONFIG="$NIRI_DIR/config.kdl"
    NOCTALIA_FILE="$NIRI_DIR/noctalia-custom.kdl"
    mkdir -p "$NIRI_DIR"
    touch "$CONFIG"

    # Keys Noctalia will bind. These will override any conflicting bind
    # already in config.kdl, because the "include" line is appended at
    # the end of config.kdl, and niri's binds are overridden positionally
    # (a bind defined later wins). See:
    # https://github.com/niri-wm/niri/wiki/Configuration:-Include#binds
    NOCTALIA_KEYS=(
        "Mod+Space"
        "Mod+S"
        "Mod+Comma"
        "XF86AudioRaiseVolume"
        "XF86AudioLowerVolume"
        "XF86AudioMute"
        "XF86MonBrightnessUp"
        "XF86MonBrightnessDown"
    )

    # Warn about any keys that already exist elsewhere in config.kdl —
    # these will be silently overridden once the include is in place.
    CONFLICTS=()
    for key in "${NOCTALIA_KEYS[@]}"; do
        key_escaped=$(printf '%s' "$key" | sed 's/[.[\*^$/+]/\\&/g')
        if grep -qE "^[[:space:]]*${key_escaped}[[:space:]]*\{" "$CONFIG"; then
            CONFLICTS+=("$key")
        fi
    done
    if [ ${#CONFLICTS[@]} -gt 0 ]; then
        echo "WARNING: the following keys are already bound in $CONFIG"
        echo "and will be overridden by Noctalia's binding once noctalia.kdl is included:"
        for key in "${CONFLICTS[@]}"; do
            echo "  - $key"
        done
        echo ""
    fi

    # Ask which wallpaper/overview style to use.
    OVERVIEW_CHOICE=$(ugum choose \
        "Option 1: Blurred overview wallpaper" \
        "Option 2: Stationary wallpaper" \
        "Option 3: Flat colored overview" \
        "Skip this section")

    case "$OVERVIEW_CHOICE" in
        "Option 1"*)
            OVERVIEW_BLOCK='// Blurred overview wallpaper (Option 1)
// NOTE: also requires enabling the [niri/backdrop] section in Noctalia'"'"'s
// own Settings app (not this file) for this to take effect.
layer-rule {
  match namespace="^noctalia-backdrop"
  place-within-backdrop true
}'
            ;;
        "Option 2"*)
            OVERVIEW_BLOCK='// Stationary wallpaper (Option 2)
// NOTE: should be used with the [niri/backdrop] section DISABLED in
// Noctalia'"'"'s own Settings app (not this file).
layer-rule {
  match namespace="^noctalia-wallpaper"
  place-within-backdrop true
}

layout {
  background-color "transparent"
}

overview {
  workspace-shadow {
    off
  }
}'
            ;;
        "Option 3"*)
            OVERVIEW_BLOCK='// Flat colored overview (Option 3)
// NOTE: should be used with the [backdrop] section DISABLED in
// Noctalia'"'"'s own Settings app (not this file).
overview {
  backdrop-color "#26233a"
}'
            ;;
        *)
            OVERVIEW_BLOCK='// Wallpaper/overview section skipped by user choice.'
            ;;
    esac

    # (Re)generate the dedicated Noctalia include file.
    cat > "$NOCTALIA_FILE" << 'NOCTALIA_EOF'
// Managed by ujust setup-noctalia — regenerated on every run.
// Do not hand-edit; changes here will be overwritten.

// Autostart
spawn-at-startup "noctalia"

// Compositor settings
window-rule {
  // Rounded corners for a modern look.
  geometry-corner-radius 20

  // Clips window contents to the rounded corner boundaries.
  clip-to-geometry true
}

// Floating Noctalia settings window.
window-rule {
  match app-id="dev.noctalia.Noctalia"
  open-floating true
  default-column-width { fixed 1080; }
  default-window-height { fixed 920; }
}

debug {
  // Allows notification actions and window activation from Noctalia.
  honor-xdg-activation-with-invalid-serial
}

// Blur
// CAUTION: requires niri >= 26.04. On older niri versions this block
// will cause a configuration error — check niri --version if unsure.
/* Apps: blur them all without xray so it looks more realistic. */
window-rule {
  background-effect {
    blur true
    xray false
  }
}

/*
  Noctalia
  Disable xray on all our surfaces so it looks more realistic.
  Noctalia publishes blur regions automatically when ext-background-effects is available.
*/
layer-rule {
  match namespace="^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"
  background-effect {
    xray false
    // blur false
  }
}

/* You can also fine-tune the blur effect globally. */
blur {
  passes 2        // more passes = stronger blur (default: 3)
  offset 3.0      // sample distance per pass (default: 3.0)
  noise 0.03      // grain overlay (default: 0.02)
  saturation 1.0  // color saturation boost (default: 1.5)
}

// IPC keybinds
binds {
    Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
    Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
    Mod+Comma { spawn-sh "noctalia msg settings-toggle"; }
    // Default is Mod+Comma, but that's overridden by niri's Mod+Comma
    Mod+Shift+Period  { consume-window-into-column; }
    XF86AudioRaiseVolume { spawn-sh "noctalia msg volume-up"; }
    XF86AudioLowerVolume { spawn-sh "noctalia msg volume-down"; }
    XF86AudioMute { spawn-sh "noctalia msg volume-mute"; }
    XF86MonBrightnessUp { spawn-sh "noctalia msg brightness-up"; }
    XF86MonBrightnessDown { spawn-sh "noctalia msg brightness-down"; }
}
NOCTALIA_EOF

    # Add overview block at the end so that we can escape all special characters in the text above
    echo $OVERVIEW_BLOCK >> "$NOCTALIA_FILE"

    echo "Wrote $NOCTALIA_FILE"

    # Wire it into config.kdl, once.
    if grep -qF "include \"$NOCTALIA_FILE\"" "$CONFIG"; then
        echo "config.kdl already includes $NOCTALIA_FILE — nothing to add."
    else
        printf '\n// Added by ujust setup-noctalia\ninclude "%s"\n' "$NOCTALIA_FILE" >> "$CONFIG"
        echo "Added 'include \"$NOCTALIA_FILE\"' to the end of $CONFIG."
    fi

    echo ""
    echo "Done. Restart your niri session (or reboot) for changes to take effect."
