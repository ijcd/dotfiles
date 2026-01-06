# Archive

Historical configuration files preserved for posterity.

## mit-1995-Xresources

X Window System resource file from my undergraduate days at MIT, circa 1995.

This file configured the look and feel of X11 applications on Project Athena
workstations. It predates the modern web and most of today's developers.

### What's in it

| Application | Description |
|-------------|-------------|
| **Dash** | Athena dashboard with logout button labeled "IHTFP!!!!" |
| **zwgc** | Zephyr WindowGram Client - MIT's instant messaging system |
| **xzewd** | Zephyr client with "All Alone..." displayed when no one's online |
| **xterm** | Terminal emulator (lightgrey background, green cursor) |
| **emacs** | GNU Emacs with antiquewhite background |
| **xmh** | X interface to the MH mail system |
| **matlab** | MATLAB on Athena workstations |
| **ez** | Andrew Toolkit editor (from CMU) |
| **xscreensaver** | Screen saver with zaway integration |
| **xclock/dclock** | Clock widgets (gold on dim gray) |

### Historical context

- **Project Athena** (1983-1991) was MIT's campus-wide distributed computing
  environment. It pioneered many concepts we take for granted today: network
  authentication (Kerberos), distributed filesystems (AFS), and the X Window
  System itself.

- **Zephyr** was MIT's real-time messaging system, predating AOL Instant
  Messenger by years. The `zaway` command set your away message when your
  screen locked.

- **IHTFP** is a famous MIT acronym with multiple interpretations, most
  commonly "I Hate This F***ing Place" (said with affection) or "I Have
  Truly Found Paradise."

- The `#ifdef COLOR` preprocessor guards supported both color and monochrome
  X terminals - not everyone had color displays in 1995.

### Why keep this

Some files transcend utility. This is 30 years of computing history in 200
lines. The applications are gone, the workstations are recycled, but the
config remains - a time capsule from when "the cloud" meant the weather.
