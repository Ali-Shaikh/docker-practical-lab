# Sample applications

Three small apps that run **on your machine first**. Later exercises turn them
into images, attach volumes, shrink build context, and put them behind Compose.
The pedagogical order is intentional: you learn what "works" looks like before
Docker becomes part of the story.

| App | Port (default) | Why it is in the lab |
|---|---|---|
| [python-api](python-api/) | 8211 | Stdlib HTTP API with `/health`, `/ready` and a writable data directory |
| [node-app](node-app/) | 8212 | TypeScript service with a real build step and production vs dev dependencies |
| [static-site](static-site/) | 8080 when served natively | Plain HTML/CSS; later served by nginx |

Each directory has a README with exact run and verify steps. If those steps do
not pass natively, stop and fix that before any Dockerfile work.

## Quick native checks

```bash
# python-api
cd apps/python-api && python app.py
# other terminal: curl http://127.0.0.1:8211/health

# node-app
cd apps/node-app && npm install && npm run build && npm start
# other terminal: curl http://127.0.0.1:8212/health

# static-site
cd apps/static-site && python -m http.server 8080 --bind 127.0.0.1
# browser: http://127.0.0.1:8080/
```

On Windows PowerShell use the same commands; the per-app READMEs show
PowerShell-friendly verify snippets.
