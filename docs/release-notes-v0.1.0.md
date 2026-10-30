# last-gen-hdr v0.1.0

PS3- and PS4-era games in HDR on an HDR TV, through a Fire TV Cube (3rd gen). No game patch, no
root, no extra box.

The console goes into the Cube's HDMI input with HDMI Input Passthrough on. `hdr-keeper.sh` starts a
small script on the Cube over ADB that keeps the output flagged as HDR10, so the TV reads the game's
own picture as HDR. These games light their scenes in HDR internally and tone-map down to SDR, so
their output already maps to HDR: for typical tone-map curves, mid-grey lands at 30–43 nits against
the 26-nit HDR reference (computed).

**Use:** switch the Cube to its HDMI input first, then run `hdr-keeper.sh <cube-ip> start`. The keeper
doesn't survive the Cube sleeping or leaving the HDMI input, so start it again after either.
`hdr-keeper.sh <cube-ip> status` shows whether it's running, whether the input is on screen, and
whether the output reads `HDR10-GAMMA_ST2084`.

**Tested:** Black Ops II and Resident Evil 6 on PS3, Black Ops III (PS4 version) on PS5; Fire TV
Cube 3rd gen on Fire OS PS7715.5585N; Samsung S95B; all three by eye. Measured on the Cube with a PS3
game: HDR10 in 97.6% of status reads over 12 minutes; by eye over the same run, no blink.

**In this release**
- `scripts/hdr-keeper.sh <cube-ip> start|stop|status|remove`
- `scripts/hdr-status.sh <cube-ip> [interval]` (read-only)
- `tools/pq_read_closeness.py`

**Known limits:** contrast runs steeper than the engine's own light and 8-bit steps can band in smooth
gradients (both computed), the colour space in the flag hasn't been read yet, and edges can look
over-sharp (by eye). Per-game
curves and native HDR output from RE6 are on the roadmap.

**Undo:** `hdr-keeper.sh <cube-ip> stop`, or reboot the Cube. Nothing it writes to the HDMI driver
survives a reboot.

Setup and details: [README](../README.md).
