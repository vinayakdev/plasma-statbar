#!/usr/bin/env bash
# Installs thermal-profile system-wide for the invoking user. Run as your normal user (uses sudo).
set -euo pipefail
cd "$(dirname "$0")"
USER_NAME=$(id -un)

sudo install -Dm755 bin/cpu-thermal-cap  /usr/local/bin/cpu-thermal-cap
sudo install -Dm755 bin/thermal-profile  /usr/local/bin/thermal-profile
sudo install -Dm755 lib/run              /usr/local/lib/thermal-profile/run
sudo install -Dm644 systemd/cpu-thermal-cap.service /etc/systemd/system/cpu-thermal-cap.service
sed "s/@USER@/$USER_NAME/g" polkit/50-thermal-profile.rules \
    | sudo install -Dm644 /dev/stdin /etc/polkit-1/rules.d/50-thermal-profile.rules

# State file is user-owned so `thermal-profile` can write it without sudo.
sudo install -d -o "$USER_NAME" /var/lib/thermal-profile
[[ -f /var/lib/thermal-profile/current ]] || echo off > /var/lib/thermal-profile/current

install -Dm644 desktop/thermal-profile.desktop ~/.local/share/applications/thermal-profile.desktop
mkdir -p ~/.local/share/plasma/plasmoids
rm -rf ~/.local/share/plasma/plasmoids/org.hotdogb.thermalprofile
cp -r plasmoid/org.hotdogb.thermalprofile ~/.local/share/plasma/plasmoids/

sudo systemctl daemon-reload
sudo systemctl enable cpu-thermal-cap.service
echo "Installed. Add the 'Thermal Profile' widget to a panel (restart plasmashell if it's not listed)."
