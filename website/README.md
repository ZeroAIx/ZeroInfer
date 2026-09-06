# ZeroInfer website

Static landing page. No framework, no build step - just open `index.html` in a browser.

## Structure

```
website/
├── index.html         # single-page landing
├── styles.css         # design tokens + sections
├── script.js          # download links, OS detection, scroll effects
├── install.sh         # macOS/Linux installer  (curl -fsSL .../install.sh | sh)
├── install.ps1        # Windows installer      (irm .../install.ps1 | iex)
├── assets/
│   └── favicon.svg    # ZeroInfer constellation mark
└── README.md          # this file
```

## Two ways to install

The page offers both, because they suit different people: a **download button**
for anyone who just wants an app, and a **one-liner** for people who live in a
terminal. Both end up installing the exact same desktop build.

### Download button

Every download link in the markup points at the releases page:

```
https://github.com/ZeroAIx/ZeroInfer/releases/latest
```

On load, `script.js` calls the GitHub releases API and rewrites those links to
the exact asset for the visitor's OS (`.exe` on Windows, `.AppImage` on Linux).
If the API call fails, is rate-limited, or JS is off, the links stay on the
releases page - so they are always correct, never broken.

**macOS is deliberately left on the releases page.** The browser cannot
distinguish Apple Silicon from Intel, and guessing wrong would hand the user a
build that won't run; the release page shows both.

### Install scripts

`install.sh` and `install.ps1` are served as static files from the site root:

```
# Windows
irm https://zeroinfer.vercel.app/install.ps1 | iex
# macOS / Linux
curl -fsSL https://zeroinfer.vercel.app/install.sh | sh
```

Both resolve the latest release from the GitHub API, pick the asset matching the
host OS/arch, and install it:

| Platform | What the script does |
| --- | --- |
| Windows | downloads the `.exe` and runs it silently (`/S`, per-user, no admin), then launches the app |
| macOS | downloads the `.zip`, unpacks `ZeroInfer.app` into `/Applications` |
| Linux | downloads the `.AppImage` into `~/.local/bin` and adds a `.desktop` entry |

Each script checks for **Python 3.10+** and warns if it's missing, but installs
anyway - the app has a proper first-run screen for that case.

> On macOS the script is actually the *smoother* path: a file fetched with `curl`
> carries no `com.apple.quarantine` attribute, so Gatekeeper doesn't block the
> unsigned app the way it does when you download the `.dmg` in a browser.

> The scripts and the page hard-code `https://zeroinfer.vercel.app`. If you deploy
> to a different domain, find-and-replace that host in `index.html` (hero command
> + the `#install` one-liners) and `script.js` (the Windows override). Serving
> over **HTTPS** is required for `| iex` / `| sh`.

## Local preview

```bash
# any static server works
cd website
python -m http.server 8080
# or: npx serve
```

Open `http://localhost:8080`.
