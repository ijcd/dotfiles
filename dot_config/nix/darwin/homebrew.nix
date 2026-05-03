{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;            # skip `brew update` on rebuild; run manually
      upgrade = false;               # skip `brew upgrade` on rebuild; run manually
      cleanup = "uninstall";         # one of "none", "uninstall", "zap"
    };

    # caskArgs.no_quarantine removed in newer Homebrew
    global.brewfile = true;

    # homebrew is best for GUI apps
    # nixpkgs is best for CLI tools

    taps = [
      "nikitabobko/tap" # for aerospace
    ];

    brews = [
      # ─────────────────────────────────────────────────────────────────────────
      # Docker (better via brew on macOS for socket/VM integration)
      # ─────────────────────────────────────────────────────────────────────────
      "docker"
      "colima"

      # ─────────────────────────────────────────────────────────────────────────
      # macOS-specific tools
      # ─────────────────────────────────────────────────────────────────────────
      "mas"              # Mac App Store CLI

      # ─────────────────────────────────────────────────────────────────────────
      # Tools not in nixpkgs (or brew version preferred)
      # ─────────────────────────────────────────────────────────────────────────
      "git-subrepo"      # subtree/subrepo workflows
      "gdrive"           # Google Drive CLI; used for business ops + exports
      "ibazel"           # Bazel file watcher
      "aws-sso-cli"      # AWS SSO helper
      "aws-sso-util"     # AWS SSO utilities
      "mise"             # version manager (nix broken on x86_64-darwin, nixpkgs#427748)
      "raine/workmux/workmux" # tmux workspace manager (nix flake needs rust 1.88+)
    ];

    casks = [
      ### OS ENHANCEMENTS
      "onyx" # system maintenance and cleanup utility
      # "bettertouchtool"        # deep customization of trackpad/mouse/keyboard gestures
      # "macforge"               # plugin-based system UI modification framework

      ### DESKTOP ENHANCEMENTS / AUTOMATION
      { name = "alfred"; greedy = true; } # powerful launcher & workflow automation (Spotlight replacement)
      "hammerspoon" # Lua-based macOS automation / window management
      "hazel" # automatic file organization rules for folders
      "hiddenbar" # hide/organize menu bar icons
      "rectangle" # window snapping/tiling manager
      "xquartz" # X11 server (for legacy Unix GUI apps requiring X11)
      "aerospace"              # tiling window manager / Spaces replacement for macOS
      # "amitv87-pip"            # always-on-top picture-in-picture video player
      # "betterdisplay"          # advanced display/scaling control, virtual monitors
      # "cleanshot"              # best-in-class screenshot and screen recording tool
      # "mos"                    # smooth/adjustable scrolling behavior

      # "raycast"                # fast launcher with plugins and automation

      ### BROWSERS
      { name = "firefox"; greedy = true; } # Mozilla browser, good dev tooling and privacy features
      # "brave-browser"          # privacy-focused Chromium browser with ad/tracker blocking
      # "thebrowsercompany-dia"  # Experimental dev-focused browser from The Browser Company (Arc)
      # "zen"                    # privacy-oriented Firefox fork with opinionated defaults

      ### CLOUD STORAGE & BACKUP
      "backblaze" # continuous, offsite cloud backup
      "google-drive" # Google Drive desktop sync client

      ### EDITORS
      "android-studio" # full Android app development IDE
      { name = "cursor"; greedy = true; } # AI-augmented code editor (VS Code derivative)
      { name = "visual-studio-code"; greedy = true; } # general-purpose code editor / lightweight IDE
      { name = "zed"; greedy = true; } # modern multiplayer code editor
      # "zed@preview"            # preview/insider build of Zed editor

      ### DEV TOOLS
      "charles" # HTTP/S proxy, traffic viewer and debugger
      { name = "claude-code"; greedy = true; } # Claude-based CLI / code assistant
      "dash" # offline API/documentation browser
      { name = "ghostty"; greedy = true; } # fast GPU-accelerated terminal emulator
      { name = "kitty"; greedy = true; } # GPU-accelerated terminal emulator
      "livebook" # Elixir Livebook notebooks for data/ML/prototyping
      "ngrok" # secure public tunnels to local dev servers
      { name = "orbstack"; greedy = true; } # fast Docker & Linux VM runtime
      "pgadmin4" # PostgreSQL admin GUI
      "sourcetree" # GUI Git client
      "virtualbox" # virtualization hypervisor for running VMs
      "wireshark-app" # network protocol analyzer / packet sniffer

      ### SDKs
      "basictex" # minimal TeX distribution (subset of MacTeX)
      "flutter" # Flutter SDK / tooling via cask
      "oracle-jdk" # Oracle Java Development Kit distribution
      "intellij-idea" # JetBrains Java/Kotlin/polyglot IDE

      ### MESSAGING & COLLAB
      { name = "discord"; greedy = true; } # community chat/voice/video (dev servers, communities)
      "loom" # async screen & camera recording and sharing
      { name = "slack"; greedy = true; } # team and work chat with channels
      { name = "signal"; greedy = true; } # end-to-end encrypted messaging
      { name = "whatsapp"; greedy = true; } # mainstream messaging app (desktop client)
      "messenger" # Facebook Messenger desktop app
      "keybase" # encrypted chat, file sharing, and crypto identity

      ### REMOTE ACCESS
      "teamviewer" # remote desktop/support tool

      ### PRODUCTIVITY, PKM & ORGANIZATION
      { name = "1password"; greedy = true; } # password manager and secure vault
      "anki" # spaced repetition (SRS) flashcard learning
      { name = "obsidian"; greedy = true; } # markdown-based personal knowledge management
      "omnifocus" # GTD-style task/project manager

      ### MEDIA, CREATIVE & CONTENT
      "affinity" # all-in-one vector/raster/web-publishing tool like Illustrator/Photoshop/InDesign
      "audacity" # audio editor and recorder
      "blender" # 3D modeling, animation, rendering suite
      "gimp" # raster graphics editor (Photoshop-like)
      "inkscape" # vector graphics editor (Illustrator-like)
      "reaper" # professional digital audio workstation (DAW)
      "sketchup" # 3D modeling for architecture/interiors

      ### STREAMING
      "plex-media-server" # media server for local movies/TV/music libraries
      { name = "spotify"; greedy = true; } # music streaming client
      "qbittorrent" # BitTorrent client (full-featured, open source)

      ### SECURITY / NETWORKING / PRIVACY
      "protonvpn" # secure VPN client for Proton VPN
    ];
  };
}
