# plasma-statbar

Small KDE Plasma 6 panel widgets for keeping an eye on a laptop.

| Widget | ID | What it does |
|--------|----|--------------|
| Thermal Profile | `org.hotdogb.thermalprofile` | Shows CPU package temp and switches thermal-cap profiles |
| Net Speed | `org.hotdogb.netspeed` | Live download/upload rates |

## Install

```sh
./install.sh            # everything
./install.sh thermal    # thermal tool + widget only
./install.sh netspeed   # net speed widget only
```

Then right-click the panel → *Add Widgets…*. If they don't show up, run
`systemctl --user restart plasma-plasmashell`.

## Thermal Profile

Keeps an Intel CPU near a target temperature by lowering its max frequency in a feedback loop.

- `cpu-thermal-cap {normal|50-95}` — root loop: reads coretemp "Package id 0" every second, steps
  `scaling_max_freq` down 100 MHz when above target, back up when 4°C below. Restores stock on exit.
- `thermal-profile [status|json|list|cycle|menu|edit|<profile>|<50-95>]` — switches profiles via
  `cpu-thermal-cap.service`; the choice persists across reboots. No sudo needed (polkit rule).
- Widget: left-click for profiles, middle-click cycles.

Default profiles (`~/.config/thermal-profile/profiles`, created on first run):

| name        | target |
|-------------|--------|
| off         | no cap |
| quiet       | 70°C   |
| balanced    | 80°C   |
| performance | 86°C   |

Requires bash, systemd, polkit, an Intel CPU with `coretemp`; optional `zenity` (menu) and
`notify-send`. The temperature shown is the CPU package sensor — the same "CPU" number btop and
most monitors show.

## Net Speed

Reads `/proc/net/dev` every second. Panel shows stacked ↓/↑ rates; the popup has peak and
since-boot totals, a 60 s graph, an interface picker (auto = default route, all, or a specific
one) and a bits/bytes toggle. Middle-click toggles bits/bytes. No extra dependencies.
