# FAQ

The obvious skeptical questions, answered from what's in this repo. Labels as in the README:
**measured** (read off the Cube), **by eye** (seen on the tested TV), **computed** (from
`tools/pq_read_closeness.py`), **predicted** (expected, not yet checked).

### Isn't this just SDR with the brightness turned up?

No picture processing happens anywhere. The console's values reach the TV unchanged; only the flag
that tells the TV how to read them changes. Read on the PQ curve, mid-tones land close to the HDR
reference while highlights spread out toward the TV's peak. For typical tone-map curves, mid-grey
lands at 30–43 nits against the 26-nit reference (ITU-R BT.2408) (computed). A plain brightness boost
would lift everything together; this mostly lifts the top.

### Why would an SDR game's values mean anything as HDR?

Games from the PS3 and PS4 era light their scenes in HDR inside the engine, then tone-map down to SDR
at the end of the frame. The bright parts are packed into the top of the signal, not thrown away.
PQ, the HDR10 curve, spends far more of its range on brightness than SDR gamma does, so read on PQ
those packed-in values open back out, with every tone still in order. The longer version is in the
[README](../README.md#why-it-works) and at [thepsychdr.com/hdr](https://thepsychdr.com/hdr/).

### So it's real HDR?

It's not mastered HDR, and the repo says so. Contrast is steeper than the engine's own light, about
1.5–2× through the mid-tones, up to 2.8× for an ACES-style curve (computed). 8-bit steps can band
(computed). The colour space in the flag hasn't been read (not yet measured). By eye on the tested TV
it looks like HDR. See [What's still off](../README.md#whats-still-off).

### Isn't this what my TV's "SDR to HDR" mode already does?

That feature (HDR+ Mode on Samsung, and similar on other brands) has the TV guess how to expand an SDR
picture. Here the TV does no guessing: it reads the game's values on the standard HDR10 curve, as it
would any HDR10 source. Whether one looks better than the other on your TV is a fair thing to
compare; keep the TV's own mode off when you test this so you're comparing against plain SDR.

### How do I know the TV is really getting HDR10, not just the Cube saying so?

Two things have been checked, and one hasn't:

- The Cube's HDMI driver reports `HDR10-GAMMA_ST2084` while the keeper holds (measured, on the Cube).
- The TV switches to its HDR mode and stays there (by eye, on the S95B, all three tested games).
- Nobody has read the InfoFrame on the cable with an HDMI analyser yet. The four 1.5-second
  off/on events the driver logged in the 12-minute test were measured on the Cube, not on the wire;
  none were seen on screen.

If you have an analyser (HDFury or similar), a reading from it would settle the last point.

### Does it flicker?

The first version did. It re-sent the flag every 50 ms, held HDR10 in about 7% of status reads
(measured) and blinked (by eye). Fire OS puts SDR back about once a frame (measured), so the current
keeper re-sends it back to back. Over 12 minutes with a PS3 game: HDR10 in 97.6% of status reads,
lowest one-second window 95%, longest SDR gap about 30 ms (measured); no blink (by eye).

### 9,000 writes a second? Is that safe for the Cube?

It writes the word `hdr` to a live setting in the HDMI driver, not to storage, so the writes themselves
don't touch flash. It costs one CPU core while it holds (measured). Heat and wear over long
sessions haven't been measured. It stops by itself after 4 hours, and a reboot undoes it. See
[Safety](../README.md#safety).

### Can it hurt my TV?

The TV gets a standard HDR10 signal and decodes it like any other HDR10 source. The brightest values
ask for more than any TV can show, so the TV tone-maps them to its own peak, as it does with films.

### Does it need root, or change the game or the console?

No root, no flashing, no game patch, no console change. It runs as the normal ADB shell user and
writes to the HDMI driver and three files in `/data/local/tmp` (the keeper, its log, a stop file).

### Does it work with an Xbox, a Switch, a PC, a PS4 directly?

Untested. The keeper doesn't know what's on the HDMI input; it flags whatever is passing through. So
any source should get the flag, but whether the picture looks right depends on how that game
tone-maps. Tested so far: a PS3, and a PS5 running a PS4 game. Please send a
[results report](https://github.com/ThePsychDr/last-gen-hdr/issues/new/choose) for anything else.

### Does it work with other TVs?

Only the Samsung S95B has been tested. Any TV that accepts HDR10 on that HDMI port should switch, but
that's predicted, not checked. Reports wanted.

### Does it work on other Fire TV devices, or other Fire OS versions?

Only the Fire TV Cube 3rd gen (AFTGAZL) on build PS7715.5585N. Most other Fire TV devices have no HDMI
input at all. A Fire OS update could change how the HDMI driver behaves.

### Does it add input lag?

Not measured. The Cube is in HDMI Input Passthrough, so it isn't rescaling the console's picture, but
nobody has timed the chain yet.

### Why does it sometimes stop?

It doesn't survive the Cube sleeping or leaving the HDMI input (by eye and in its status, in use; the
cause hasn't been measured), and it stops after 4 hours on purpose. Switch back to the HDMI input and
run `start` again.

### Why not just use an HDFury?

You can. HDMI boxes like HDFury can inject HDR InfoFrames in hardware. This does the same flagging
with a Fire TV Cube you may already have, for nothing.

### Can I see it in a photo or video?

Not really. A phone photo or an SDR video can't show HDR, so pictures of the screen won't prove much
either way. The checks in [reproduce it yourself](reproduce.md#7-verify-the-hdr10-flag) are what
count; photos are still welcome in reports for showing banding or crunchy edges.

### What's next?

Per-game curves (measure each game's tone map and re-encode it to HDR10 properly), native HDR output
from RE6, reading the colour flag, and more games. See the [roadmap](../README.md#roadmap).
