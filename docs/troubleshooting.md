# Troubleshooting

Find the message the script printed, or the symptom, below. If none fits, open a
[bug report](https://github.com/ThePsychDr/last-gen-hdr/issues/new/choose) with the full output.

Two commands answer most questions, so run them first:

```bash
bash scripts/hdr-keeper.sh <cube-ip> status
```

```bash
bash scripts/hdr-status.sh <cube-ip>
```

## Messages from the scripts

### `adb not found: install Android platform-tools or set ADB=/path/to/adb`

`adb` isn't on your PATH. Either add the platform-tools folder to your PATH, or put the path in front
of the command:

```bash
ADB=/path/to/platform-tools/adb bash scripts/hdr-keeper.sh <cube-ip> status
```

On Windows in Git Bash, that looks like `ADB=/c/platform-tools/adb.exe`.

### `could not connect to <cube-ip>:5555: …`

- **ADB Debugging** is off: Settings → My Fire TV → Developer Options.
- The IP is wrong or has changed: check Settings → My Fire TV → About → Network.
- The computer and the Cube are on different networks (a guest Wi-Fi, a VPN on the computer).
- The Cube is asleep. Wake it with the remote and try again.

If the Cube uses a port other than 5555, pass it as `<cube-ip>:<port>`.

### `<cube-ip>:5555 is '…': accept the "Allow USB debugging?" prompt on the TV, then run this again`

Look at the TV. Choose **Always allow from this computer**, then run the command again. If no prompt
shows, run `adb disconnect`, then run the script again so it reconnects and asks again.

`hdr-status.sh` doesn't make this check, so there you'll see adb's own `device unauthorized` error
instead. Same fix.

### `the HDMI input isn't on screen in passthrough: switch the Cube to it, then run start again`

`start` only runs with the HDMI input on screen, because the keeper doesn't survive the Cube leaving
it. Switch the Cube to the HDMI input and run `start` again.

If you *are* on the HDMI input and still get this, check **HDMI Input Passthrough** is on (Settings →
Display & Sounds). `hdr-status.sh` shows it as `passthrough=<setting>/<active>`; the second half reads
`on` while the input is on screen in passthrough.

### `… has Windows line endings; re-clone the repo or run: sed -i 's/\r$//' …`

The file on the Cube has to have Unix line endings. This happens when a Git set to convert line endings
checked the repo out, or an editor saved the file. Run the `sed` command it prints, or clone again.
The repo's `.gitattributes` keeps LF on a fresh clone.

### `failed to start`

The keeper was copied but no process showed up two seconds later. Run `status` to see its log, then
try `start` once more. If it keeps failing, open a bug report with the `status` output.

### `already running`

It's already holding. If the TV isn't in HDR anyway, see [running but the output is SDR](#running-but-the-output-is-sdr).

### `killed` after `stop`

It didn't stop within five seconds, so the script killed it. Nothing to fix; Fire OS takes the output
back either way.

## Symptoms

### `started`, but the TV doesn't switch to HDR

1. Run `status`. You want `output: HDR10-GAMMA_ST2084`. If it says that and the TV still shows SDR,
   the Cube is sending the flag and the TV isn't taking it:
   - turn on the enhanced/HDR setting for that HDMI port (Samsung: **Input Signal Plus**; general HDR
     advice, not tested with this setup);
   - try another HDMI port or cable;
   - make sure the TV's HDR is on in its picture settings.
2. If `output:` says `SDR`, see the next section.

### Running but the output is SDR

- `HDMI input on screen: no`: the Cube left the HDMI input. Switch back to it.
- `HDMI input on screen: yes` but `output: SDR`: the Cube most likely slept or left the input earlier and
  the keeper didn't recover (it doesn't survive either; the cause hasn't been measured). Run `stop`, then `start` on the HDMI input.
- The log's last line is a `stop`: it hit the 4-hour limit. Run `start` again.

### The TV blinks in and out of HDR

- Make sure you have the current scripts (`git pull`, or download the ZIP again). The first version of
  the keeper blinked (by eye); the current one didn't over a 12-minute test (by eye, and measured on
  the Cube as HDR10 in 97.6% of status reads).
- Watch `bash scripts/hdr-status.sh <cube-ip> 1` while it happens. A changing `hpd` or `hdcp` means
  the HDMI link itself re-synced, which is a cable/port/TV issue rather than the flag. Single `SDR`
  lines with the TV steady are normal reads landing in the gap between Fire OS's write and the
  keeper's.
- Please report it with the `hdr-status.sh` lines: blinking on other TVs hasn't been tested.

### It worked, then stopped

The Cube went to sleep, switched to the home screen or an app (it can do that on its own), or the
keeper hit its 4-hour limit. Switch to the HDMI input and `start` again.

### The status line shows `ready=0`

The Cube is asleep; the other driver fields are stale. Wake it up.

### The HDR field already says `HDR10-GAMMA_ST2084` before I start the keeper

The console is sending HDR itself: a game with its own HDR mode, or console HDR settings that send
it. That's not what this project is for. Use a game without HDR, or turn the console's HDR off.

### It looks too contrasty, the shadows are crushed, the edges look crunchy, the sky bands

Those are known limits, not a setup fault: steeper contrast and darker deep shadows (computed),
banding in smooth gradients (computed), crunchy edges (by eye, on RE6). See
[What's still off](../README.md#whats-still-off). If your game looks very different from that, say so
in a results report; per-game curves are on the roadmap.

### Colours look oversaturated

Possible: the colour space the flag carries hasn't been read yet. If it says BT.2020 over a BT.709
game, colours come out oversaturated. A report with your TV's signal info helps.

## The Python tool

- `python: command not found` on macOS or Linux: use `python3 tools/pq_read_closeness.py`.
- `--edge` fails with `No module named numpy` or `PIL`: that option needs `pip install numpy pillow`.
  The tables don't need any packages.

## Undo everything

```bash
bash scripts/hdr-keeper.sh <cube-ip> remove
```

Then reboot the Cube (unplug it, or `adb reboot`), and turn ADB Debugging off.
