{
  pkgs,
  primaryUser,
  ...
}:
{
  networking.hostName = "bearcat";

  # host-specific homebrew casks
  homebrew.casks = [
    ### OS ENHANCEMENTS
    "onyx" # system maintenance and cleanup utility
    # "bettertouchtool"        # deep customization of trackpad/mouse/keyboard gestures
    # "macforge"               # plugin-based system UI modification framework

    ### DESKTOP ENHANCEMENTS / AUTOMATION
    "alfred" # powerful launcher & workflow automation (Spotlight replacement)
    "hammerspoon" # Lua-based macOS automation / window management
    "hazel" # automatic file organization rules for folders
    "hiddenbar" # hide/organize menu bar icons
    "rectangle" # window snapping/tiling manager
    "xquartz" # X11 server (for legacy Unix GUI apps requiring X11)
    # "aerospace"              # tiling window manager / Spaces replacement for macOS
    # "amitv87-pip"            # always-on-top picture-in-picture video player
    # "betterdisplay"          # advanced display/scaling control, virtual monitors
    # "cleanshot"              # best-in-class screenshot and screen recording tool
    # "mos"                    # smooth/adjustable scrolling behavior

    # "raycast"                # fast launcher with plugins and automation

    ### BROWSERS
    "firefox" # Mozilla browser, good dev tooling and privacy features
    # "brave-browser"          # privacy-focused Chromium browser with ad/tracker blocking
    # "thebrowsercompany-dia""thebrowsercompany-dia"   # Experimental dev-focused browser from The Browser Company (Arc), a sandbox for new UI/engine ideas
    # "zen"                    # privacy-oriented Firefox fork with opinionated defaults

    ### CLOUD STORAGE & BACKUP
    "backblaze" # continuous, offsite cloud backup
    "google-drive" # Google Drive desktop sync client

    ### EDITORS
    "android-studio" # full Android app development IDE
    "cursor" # AI-augmented code editor (VS Code derivative)
    "visual-studio-code" # general-purpose code editor / lightweight IDE
    "zed" # modern multiplayer code editor
    # "zed@preview"            # preview/insider build of Zed editor

    ### DEV TOOLS
    "charles" # HTTP/S proxy, traffic viewer and debugger
    "claude-code" # Claude-based CLI / code assistant (terminal integration)
    "dash" # offline API/documentation browser
    "ghostty" # fast GPU-accelerated terminal emulator
    "livebook" # Elixir Livebook notebooks for data/ML/prototyping
    "ngrok" # secure public tunnels to local dev servers
    "pgadmin4" # PostgreSQL admin GUI
    "sourcetree" # GUI Git client
    "virtualbox" # virtualization hypervisor for running VMs
    "wireshark-app" # network protocol analyzer / packet sniffer

    ### SDKs
    "flutter" # Flutter SDK / tooling via cask
    "oracle-jdk" # Oracle Java Development Kit distribution
    "intellij-idea" # JetBrains Java/Kotlin/polyglot IDE

    ### MESSAGING & COLLAB
    "discord" # community chat/voice/video (dev servers, communities)
    "loom" # async screen & camera recording and sharing
    "slack" # team and work chat with channels
    "signal" # end-to-end encrypted messaging
    "whatsapp" # mainstream messaging app (desktop client)
    "messenger" # Facebook Messenger desktop app
    "keybase" # encrypted chat, file sharing, and crypto identity

    ### REMOTE ACCESS
    "teamviewer" # remote desktop/support tool

    ### PRODUCTIVITY, PKM & ORGANIZATION
    "1password" # password manager and secure vault
    "anki" # spaced repetition (SRS) flashcard learning
    "obsidian" # markdown-based personal knowledge management
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
    "spotify" # music streaming client
    "qbittorrent" # BitTorrent client (full-featured, open source)

    ### SECURITY / NETWORKING / PRIVACY
    "protonvpn" # secure VPN client for Proton VPN
  ];

  homebrew.brews = [
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
    "mise"             # version manager (nix version broken on x86_64-darwin, nixpkgs#427748)
    "git-subrepo"      # subtree/subrepo workflows
    "gdrive"           # Google Drive CLI; used for business ops + exports
    "ibazel"           # Bazel file watcher
    "aws-sso-cli"      # AWS SSO helper
    "aws-sso-util"     # AWS SSO utilities
  ];

  # Install apps from AppStore (https://discourse.nixos.org/t/nix-darwin-homebrew-masapps-is-hanging/60828)
  # homebrew.masApps = {
  #   "3Hub" = 427515976;
  #   "AdBlock" = 1402042596;
  #   "Be Focused" = 973134470;
  #   "Clocker" = 1056643111;
  #   "Compressor" = 424390742;
  #   "DW Spectrum" = 794454285;
  #   "Final Cut Pro" = 424389933;
  #   "GarageBand" = 408980954;
  #   "GarageBand" = 682658836;
  #   "Growl" = 467939042;
  #   "iMazing HEIC Converter" = 1292198261;
  #   "iMovie" = 408981434;
  #   "iMovie" = 408981434;
  #   "iMovie" = 408981434;
  #   "iPhoto" = 408981381;
  #   "Keynote" = 409183694;
  #   "Keynote" = 409183694;
  #   "Logic Pro X" = 634148309;
  #   "MainStage 3" = 634159523;
  #   "Markoff" = 1084713122;
  #   "Microsoft Excel" = 462058435;
  #   "Microsoft OneNote" = 784801555;
  #   "Microsoft Outlook" = 985367838;
  #   "Microsoft PowerPoint" = 462062816;
  #   "Microsoft Word" = 462054704;
  #   "Motion" = 434290957;
  #   "Numbers" = 409203825;
  #   "OneDrive" = 823766827;
  #   "Pages" = 409201541;
  #   "RB App Checker Lite" = 519421117;
  #   "Should I Sleep" = 560851219;
  #   "Slack" = 803453959;
  #   "Tomato One" = 907364780;
  #   "Trello" = 1278508951;
  #   "Ulysses" = 1225570693;
  #   "Xcode" = 497799835;
  # }

  homebrew.taps = [
    "nikitabobko/tap" # for aerospace
  ];

  # host-specific home-manager configuration
  home-manager.users.${primaryUser} = {
    home.packages = with pkgs; [
      graphite-cli
    ];

    programs = {
      zsh = {
        initContent = ''
          # Source shell functions
          source ${./shell-functions.sh}
        '';
      };
    };
  };
}
