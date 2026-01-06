# Archive

Historical configuration files preserved for posterity.

These are dotfiles built up over a few decades of Unix use, starting with zsh
in 1995. What began as scattered `.rc` files became an elaborate module system,
then zgen + oh-my-zsh + prezto, and has now evolved into chezmoi + nix-darwin +
Home Manager + Zim.

The configs here have been retired but are worth keeping for reference,
nostalgia, or the occasional resurrection.

---

## The Original Dotfiles System (2010s)

The previous incarnation used a custom module system with zgen:

```
~/.dotfiles/
├── modules/           # Topic-based organization
│   ├── git/          # gitconfig, aliases, scripts
│   ├── ruby/         # irbrc, pryrc, gemrc
│   ├── zsh/          # zshrc.symlink, prompts
│   └── ...
├── local/            # Less organized recent additions
└── dotfiles          # Installation script
```

Each module could have:
- `*.symlink` files → symlinked to `~/.filename`
- `bin/` → added to PATH
- `functions/` → added to fpath
- `*.zsh` → sourced at startup

This worked well but required manual symlink management. Chezmoi handles this
better, and nix-darwin + Home Manager provide declarative system configuration.

### Tools from that era (retired)

| Tool | Replaced by |
|------|-------------|
| zgen | Zim (faster, simpler) |
| prezto modules | Zim modules |
| oh-my-zsh modules | Zim modules + custom |
| custom module loader | chezmoi |
| manual symlinks | chezmoi |
| Brewfile | nix-darwin |

### Inspiration (still good)

- [yadr](https://github.com/skwp/dotfiles)
- [rtomayko](https://github.com/rtomayko/dotfiles)
- [mathiasbynens](https://github.com/mathiasbynens/dotfiles)
- [sorin-ionescu](https://github.com/sorin-ionescu/dotfiles)

---

## MIT 1995 - Xresources

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

---

## Email Infrastructure (2000s)

Server-side email processing from the era of self-hosted mail.

### Files

| File | Description |
|------|-------------|
| `pinerc-2000s` | Alpine/Pine email client configuration |
| `procmailrc-2000s` | Procmail filtering rules |
| `procmail-2000s/` | Supporting filter includes |

### What it did

This was infrastructure for running your own email:

- **Pine/Alpine**: Terminal-based email client from University of Washington.
  The spiritual ancestor of many email conventions we still use today.

- **Procmail**: Server-side mail filtering that ran on every incoming message.
  Rules would sort mail into folders, forward copies, and filter spam.

- **CRM114**: The "Controllable Regex Mutilator" - a statistical spam filter
  that was cutting-edge in its day. It learned from your mail to distinguish
  spam from ham using Bayesian classification.

### The setup

```
Incoming mail → Procmail → CRM114 spam check → Sort to folders
                    ↓
              Forward copy to Gmail (backup)
```

Mail was sorted by:
- Whitelist (trusted senders)
- Killfile (blocked senders)
- Mailing lists (auto-sorted by List-Id header)
- Spam score (CRM114 classification)

### Historical context

This predates Gmail's dominance. Running your own mail server meant:
- Full control over your email
- Learning procmail's arcane recipe syntax
- Battling spam with tools like SpamAssassin, CRM114, and bogofilter
- Actually reading RFCs to debug delivery issues

Today, even email enthusiasts typically use Fastmail or Gmail rather than
self-hosting. The spam problem alone makes it impractical for individuals.

---

## Ruby Development (2010s)

A comprehensive Ruby/Rails development environment from the peak Rails era.

### Files

| File/Directory | Description |
|----------------|-------------|
| `ruby-2010s/irbrc` | IRB config with Pry fallback, helpers, Rails integration |
| `ruby-2010s/pryrc` | Pry debugger aliases |
| `ruby-2010s/pry/` | Elaborate Pry config with Solarized colors |
| `ruby-2010s/gemrc` | Gem install options (skip docs) |
| `ruby-2010s/railsrc` | Rails console helpers (SQL toggling) |
| `ruby-2010s/rdebugrc` | ruby-debug settings |
| `ruby-2010s/bin/` | ctags-ruby, zeus helpers, gem finders |
| `ruby-2010s/functions/` | Shell helpers for gems, bundler, cucumber |

### What it did

This was a full Ruby development workflow:

- **RVM/rbenv**: Ruby version managers (now use mise/asdf)
- **Zeus**: Rails preloader for fast test runs (dead, was replaced by Spring)
- **Pry**: Enhanced REPL that replaced IRB for many (still used)
- **Wirble**: IRB colorizer (obsolete, IRB has colors now)
- **TextMate**: The editor of choice (`gemmate` opened gems in it)

### The workflow

```
rvm use 2.1.0           # Switch Ruby version
bundle install          # Install gems
zeus start              # Preload Rails in background
zeus rspec spec/        # Fast test runs
binding.pry             # Drop into debugger
```

### Historical context

This was peak Ruby/Rails (2008-2015):
- Rails was "the" web framework
- GitHub, Twitter, Shopify all ran on Rails
- "Convention over configuration" was revolutionary
- DHH was posting inflammatory blog posts
- RailsConf was the conference to attend

The ecosystem has matured significantly. Modern Ruby (3.1+) has:
- Built-in IRB improvements (colors, autocomplete)
- Built-in `debug` gem replacing pry-byebug
- Bundler built into Ruby
- No need for complex preloaders

A minimal `~/.irbrc` for history is all that's needed now.

---

## Zsh Tips (Still Useful)

Some things from the old setup that remain useful:

- **zmv**: `zmv '(*).txt' '$1.md'` - powerful bulk rename
- **fzf**: ctrl-r for history, ctrl-t for files
- **zsh plugins**: https://github.com/unixorn/awesome-zsh-plugins
- **zsh tricks**: http://reasoniamhere.com/2014/01/11/outrageously-useful-tips-to-master-your-z-shell/
