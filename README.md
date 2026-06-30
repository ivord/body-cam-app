# nvr_viewer

Flutter (Android + iOS) viewer for Dahua NVR / ONVIF IP cameras. Built for
factory-floor use: **local network only**, **bandwidth-frugal**, with **two-way
talk** (mic noise-suppressed + echo-cancelled). Vendor-neutral — ONVIF + RTSP,
no proprietary Dahua SDK.

## Features

| Need | How |
|------|-----|
| Live video | media_kit (libmpv), RTSP over TCP, H.265 hardware decode, low-latency tuning |
| Save bandwidth | Substream (`subtype=1`) by default; HD (main stream) only on tap |
| ONVIF | WS-Discovery on the LAN, profile/channel + stream-URI resolution (`easy_onvif`) |
| Multi-NVR | NVR Settings screen stores many NVRs (add/edit/delete); Home picks one from a dropdown, remembers the last used |
| NVR-defined channels | Channel list comes from the NVR (ONVIF); switch cameras in-live (◀/▶ + swipe); single-cam shows no switcher; per-NVR manual channel count is the ONVIF-off fallback |
| Two-way audio + ANC | OS `VOICE_COMMUNICATION` mic + `AcousticEchoCanceler` + `NoiseSuppressor` → G.711 → RTP over ONVIF Profile-T backchannel |
| Local network | WS-Discovery + manual-IP; shows the phone's own LAN IP; credentials in encrypted secure storage; zero cloud calls |
| No video stored | Live only — no recording/snapshot/disk cache (`cache=no`); only NVR info (encrypted creds) + a tiny last-viewed marker persist |

## Screens

Mock-ups reflect the actual widgets — not aspirational art.

**Home** — pick an NVR, start live — [home_screen.dart](lib/features/home/home_screen.dart)

```text
┌──────────── NVR Viewer ───────[⚙]──┐  ⚙ → NVR Settings
│ This phone : 192.168.1.55           │  own LAN IP
│ ─────────────────────────────────── │
│ NVR  [ Factory NVR            ▼ ]   │  dropdown of stored NVRs
│                                     │
│ Host / IP : 192.168.1.10            │  selected NVR info (read-only)
│ Username  : admin                   │
│ Password  : ••••••••          [👁]   │  eye toggles reveal
│                                     │
│          [  ▶  Start live  ]        │
└─────────────────────────────────────┘
   No NVR yet → "Add NVR" button → settings.
```

**NVR Settings** — manage stored NVRs — [nvr_settings_screen.dart](lib/features/settings/nvr_settings_screen.dart)

```text
┌──────────── NVR Settings ───────────┐
│ 🖳  Factory NVR              [🗑]    │  tap row → edit
│     192.168.1.10                    │
│ 🖳  Line-2 Cam               [🗑]    │
│     192.168.1.21                    │
│                      ┌────────────┐  │
│                      │ +  Add NVR │  │  FAB → Edit NVR (blank)
│                      └────────────┘  │
└─────────────────────────────────────┘
```

**Edit NVR** — add / edit one NVR — [nvr_edit_screen.dart](lib/features/settings/nvr_edit_screen.dart)

```text
┌──────────────── Edit NVR ──────────────┐
│ Name (optional) [ Factory NVR        ] │
│ Host / IP       [ 192.168.1.10 ][Scan] │  Scan = ONVIF autofill IP
│ Username        [ admin              ] │
│ Password        [ ••••••••           ] │
│ ONVIF port      [ 80                 ] │
│ Channels (opt)  [ 4   ] fallback if    │  used only when ONVIF off
│                         ONVIF off      │
│                 [        Save        ] │
└────────────────────────────────────────┘
```

**Live view** — in-live camera switch — [live_screen.dart](lib/features/live/live_screen.dart)

```text
┌── Factory NVR · Channel 1 ─[◀][▶][SD]┐  ◀/▶ = prev/next camera (multi-cam)
│ ┌────────────────────────────────┐ │     SD/HD toggles substream↔main
│ │                                │ │
│ │        live video 16:9         │ │  RTSP/TCP, H.265 HW decode
│ │     ← swipe to switch cam →     │ │
│ └────────────────────────────────┘ │
│            ╭──────────╮             │  idle:  [ 📞 Talk ]
│            │ 📞 Talk  │             │  in call → [ 🎙 Mute ] [ ☎ End ]
│            ╰──────────╯             │  full-duplex; AEC/NS on mic
└─────────────────────────────────────┘
   Talk opens the backchannel; Mute holds the call, End closes it.
   Single-camera NVR → no ◀/▶ arrows.
```

