# Keep Pixel UE5 plugin 0.2.0 (source)

Copy this directory to `<Project>/Plugins/KeepPixelPlugin`, regenerate project files,
compile Development Editor, enable the plugin and restart UE.

Blueprint GameInstance Init: `Initialize From Launcher` -> check Success/Error.
Available async nodes: `Get User Profile`, `Get Friends List`, `Check License`,
`Set Presence`, `Set Overlay Visible`. Connect every Completed callback and handle
Success=false. Shared user IDs are UUID strings (`GlobalID`), not integers.

Launch the packaged game from the Keep Pixel 1.3 Windows library. The launcher
passes KEEPPIXEL_SDK_URL, KEEPPIXEL_SDK_TOKEN and KEEPPIXEL_GAME_ID through the
process environment. No account JWT, login or email enters the game. Never log
or upload the SDK capability. The old PHP/REQUEST_TOKEN API has been removed.

Shift+Tab is handled by the launcher, so no game input binding is required.
Use windowed or borderless fullscreen. Exclusive fullscreen/injected overlays,
match invites, achievements, cloud saves and server auth tickets are not provided.
For UE packaged bootstrappers, configure the actual game executable in the build
manifest so the launcher tracks the process for the full session.

UHT/UBT compilation and packaged-game runtime have not been verified in the Linux
SDK development environment. Build and verify with your installed UE5 before
shipping. Full contract, engine adapters and status: sdk/README.md in Keep-Pixel.
