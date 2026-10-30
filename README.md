# last-gen-hdr

Play PS3- and PS4-era games in HDR on an HDR TV, with a Fire TV Cube (3rd gen) you may already own.
No game patch, no root, no box to buy.

The console plugs into the Cube's HDMI input. A small script, started over ADB, keeps the Cube's
output flagged as HDR10, so the TV reads the game's own picture as HDR.

<!-- video link goes here before the repo goes public -->

## Why it works

Games from the PS3 and PS4 era already light their scenes in HDR inside the engine. At the end of each
frame they squeeze that light down into an SDR picture (tone mapping), because that's what TVs took
at the time. The bright parts aren't thrown away; they're packed into the top of the signal.

HDR10 TVs use a different curve (PQ) to turn signal values into brightness. Flag the console's picture
as HDR10 and the TV reads those same values on the PQ curve, which unpacks the top of the range back
out toward the TV's peak brightness while keeping every tone in order.

How close it lands, computed for typical game tone-map curves (generic curves, not measured from any
one game; reproduce with `python tools/pq_read_closeness.py`):

| Tone-map curve | Mid-grey read as HDR10 | HDR reference for mid-grey |
|---|---|---|
| Hable filmic | 30 nits | 26 nits (ITU-R BT.2408) |
| ACES fit | 36 nits | 26 nits |
| Reinhard | 43 nits | 26 nits |

