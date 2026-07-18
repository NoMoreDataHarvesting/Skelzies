# Landscape Lock — the one Xcode step the code can't do for you

## Why the last patch didn't lock orientation

The code was correct, but iPad has a rule that overrides it: **if an app
supports iPad multitasking (Split View / Slide Over), iOS requires it to
support all orientations and silently ignores the app's orientation mask.**
An app opts out of multitasking by declaring "Requires Full Screen"
(`UIRequiresFullScreen = YES`). Your project came from the Game template with
its own Info.plist, and that flag was never set — so the delegate lock I
shipped was being ignored by the system.

The new `SkelziesApp.swift` adds a second enforcement layer (it actively
rotates any portrait scene to landscape at launch and every time the app
returns to the foreground), but the clean, App-Review-proof fix still needs
one checkbox in Xcode.

## Do this (60 seconds) — Option A: the General tab

1. Click the blue **Skelzies** project icon → **Skelzies iOS** target →
   **General** tab.
2. Under **Deployment Info**:
   - **iPad Orientation:** check ONLY **Landscape Left** and
     **Landscape Right**. Uncheck Portrait and Upside Down.
   - Check ✅ **Requires full screen**. ← This is the critical one.
3. Clean Build Folder (⇧⌘K), then run.

## Or Option B: paste into Info.plist directly

Right-click **Info.plist** → Open As → Source Code, and make sure these three
entries exist (replace any existing orientation arrays):

```xml
<key>UIRequiresFullScreen</key>
<true/>
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

Note: "Requires full screen" also means Skelzies won't run in Split View —
which is exactly what you want for a full-board physics game, and Apple
accepts it without question for games.

## Verify before you call it done

- [ ] Hold the iPad **vertically**, cold-launch Skelzies → it comes up in
      landscape anyway
- [ ] Rotate the iPad through all four orientations mid-game → the board
      never budges
- [ ] Background the app, rotate the iPad to portrait, reopen Skelzies →
      still landscape
- [ ] Win a game → tap **Go Home** → lands on the setup screen, no crash
      (fixed in this patch: the overlay no longer reads the roster live, and
      backToSetup no longer empties it mid-frame)

## Files in this patch

| File | Change |
|---|---|
| `GameViewModel.swift` | `backToSetup()` no longer clears `players` mid-frame (crash root cause) |
| `ContentView.swift` | Win overlay takes the winner's name as a plain value + guarded call site (crash can't recur, in any future mode) |
| `SkelziesApp.swift` | Two-layer landscape enforcement: delegate mask + active rotation on launch/foreground |

Paste-replace the three files, flip the checkbox, ⇧⌘K, run the four checks.
