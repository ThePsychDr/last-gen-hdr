# Reproduce it yourself

This walks through the whole thing from nothing: get the hardware together, set up the Cube, check
the baseline, start the keeper, and check that the HDR10 flag is really there. Each step says what you
should see. If something doesn't match, [troubleshooting](troubleshooting.md) goes through each
message the scripts print.

Results here keep the README's labels: **measured** (read off the Cube), **by eye** (seen on the
tested TV), **computed** (from `tools/pq_read_closeness.py`). Please label yours the same way when you
[report them](https://github.com/ThePsychDr/last-gen-hdr/issues/new/choose).

## 1. What you need

| Part | What was tested | Notes |
|---|---|---|
| Fire TV Cube, 3rd gen (2022), model AFTGAZL | Fire OS build PS7715.5585N | The only Fire TV with an HDMI input. Other builds untested. |
| HDR10 TV | Samsung S95B | Any TV that takes HDR10 on the port the Cube is on should do; others untested. |
| Console | PS3; PS5 running a PS4 game | Any HDMI source goes through the same path; only these were tested. |
| A game | Black Ops II, Resident Evil 6 (PS3); Black Ops III (PS4 version) | For a fair test, use a game with no HDR mode of its own. |
| Computer on the same network as the Cube | Windows (Git Bash), macOS, Linux | Needs `adb` from [Android platform-tools](https://developer.android.com/tools/releases/platform-tools) and a bash shell. |
| Two HDMI cables | | Console → Cube's HDMI input; Cube's HDMI output → TV. |
| Python 3 (optional) | | Only for re-running the computed numbers. |

On Windows, run everything from **Git Bash**, not PowerShell or cmd.

## 2. Wire it up

```
console ──HDMI──▶ Cube HDMI IN      Cube HDMI OUT ──HDMI──▶ TV
```

Plug the TV end into a port that takes HDR. On a Samsung that means turning on **Input Signal Plus**
for that port; other brands have their own name for it. (General HDR advice, not something tested
with this setup.)

## 3. Set up the Cube (once)

1. **Developer Options:** Settings → My Fire TV → About → select the device name 7 times.
2. **ADB:** Settings → My Fire TV → Developer Options → **ADB Debugging** on.
3. **IP address:** Settings → My Fire TV → About → Network. Write it down; it's `<cube-ip>` below.
4. **Passthrough:** Settings → Display & Sounds → **HDMI Input Passthrough** on. The keeper only
   works in passthrough.
5. **Dynamic Range:** Settings → Display & Sounds → Display → **Dynamic Range Settings** →
   **Adaptive**. (These menus may ask for your PIN.)
6. **Software version:** note it from Settings → My Fire TV → About. You'll want it for a results
   report, and builds other than PS7715.5585N haven't been tested.

## 4. Set up the computer (once)

1. Get the repo: `git clone https://github.com/ThePsychDr/last-gen-hdr`, or the green **Code**
   button → **Download ZIP** and unzip it. Open a terminal in the folder.
2. Check `adb version` prints a version. If `adb` isn't on your PATH, put `ADB=/path/to/adb` in front
   of every command below, for example:

   ```bash
   ADB=/c/platform-tools/adb.exe bash scripts/hdr-status.sh <cube-ip>
   ```

3. Approve the computer on the Cube:

   ```bash
   bash scripts/hdr-status.sh <cube-ip>
   ```

   The TV shows **"Allow USB debugging?"**. Choose **Always allow from this computer**, then run the
   same command again. You should get one line describing what the Cube is sending. The fields are
   explained at the top of `scripts/hdr-status.sh`; the one this guide is about is the **second**
   field, the HDR state (`SDR` or `HDR10-GAMMA_ST2084`).

## 5. Baseline: check it's SDR first

This is the "before" half of the comparison, so don't skip it.

1. Turn the console on, start the game, and switch the Cube to its **HDMI input** so the game is on
   screen.
2. Run:

   ```bash
   bash scripts/hdr-status.sh <cube-ip>
   ```

   **What you should see:** `ready=1`, and the second field reads `SDR`. The `attr` field shows the
   colour format and bit depth the console is sending (the PS3 arrived as 720p60 RGB 12-bit,
   measured). The `passthrough=` field should end in `/on` while the HDMI input is on screen.

   If the HDR field already reads `HDR10-GAMMA_ST2084` before the keeper is running, the console is
   sending HDR itself (for example a PS4 Pro or PS5 with a game that has its own HDR mode). That's
   not what this project tests: pick a game without HDR, or turn the console's HDR off.

3. Note what the TV says about the signal. Most HDR TVs show an HDR badge when they switch, and many
   list the format in their input or signal info. It should be SDR now.

## 6. Start the keeper

With the HDMI input on screen:

```bash
bash scripts/hdr-keeper.sh <cube-ip> start
```

**What you should see:** `started`. Within a moment the TV switches to HDR (by eye on the tested
TV: it does, for all three tested games).

If it prints `the HDMI input isn't on screen in passthrough`, switch the Cube to the HDMI input and
run `start` again. The keeper is only started on the input on purpose.

## 7. Verify the HDR10 flag

There are three places to check, and they tell you different things.

**a. The keeper's own status** (measured, on the Cube):

```bash
bash scripts/hdr-keeper.sh <cube-ip> status
```

What you should see while it's holding the flag:

```
running (pid …)
HDMI input on screen: yes
output: HDR10-GAMMA_ST2084
```

followed by the last lines of its log, ending in `HDMI IN on screen: holding HDR10`.

**b. The output over time** (measured, on the Cube). Watch it for a few minutes; it prints a line
only when something changes (Ctrl+C to stop):

```bash
bash scripts/hdr-status.sh <cube-ip> 1
```

The HDR field should read `HDR10-GAMMA_ST2084`. Fire OS puts SDR back about once a frame (measured)
and the keeper re-writes the flag straight after, so a read can occasionally land in the gap and show
`SDR` for one line. That's expected: in the 12-minute test with a PS3 game, 97.6% of status reads were
HDR10 (lowest one-second window 95%, longest SDR gap about 30 ms; measured). What matters is the next
check.

**c. The TV** (by eye). The TV should be in its HDR mode and stay there, with no blinking back to SDR.
On the tested S95B over the same 12-minute run: no blink. Write down what your TV says the signal is
(where it shows that varies by brand).

What these checks don't cover: all of the above reads the Cube's HDMI driver and watches the TV. Nobody
has yet read the InfoFrame on the cable itself with an HDMI analyser, and the colour space the flag
carries hasn't been read either. If you have the gear for either, that's one of the most useful
reports you could send.

## 8. A/B it

Stop the keeper and the TV should drop back to SDR; start it again (on the HDMI input) and it should
come back to HDR:

```bash
bash scripts/hdr-keeper.sh <cube-ip> stop
```

```bash
bash scripts/hdr-keeper.sh <cube-ip> start
```

Same scene, both ways, is the clearest way to see what the flag changes. Keep the TV's own SDR-to-HDR
features (on Samsung, HDR+ Mode) off for this, or you're comparing against the TV's guess rather than
plain SDR.

## 9. What you should expect it to look like

By eye on the tested TV: it looks like HDR. Highlights get real headroom and mid-tones land near where
HDR content puts them (computed: mid-grey at 30–43 nits for typical tone-map curves, against the
26-nit HDR reference).

It isn't mastered HDR. Expect (see [What's still off](../README.md#whats-still-off)):

- contrast steeper than the game's own light, and darker deep shadows (computed);
- possible banding in smooth gradients like skies and fog (computed);
- edges and texture that can look crunchy (by eye, on RE6);
- colour not yet checked (not yet measured).

## 10. Keeping it running

- **Start it again** whenever the Cube sleeps or leaves the HDMI input (home screen or an app; it can
  do that on its own). It doesn't survive either. Switch back to the HDMI input, then `start`.
- It **stops by itself after 4 hours**.
- It **keeps running** if your computer sleeps or ADB disconnects.
- When you're done: `stop`, or `remove` to also delete its files from the Cube. A reboot of the Cube
  undoes everything it wrote to the HDMI driver.
- Turn **ADB Debugging** off when you're not using it. See [Safety](../README.md#safety).

## 11. Optional: re-run the computed numbers

```bash
python3 tools/pq_read_closeness.py
```

(`python` on Windows.) It prints, for each generic tone-map curve, where each stop of scene light lands
when read as PQ. The `+0` row is mid-grey: 30.1 nits for Hable filmic, 42.7 for Reinhard and 35.9 for
the ACES fit, against a 26-nit reference. Those are the numbers in the README table. If you've
measured a game's own curve, pass it with `--curve game.csv` (rows of `scene_x,code_v`).

## 12. Send your results

[Open a results report](https://github.com/ThePsychDr/last-gen-hdr/issues/new/choose). The form asks
for display, game and console, and for the output of `status` and `hdr-status.sh`, which is what
makes a report comparable with the tested setup. A "didn't work" report is as useful as a "worked"
one.
