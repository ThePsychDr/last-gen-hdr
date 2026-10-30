# Changelog

## v0.1.0 (2026-10-30)

First release.

- `scripts/hdr-keeper.sh`: start, stop, status and remove for the HDR keeper on a Fire TV Cube
  (3rd gen). Holds the HDR10 flag on the Cube's output while its HDMI input is on screen in
  passthrough. `start` refuses unless the HDMI input is on screen; `status` shows whether it's
  running, whether the input is on screen, and the output's HDR state.
- `scripts/hdr-status.sh`: read-only, one line of what the Cube is sending over HDMI; with an
  interval, a line per change.
- `tools/pq_read_closeness.py`: how close a game's tone-mapped output lands to the HDR reference
  when read as HDR10.
- Works from Git Bash on Windows, macOS and Linux with stock platform-tools.
