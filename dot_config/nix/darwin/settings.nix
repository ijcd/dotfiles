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
    };
  };
}
