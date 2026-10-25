#!/usr/bin/env bash
# Installs plasma-statbar components for the invoking user. Run as your normal user (thermal uses sudo).
# Usage: ./install.sh [all|thermal|netspeed]   (default: all)
set -euo pipefail
cd "$(dirname "$0")"
USER_NAME=$(id -un)
PLASMOIDS=~/.local/share/plasma/plasmoids

install_plasmoid() {
    mkdir -p "$PLASMOIDS"
    rm -rf "$PLASMOIDS/$1"
    cp -r "plasmoids/$1" "$PLASMOIDS/"
}

install_thermal() {
    sudo install -Dm755 thermal/bin/cpu-thermal-cap  /usr/local/bin/cpu-thermal-cap
    sudo install -Dm755 thermal/bin/thermal-profile  /usr/local/bin/thermal-profile
    sudo install -Dm755 thermal/lib/run              /usr/local/lib/thermal-profile/run
    sudo install -Dm644 thermal/systemd/cpu-thermal-cap.service /etc/systemd/system/cpu-thermal-cap.service
    sed "s/@USER@/$USER_NAME/g" thermal/polkit/50-thermal-profile.rules \
        | sudo install -Dm644 /dev/stdin /etc/polkit-1/rules.d/50-thermal-profile.rules

    # State file is user-owned so `thermal-profile` can write it without sudo.
    sudo install -d -o "$USER_NAME" /var/lib/thermal-profile
    [[ -f /var/lib/thermal-profile/current ]] || echo off > /var/lib/thermal-profile/current

    install -Dm644 thermal/desktop/thermal-profile.desktop ~/.local/share/applications/thermal-profile.desktop
    install_plasmoid org.hotdogb.thermalprofile

    sudo systemctl daemon-reload
    sudo systemctl enable cpu-thermal-cap.service
}

install_netspeed() {
    install_plasmoid org.hotdogb.netspeed
}

case "${1:-all}" in
    all)      install_thermal; install_netspeed ;;
    thermal)  install_thermal ;;
    netspeed) install_netspeed ;;
    *)        echo "Usage: $0 [all|thermal|netspeed]" >&2; exit 1 ;;
esac
echo "Installed. Add the widgets to a panel (restart plasmashell if they're not listed:"
echo "  systemctl --user restart plasma-plasmashell)"
