# Cerkak Player (`cerkak_player`)

Omarchy shell plugin to play sound-only YouTube playlists of Javanese short stories (*Cerita Cekak Basa Jawa*) read by **Slamet Prasojo (default)**.

## Features

- **Audio-Only Playback:** High quality opus audio stream powered by `mpv` and `yt-dlp` via PipeWire / PulseAudio.
- **Default Playlist:** Includes pre-bundled snapshot of 230 stories read by Slamet Prasojo (`https://youtube.com/playlist?list=PLR0xzKWWUQU4TbQRIWq8sSxM_MdtlbrVO`).
- **Custom Playlist Support:** Option to input and load any custom YouTube playlist URL or ID directly in the panel UI or CLI.
- **Playback Controls:**
  - **Prev (`⏮`):** Plays previous track (or rewinds to start if > 3s).
  - **Play / Pause (`⏯`):** Toggles playback with instant responsiveness.
  - **Next (`⏭`):** Plays next track.
  - **Stop (`⏹`):** Halts playback and resets state.
  - **Shuffle (`🔀`):** Shuffles playback order without repeating until all tracks have played.
- **Interactive Panel:**
  - **Compact Design:** The large playback controls card is hidden by default to keep the panel compact and focused on story browsing.
  - **Toggleable Player Card (`Pemutar`):** Header button and keyboard shortcut `m` toggle the full playback controls (progress bar with click-to-seek, volume slider, shuffle, prev/next, and stop buttons).
  - **Header Status:** Displays active story title when playing (*"Memutar: [Judul]"*) or reader information, plus interactive play/pause status pill.
  - **Search filter:** Filter stories quickly (*"Golek cerkak..."*) among hundreds of tracks.
  - **Story list:** Numbered track list with titles, durations, active track highlighting, and click-to-play.
- **Bar Widget:**
  - Displays icon and current story title when playing.
  - **Left-click:** Toggle popout player panel.
  - **Middle-click:** Toggle Play / Pause.
  - **Right-click:** Skip to next story.
  - **Mouse wheel:** Adjust volume up/down.
- **Keyboard Shortcuts (in Panel):**
  - `Space`: Play / Pause
  - `n`: Next track
  - `p`: Previous track
  - `s`: Toggle shuffle
  - `m`: Toggle Now Playing card (show/hide full player controls)
  - `x`: Stop playback
  - `[` / `]`: Seek -10s / +10s
  - `Esc`: Close panel

## CLI Tool (`cerkak-player`)

The plugin includes a standalone Python CLI tool `cerkak-player`:

```bash
# Playback
cerkak-player play [index]      # Play current or specific track index (0-based) 
cerkak-player pause             # Pause playback
cerkak-player play-pause        # Toggle play/pause
cerkak-player next              # Skip to next track
cerkak-player prev              # Previous track
cerkak-player stop              # Stop playback
cerkak-player shuffle [on|off]  # Toggle or set shuffle mode
cerkak-player volume <0-100>    # Set volume
cerkak-player seek <seconds>    # Seek to position in seconds

# Status and Playlist
cerkak-player status            # Print JSON playback status
cerkak-player list              # Print JSON list of all playlist items
cerkak-player playlist <url>    # Set and load a custom YouTube playlist
cerkak-player reset-playlist    # Reset to default Slamet Prasojo playlist
cerkak-player refresh           # Re-fetch current playlist from YouTube
```

## Omarchy Shell IPC

You can control the plugin via `omarchy-shell`:

```bash
omarchy-shell cerkak_player open
omarchy-shell cerkak_player close
omarchy-shell cerkak_player toggle
omarchy-shell cerkak_player play
omarchy-shell cerkak_player pause
omarchy-shell cerkak_player next
omarchy-shell cerkak_player prev
omarchy-shell cerkak_player stop
omarchy-shell cerkak_player shuffle
omarchy-shell cerkak_player status
```

## Installation & Enablement

Requirements: `mpv` and a current `yt-dlp`. YouTube regularly changes its
stream formats, and a yt-dlp older than roughly three months starts returning
HTTP 403. The player prefers `~/.local/bin/yt-dlp` over the system package, so
the latest release can be installed without touching pacman:

```bash
mkdir -p ~/.local/bin
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o ~/.local/bin/yt-dlp
chmod +x ~/.local/bin/yt-dlp
```

```bash
# Plugin is installed at ~/.config/omarchy/plugins/cerkak_player
omarchy plugin validate ~/.config/omarchy/plugins/cerkak_player
omarchy plugin enable cerkak_player --section right
```

Playback progress is only reported once mpv has actually loaded the stream;
a refused stream shows an error in the panel and bar tooltip instead of a
false "playing" state.

## Playlist Recommendation
- https://youtube.com/playlist?list=PLKwjOjRtM0fSnn8yUlyyShLsEtzIOeynK&si=t2QSS4U5neNYuV3q by Radio Siaran Jawi
- https://youtube.com/playlist?list=PLUhUkBSc0s09TKK5w7sgBPbtRodMV-6pf&si=WXgfnYSAt4GFWu8u by Paniradya Kaistimewan
- https://youtube.com/playlist?list=PL76PFevWUC-4vxjM1Vm83q7-yEdHczgfq&si=ABVCclIC68AY1P3h by Subadi Prawoto
