# node-app

A small Node.js service with a **real build step**. You install dependencies,
compile TypeScript into `dist/`, then run the compiled file. That shape is the
point of the later multi-stage "image diet" exercise: development tools stay out
of the final image, while the runtime still works.

Run it on your machine first so you know what green looks like before Docker
enters the picture.

## What you learn from this app

| Piece | Why it is here |
|---|---|
| TypeScript source in `src/` | Needs a build; multi-stage Dockerfiles have something to compile. |
| `devDependencies` (`typescript`, `esbuild`, `@types/node`) | Tools you need to build, not to run. The diet exercise strips these. |
| Runtime dependency `nanoid` | Must still work in production; proves the runtime layer is not empty. |
| `npm run build` then `npm start` | Matches how many real Node services ship. |

## Requirements

- Node.js 20 or later (Node 24 matches the lab's shared base image series)
- npm (ships with Node)

## Run it

From this directory:

```bash
npm install
npm run build
npm start
```

On Windows PowerShell the same commands work.

Default port is **8212**. Override with:

```bash
PORT=8212 npm start
```

```powershell
$env:PORT = "8212"
npm start
```

For a quick edit loop without writing `dist/` first:

```bash
npm run dev
```

## Prove it works

```bash
curl http://127.0.0.1:8212/health
curl "http://127.0.0.1:8212/greet?name=Ada"
curl -X POST http://127.0.0.1:8212/echo \
  -H "Content-Type: application/json" \
  -d "{\"message\":\"works on my machine\"}"
```

PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8212/health
Invoke-RestMethod "http://127.0.0.1:8212/greet?name=Ada"
Invoke-RestMethod http://127.0.0.1:8212/echo -Method Post `
  -ContentType "application/json" `
  -Body '{"message":"works on my machine"}'
```

You should see `"status": "ok"`, a greeting with a `request_id`, and your JSON
echoed back.

## Files

| Path | Purpose |
|---|---|
| `src/server.ts` | Application source |
| `dist/` | Build output (created by `npm run build`, gitignored) |
| `package.json` | Scripts, runtime deps and devDependencies |
| `tsconfig.json` | Typecheck settings |

## What comes next in the lab

A later exercise asks you to write a multi-stage Dockerfile: build with the
full toolchain, ship only `dist/` plus production `node_modules`, and pass a
size ceiling while `/health` still answers.

Get the native `build` + `start` path green before that.