So mid-tones land close to where HDR content puts them, and highlights get real HDR headroom. It isn't
mastered HDR (see [What's still off](#whats-still-off)), but on the tested TV it looks like HDR.

The Cube is what makes this possible without extra hardware. Its HDMI input can pass the console's
signal straight through, and from a plain ADB shell you can tell its HDMI driver to send the HDR10
flag. Fire OS puts SDR back about once a frame, so the keeper re-sends the flag back to back. Measured
on the Cube with a PS3 game: the output read HDR10 in 97.6% of status reads over 12 minutes (lowest
one-second window 95%, longest SDR gap about 30 ms), and no blink was visible on the TV.

## What you need

- **Fire TV Cube, 3rd gen (2022)**, model AFTGAZL. This is the one with an HDMI input. Other Fire TV
  devices are untested and most have no HDMI input.
- **An HDR10 TV.** Tested on a Samsung S95B.
- **A console** on the Cube's HDMI input. Tested with a PS3, and a PS5 running a PS4 game.
- **A computer** on the same network as the Cube, with
  [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`) and a
  bash shell: Git Bash on Windows, Terminal on macOS, any shell on Linux.
- Optional, for the tool: Python 3.

## Setup (once)

1. **Get the scripts.** Download this repo (green Code button → Download ZIP, or `git clone`) and open
   a terminal in its folder. Check `adb version` works; if `adb` isn't on your PATH, put
   `ADB=/path/to/adb` in front of the commands below.
2. **Turn on Developer Options on the Cube.** Settings → My Fire TV → About → select the device name
   7 times.
3. **Turn on ADB.** Settings → My Fire TV → Developer Options → **ADB Debugging** on.
4. **Find the Cube's IP address.** Settings → My Fire TV → About → Network. It's used as `<cube-ip>`
   below.
5. **Turn on HDMI Input Passthrough.** Settings → Display & Sounds → **HDMI Input Passthrough** on.
   The Cube then sends the console's own signal (its resolution and colour format) instead of
   rescaling it. The keeper only works in passthrough.
6. **Set Dynamic Range to Adaptive.** Settings → Display & Sounds → Display → **Dynamic Range
   Settings** → **Adaptive**. (These menus may ask for your PIN.) In passthrough this setting doesn't
   touch the console's picture; Adaptive keeps the Fire TV home screen in SDR.
7. **Approve the computer.** Run `bash scripts/hdr-status.sh <cube-ip>` once. The TV shows "Allow USB
   debugging?" for your computer: choose **Always allow from this computer**, then run it again. You
   should get one line describing what the Cube is sending.

On the TV, if it never switches to HDR, check that HDR is enabled for the HDMI port the Cube is on (on
Samsung: Input Signal Plus).

## Use

Switch the Cube to its HDMI input with the console on, then:

```bash
bash scripts/hdr-keeper.sh <cube-ip> start
```

The TV should switch to HDR. Play.

```bash
bash scripts/hdr-keeper.sh <cube-ip> status    # running or not, last lines of its log
bash scripts/hdr-keeper.sh <cube-ip> stop      # stop; Fire OS puts its own HDR state back
bash scripts/hdr-keeper.sh <cube-ip> remove    # stop and delete the keeper's files from the Cube
```

The keeper keeps running on the Cube if your computer sleeps or ADB disconnects. It only works while
the HDMI input is on screen and idles otherwise, so the home screen and apps are left alone. It stops
by itself after 4 hours; run `start` again to continue.

To watch what the Cube is sending, one line per change (Ctrl+C to stop):

```bash
bash scripts/hdr-status.sh <cube-ip> 1
```

With the keeper holding, the HDR field reads `HDR10-GAMMA_ST2084`; without it, `SDR`.

## What's still off

Flagging the picture gets close to HDR, not all the way. Measured against generic curves:

- **Contrast is steeper than the engine's own light.** Through the mid-tones, brightness changes
  about 1.5–2× faster than the scene does (up to 2.8× for an ACES-style curve). Deep shadows sit about
  1.5–2 stops darker than the HDR reference, and upper mid-tones about 2 stops brighter.
- **Banding.** The console sends 8-bit values. Read as HDR10, one step is about a 4% change in
  brightness, roughly twice the step in SDR, so smooth gradients (skies, fog) can band.
- **Colour.** The colour space the flag carries hasn't been read yet. If it says BT.2020 over a
  BT.709 game, colours come out oversaturated.
- **Sharpness.** Edges and texture can look crunchy. The leading cause is the same steep contrast
  showing at texture scale (every edge gets about twice the contrast); the TV upscaling a 720p signal
  to 4K may add to it.
- **Rare blips.** In the 12-minute test the Cube's driver logged four brief SDR events. None were seen
  on screen, but they haven't been ruled out.

## Tested

| Game | Platform | Result |
|---|---|---|
| Call of Duty: Black Ops II | PS3 | Shows in HDR, looks like HDR |
| Resident Evil 6 | PS3 | Shows in HDR, looks like HDR |
| Call of Duty: Black Ops III | PS4 version on PS5 | Shows in HDR, looks like HDR |

Chain: console → Fire TV Cube 3rd gen (Fire OS build PS7715.5585N, HDMI Input Passthrough on, Dynamic
Range Adaptive) → Samsung S95B. The PS3 arrived at the Cube as 720p60 RGB 12-bit. Fire OS updates can
change how the HDMI driver behaves; other builds are untested.

## Safety

- **What it writes.** While running, the keeper writes the word `hdr` to the Cube's HDMI output driver
  (`/sys/class/amhdmitx/amhdmitx0/config`). That's a live setting in the driver, not a file on
  storage; it doesn't survive a reboot. It also keeps three files in `/data/local/tmp`: the keeper
  script, its log, and a stop file. It doesn't root the Cube, flash anything or change any settings.
- **Cost.** One CPU core on the Cube while the HDMI input is on screen. Nothing while it idles.
- **Undo.** `bash scripts/hdr-keeper.sh <cube-ip> stop`, or just reboot the Cube (unplug it, or
  `adb reboot`). `remove` also deletes its files.
- **ADB.** ADB Debugging lets any computer you approved control the Cube over your network. Turn it
  off in Developer Options when you're not using the keeper.
- **Your TV.** The TV receives a standard HDR10 signal and decodes it as it would any HDR10 source.
  The brightest values ask for more than any TV can show, so the TV tone-maps them to its own peak.

## Roadmap

- **Per-game curves.** Measure each game's tone map, invert it back to scene light and re-encode to
  HDR10 properly. That fixes the steep contrast and the colour.
- **Native HDR from RE6.** A patch to Resident Evil 6's last render pass so the game itself outputs
  HDR10 values built from its internal HDR light.
- **Read the colour flag** the Cube sends, and fix it if it's wrong for these games.
- **More games**, with a table of engine, tone-map type and result.

## Related work

HDMI boxes (HDFury and similar) can inject HDR InfoFrames in hardware. RenoDX and Luma add HDR to PC
games by modding them. This project only sets the flag, on a Fire TV Cube, for console games, with no
change to the game.

## Tools

`tools/pq_read_closeness.py` (Python 3, no packages needed for the tables): for a tone-map curve, how
far each stop of scene light lands from the HDR reference when the game's output is read as HDR10.
Pass a measured curve with `--curve game.csv` (rows of `scene_x,code_v`). `--edge` compares texture
contrast on one frame patch and needs numpy and Pillow.

```bash
python tools/pq_read_closeness.py
```

## License

MIT, see [LICENSE](LICENSE).
<!-- draft license choice: confirm MIT before publishing -->
