# static-site

Plain HTML and CSS. No framework, no build step. The pedagogical point is
simple: static files are just files until something serves them. You view this
site with a one-line local server now; a later exercise serves the same folder
with nginx inside a container.

Useful content lives in `index.html` on purpose. Learners should not practise
on lorem ipsum when a short, accurate explanation of image versus container is
one file away.

## What you learn from this app

- Static content has no runtime of its own.
- A web server (Python's `http.server`, nginx, Caddy) is a separate concern.
- Docker will package *both* the files and a server process; natively you only
  need the files plus any server you already have.

## Requirements

- A browser
- Either Python 3, or any other static file server you prefer

## Run it

From this directory:

```bash
python -m http.server 8080 --bind 127.0.0.1
```

PowerShell:

```powershell
python -m http.server 8080 --bind 127.0.0.1
```

Open [http://127.0.0.1:8080/](http://127.0.0.1:8080/) and read the three short
sections on the page.

You can also open `index.html` directly in a browser. A local server is closer
to how the nginx exercise will behave (proper paths, no `file://` quirks).

## Prove it works

```bash
curl -sS http://127.0.0.1:8080/ | head
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/styles.css
```

PowerShell:

```powershell
(Invoke-WebRequest http://127.0.0.1:8080/).StatusCode
(Invoke-WebRequest http://127.0.0.1:8080/styles.css).StatusCode
```

You want HTTP 200 for both the page and the stylesheet, and HTML that mentions
"Image versus container".

## Files

| Path | Purpose |
|---|---|
| `index.html` | Learner-facing content |
| `styles.css` | Layout and typography |

## What comes next in the lab

A later exercise (and the capstone track) serves this directory with nginx on a
lab port bound to loopback. The HTML should not need edits for that to work.