## Project layout

```text
lib/
  main.dart                              bootstrap media_kit + Riverpod
  app.dart                               MaterialApp → HomeScreen
  core/config.dart                       defaults: substream, TCP, timeouts
  features/
    devices/device.dart                  Device + CameraChannel (+ manualChannels)
    devices/device_repository.dart       secure-storage persistence + last-viewed (Riverpod)
    home/home_screen.dart                phone IP, NVR dropdown, info, Start live
    settings/nvr_settings_screen.dart    stored NVRs list: add / edit / delete
    settings/nvr_edit_screen.dart        NVR form: host, creds, ports, channels + Scan
    live/live_screen.dart                player, in-live ◀/▶ + swipe, SD/HD, wakelock, talk
    talk/talk_controls.dart              push-to-talk UI + mic permission
  services/
    onvif_service.dart                   discovery, profiles, stream URIs (+ onvifServiceProvider)
    rtsp_url_builder.dart                Dahua RTSP URL builder
    backchannel/backchannel_channel.dart Dart side of the native talk module
android/.../Backchannel.kt               native talk: mic+AEC/NS → G.711 → RTP → RTSP
ios/Runner/Backchannel.swift             iOS talk (stub — see Status)
```

## Run

```bash
flutter pub get        # fetch dependencies (first time)
```

Both platforms must be on the **same LAN as the NVR**.

### Android

```bash
flutter devices                 # list connected targets
flutter run -d android          # USB debugging on; debug build
flutter build apk               # release APK → build/app/outputs/flutter-apk/
```

### iOS

```bash
cd ios && pod install && cd ..  # media_kit uses CocoaPods, not SPM
open ios/Runner.xcworkspace     # once: select a Signing Team
flutter run -d ios              # real device — needed for ONVIF + mic
```

iOS ONVIF discovery needs Apple's **Multicast Networking entitlement**; the
manual-IP add (Scan not required) works without it.

**First run**: Home → **⚙ NVR Settings** → **Add NVR** → fill host/creds (**Scan**
autofills the IP) → Save. Back on Home, pick the NVR from the dropdown → **Start
live**. The dropdown remembers the last NVR used. In live, **◀/▶** or swipe
switch cameras (multi-cam NVR), **SD/HD** toggles quality, **Talk** opens a
full-duplex conversation (**Mute** holds it, **End** closes it); back exits live
and stops the stream.

## RTSP URL

Dahua pattern the app falls back to when ONVIF `GetStreamUri` is unavailable:

```text
rtsp://user:pass@host:554/cam/realmonitor?channel=N&subtype=S
# subtype 0 = main stream (HD), 1 = substream (low bitrate, default)
```

## Permissions

- **Android**: `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE`,
  `CHANGE_WIFI_MULTICAST_STATE` (WS-Discovery), `MODIFY_AUDIO_SETTINGS`;
  cleartext traffic enabled (LAN RTSP/HTTP is plaintext).
- **iOS**: microphone + local-network usage descriptions, ATS local networking.
  WS-Discovery multicast needs Apple's **Multicast Networking entitlement**;
  manual-IP add works without it.

## Status

- **Done**: multi-NVR store (add/edit/delete), Home dropdown + phone IP, ONVIF
  discovery + NVR-defined channels with manual fallback, in-live camera switch,
  live video, SD/HD, bandwidth substream, push-to-talk UI, Android backchannel
  (mic + AEC/NS + G.711 + RTP).
- **Verify on-device**: the Android backchannel's RTSP digest auth + SDP
  `a=sendonly` parse are firmware-sensitive. If the NVR advertises no
  backchannel track, talk reports `UNSUPPORTED`.
- **Not yet built**: iOS talk (stub — video/discovery work), PTZ, auto-reconnect,
  multi-view grid.

## Test

```bash
flutter analyze
flutter test           # rtsp_url_builder + last-viewed parser units
```
