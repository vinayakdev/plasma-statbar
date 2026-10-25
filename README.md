# thermal-profile

Keep an Intel laptop CPU near a target temperature by lowering its max frequency in a feedback loop,
with switchable profiles, a menu, and a KDE Plasma 6 panel widget.

- `cpu-thermal-cap {normal|50-95}` — root loop: reads coretemp "Package id 0" every second, steps
  `scaling_max_freq` down 100 MHz when above target, back up when 4°C below. Restores stock on exit.
- `thermal-profile [status|json|list|cycle|menu|edit|<profile>|<50-95>]` — switches profiles via
  `cpu-thermal-cap.service`; the choice persists across reboots. No sudo needed (polkit rule).
- Plasma widget `org.hotdogb.thermalprofile` — shows the package temp; left-click for profiles,
  middle-click cycles.

Default profiles (`~/.config/thermal-profile/profiles`, created on first run):

| name        | target |
|-------------|--------|
| off         | no cap |
| quiet       | 70°C   |
| balanced    | 80°C   |
| performance | 86°C   |

## Install

Requires bash, systemd, polkit, an Intel CPU with `coretemp`; optional `zenity` (menu),
`notify-send`, KDE Plasma 6 (widget).

```sh
./install.sh
thermal-profile balanced
```

The temperature shown is the CPU package sensor — the same "CPU" number btop and most monitors show.
