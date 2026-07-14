# Named Homebrew cask groups. Machines compose the groups they want:
#   - darwin/homebrew.nix pulls the universal base (every host, incl. fallbacks)
#   - hosts/<host>/configuration.nix pulls extra groups for that machine
# Keeps "which apps on which machine" declarative and per-group instead of one
# flat list. Entries may be plain strings or { name; greedy; } attrsets.
{
  # ── Universal: every machine, including generic fallback hosts ──────────────
  base = [
    "onyx" # system maintenance / cleanup
    { name = "1password"; greedy = true; } # password manager
    "lastpass" # password manager (legacy, still in use)
    "jumpcut" # clipboard history (was in legacy/Brewfile, dropped in nix migration)
  ];

  terminals = [
    { name = "ghostty"; greedy = true; } # GPU terminal
    { name = "kitty"; greedy = true; } # GPU terminal
  ];

  editors = [
    { name = "cursor"; greedy = true; } # AI editor (VS Code derivative)
    { name = "visual-studio-code"; greedy = true; }
    { name = "zed"; greedy = true; } # multiplayer editor
  ];

  ai = [
    { name = "claude"; greedy = true; } # desktop app
    { name = "claude-code"; greedy = true; } # CLI / code assistant
  ];

  dev = [
    "charles" # HTTP/S proxy / debugger
    "dash" # offline API docs
    "ngrok" # tunnels to local dev servers
    { name = "orbstack"; greedy = true; } # Docker & Linux VM runtime
    "pgadmin4" # Postgres admin GUI
    "sourcetree" # Git GUI
    "livebook" # Elixir notebooks
  ];

  windowMgmt = [
    { name = "alfred"; greedy = true; } # launcher / automation
    "hammerspoon" # Lua automation / window mgmt
    "rectangle" # window snapping
    "hiddenbar" # menu-bar hiding
    "aerospace" # tiling window manager
  ];

  workComms = [
    { name = "slack"; greedy = true; } # team chat
    "loom" # async screen recording
  ];

  browsers = [
    { name = "firefox"; greedy = true; }
  ];

  notes = [
    { name = "obsidian"; greedy = true; } # PKM
    "omnifocus" # GTD task manager
  ];

  # ── Home / personal: bearcat only ──────────────────────────────────────────
  creative = [
    "affinity" # vector/raster/publishing suite
    "audacity" # audio editor
    "blender" # 3D suite
    "gimp" # raster editor
    "inkscape" # vector editor
    "reaper" # DAW
    "sketchup" # 3D modeling
  ];

  media = [
    "plex-media-server" # local media server
    { name = "spotify"; greedy = true; }
    "qbittorrent" # BitTorrent client
  ];

  personalComms = [
    { name = "discord"; greedy = true; }
    { name = "signal"; greedy = true; }
    { name = "whatsapp"; greedy = true; }
    "messenger"
    "keybase"
  ];

  personalInfra = [
    "backblaze" # offsite backup
    "protonvpn" # personal VPN
    "tailscale-app" # WireGuard mesh VPN / tailnet peer (bearcat = remote-access host; renamed from "tailscale" 2026). Move to `base` for a universal tailnet.
    "teamviewer" # remote desktop
  ];

  personalMisc = [
    "anki" # flashcards
    "hazel" # file automation
    "xquartz" # X11 server
  ];

  # Dev extras kept off the work laptop (policy / size), opted into by bearcat.
  homeDevExtra = [
    "wireshark-app" # packet analyzer (often flagged on managed work machines)
    "basictex" # minimal TeX distribution
  ];

  # ── Heavy / on-demand: multi-GB, situational. NOT pulled by the work laptop
  # or the generic fallbacks; bearcat opts in below. Pull into another host by
  # importing this group there. Several are also problematic on locked-down work
  # machines (virtualbox needs a kernel ext; oracle-jdk has licensing strings —
  # prefer Temurin).
  heavySdks = [
    "android-studio"
    "intellij-idea"
    "oracle-jdk"
    "flutter"
    "virtualbox"
  ];
}
