# Part III · Music

> **GitHub public edition:** The original 0.4.6 learning manual is retained below. The three extracted character presets, optional shared library and historical case packages are not bundled in this public release. Built-in buildings and terrain are included; use your own character assets. [Public distribution details](../../DISTRIBUTION.md)

Import and select a track, audition it, adjust and apply settings, then set it as scene BGM. List selection is not activation: the ♪ mark identifies the active scene track.

## Collapsible visual groups

Click a bordered heading to expand or collapse it. Common groups start open (★); your choice is remembered per project. **Expand All / Collapse All** only affects this page. Tab to a heading and use Enter/Space, or Left/Right. Hiding controls keeps drafts and active tools/audition; it neither applies settings nor saves the scene. Shared Apply buttons stay outside the folds.

| Group | Contains |
| --- | --- |
| ★ [Music import & library](#group-music-import) | Import, track library and search; selection is not BGM activation. |
| [Scene BGM management](#group-music-bgm) | Set BGM, remove entry, or disable BGM while keeping the library. |
| ★ [Audition & waveform](#group-music-audition) | Waveform, play/pause/stop, seek and time; audition continues when collapsed. |
| [Name, category & source](#group-music-identity) | Track name, category and provenance; audio filenames are unchanged. |
| [Autoplay & looping](#group-music-playback) | Autoplay, loop and pause-with-stage toggles. |
| [Volume & fades](#group-music-volume) | Volume in dB, start fade-in and explicit-stop fade-out in seconds. |
| [Loop interval](#group-music-interval) | Loop start/end; first playback starts at zero, nonzero end requires PCM WAV. |

<a id="group-music-import"></a>

**Music import & library**

<a id="group-music-bgm"></a>

**Scene BGM management**

<a id="group-music-audition"></a>

**Audition & waveform**

<a id="group-music-identity"></a>

**Name, category & source**

<a id="group-music-playback"></a>

**Autoplay & looping**

<a id="group-music-volume"></a>

**Volume & fades**

<a id="group-music-interval"></a>

**Loop interval**

## Buttons and operations

| Visible button | What it does / when it applies |
| --- | --- |
| + Import Music (multiple) | Imports WAV/OGG Vorbis/MP3 into the scene library, copying external files; does not autoplay during editing. |
| Set as Scene BGM | Activates the selected track (♪). Apply settings first; activation does not mean unsaved drafts were committed. |
| Remove Entry | Removes the selected music-library entry with undo, without deleting the audio file. |
| Disable Scene BGM (keep library) | Disables scene BGM while retaining all tracks and settings. |
| ▶ Audition | Auditions the current panel draft from zero; does not commit settings or guarantee a seamless loop. |
| Pause/Resume | Pauses or resumes audition without changing scene autoplay settings. |
| ■ Stop | Stops audition using the fade-out duration; changing scenes or closing Preview stops immediately instead. |
| Apply Music Settings (undoable) | Validates and commits one undoable settings change. Invalid loop ranges are rejected without replacing the old configuration; save the scene afterward. |

## Every parameter

Most numeric fields are drafts until the relevant Apply button is clicked. Tool settings are read when you paint/place; imports and file-selection actions run immediately. Apply is not a disk save: use Ctrl+S / Cmd+S afterward. Check the action descriptions for exceptions.

Ranges show minimum … maximum; step. Options show the available choices. Units and conditions are explained in the final column. Sliders and their numeric boxes edit the same value, not two separate parameters.

| Parameter | Initial default | Range / step / options | Meaning and limits |
| --- | --- | --- | --- |
| <a id="control-music_autoplay"></a>Autoplay in game / preview<br>[Autoplay & looping](#group-music-playback) | On / 开 | — | Plays the active track when the scene or isolated preview starts; does not autoplay during editing. |
| <a id="control-music_loop"></a>Loop playback<br>[Autoplay & looping](#group-music-playback) | On / 开 | — | Returns to the loop start at the end; disabled plays once. Does not automatically repair musical seams. |
| <a id="control-music_pause_stage"></a>Pause with stage (off by default)<br>[Autoplay & looping](#group-music-playback) | Off / 关 | — | Pauses music with the stage; disabled by default, so pausing the background normally leaves music playing. |
| <a id="control-music_volume"></a>Volume (dB, 0 = original)<br>[Volume & fades](#group-music-volume) | -18 | -60 … 0; 0.01 | Playback gain in dB; 0 retains the original level and negative values attenuate it, without rewriting the audio file. |
| <a id="control-music_fade_in"></a>Fade in (s)<br>[Volume & fades](#group-music-volume) | 1.5 | 0 … 10; 0.1 | Seconds to fade from silence to the target level when starting; not crossfading between loop endpoints. |
| <a id="control-music_fade_out"></a>Audition fade out (s)<br>[Volume & fades](#group-music-volume) | 0.8 | 0 … 10; 0.1 | Fade-out duration when explicitly stopping audition; closing Preview or switching scenes stops immediately. |
| <a id="control-music_loop_start"></a>Loop start (s)<br>[Loop interval](#group-music-interval) | 0 | 0 … 7200; 0.01 | Initial playback still begins at zero; subsequent loops return to this time, which must precede the effective endpoint. |
| <a id="control-music_loop_end"></a>Loop end (0 = EOF)<br>[Loop interval](#group-music-interval) | 0 | 0 … 7200; 0.01 | Zero means end of file. Nonzero custom endpoints are supported only for PCM WAV; OGG/MP3 use the file end. |

## Other visible controls

| Control | Explanation |
| --- | --- |
| Music search and library | Filters names or categories. Selection prepares editing; ♪ identifies scene BGM. |
| Sampled waveform and seek bar | During audition, click the waveform or drag the seek bar to jump. The waveform is a sampled overview, not a sample-accurate editor. |
| Title / category | Apply after editing the display title/category; this does not rename the disk file. |
| Source and usage note | Free text saved with the scene for provenance and usage limits; does not grant usage rights. |
| Track information / playback status | Read-only path, format, duration, time and playback state; the editor does not autoplay. |

## Recommended sequence and pitfalls

There is one background player per scene, not one per loop segment. Apply, activate and save, then reopen to check. Audition a complete loop; prepare musical seams in an external audio editor. This page has no multitrack mixer, automatic beat matching, denoising, waveform trimming or ad insertion.

Use the shared toolbar reference for saving, stopping tools and previews. This workflow uses the dock, thumbnails, brush and native Inspector; you do not need to write GDScript to author the scene.
