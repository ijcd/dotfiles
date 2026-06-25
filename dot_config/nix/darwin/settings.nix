{ self, ... }:
{
  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # system defaults and preferences
  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      # Dock
      dock = {
        autohide = true;
        tilesize = 110;
        mru-spaces = false;  # Don't rearrange spaces by recent use
      };

      # Screenshots
      screencapture = {
        show-thumbnail = true;  # floating thumbnail in the corner (drag/annotate before it saves)
      };

      # Finder
      finder = {
        AppleShowAllFiles = true;          # hidden files
        AppleShowAllExtensions = true;     # file extensions
        _FXShowPosixPathInTitle = true;    # title bar full path
        ShowPathbar = true;                # breadcrumb nav at bottom
        ShowStatusBar = true;              # file count & disk space
        FXPreferredViewStyle = "Nlsv";     # list view
      };

      # Trackpad
      trackpad = {
        Clicking = true;  # tap to click
      };

      # Keyboard & Global
      NSGlobalDomain = {
        # Keyboard repeat
        KeyRepeat = 2;
        InitialKeyRepeat = 25;

        # Scrolling
        "com.apple.swipescrolldirection" = false;  # traditional scrolling

        # Disable auto-corrections
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
      };

      # Raw-key defaults not covered by the typed options above.
      CustomUserPreferences = {
        # Terminal.app: default to Apple's "Pro" dark profile. "Basic" in Dark
        # Mode renders dim/grey text near-invisibly (the starship prompt); "Pro"
        # is a purpose-built dark palette with readable contrast. Set as both the
        # default and startup profile so every new window uses it.
        "com.apple.Terminal" = {
          "Default Window Settings" = "Pro";
          "Startup Window Settings" = "Pro";
        };

        # Disable macOS's built-in drag-to-screen-edge tiling so it stops
        # fighting Rectangle over the same gesture (the "Conflict with macOS
        # tiling" dialog). Rectangle is a superset of this behavior.
        NSGlobalDomain = {
          EnableTilingByEdgeDrag = false;
          EnableTopTilingByEdgeDrag = false;
        };
      };
    };
  };
}
