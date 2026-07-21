# Exercise 03: image diet (multi-stage Node build)

## The situation

`apps/node-app` has a real build step: TypeScript goes in, `dist/` comes out,
and production should not ship `typescript` or `esbuild`. Build a **multi-stage**
image that stays small and still serves `/health` on port **8212**.

## What you will learn

- Why multi-stage builds exist
- Installing production dependencies only in the final stage
- Keeping a size ceiling without breaking the app

## Before you start

```bash
cd apps/node-app
npm install
npm run build
npm start
# curl http://127.0.0.1:8212/health
# stop the native process before using port 8212 in Docker
```

## Steps

### 1. Write `apps/node-app/Dockerfile`

Suggested shape:

1. **Build stage** (`node:24-alpine` or the series from `config/images.env`)
   - copy package files, `npm ci` or `npm install`
   - copy source, `npm run build`
2. **Runtime stage** (same base family, alpine)
   - `LABEL cloudsprocket.lab=docker`
   - copy only `package.json` / lockfile and run `npm ci --omit=dev` (or equivalent)
   - copy `dist/` from the build stage
   - `USER` may stay root for this exercise; non-root is exercise 06
   - `ENV PORT=8212`
   - `EXPOSE 8212`
   - `CMD ["node", "dist/server.js"]`

### 2. Build and run

```bash
docker build -t dpl-node-app:ex03 apps/node-app

docker run -d \
  --name dpl-ex03-app \
  --label cloudsprocket.lab=docker \
  --network dpl-net \
  -p 127.0.0.1:8212:8212 \
  dpl-node-app:ex03
```

### 3. Check

```bash
curl -sS http://127.0.0.1:8212/health
./lab check 03
```

## Check your work

- image `dpl-node-app:ex03` labelled and under the size ceiling (see check output)
- container `dpl-ex03-app` running, loopback **8212**, `/health` OK

The size ceiling is generous enough for a correct alpine multi-stage build, and
tight enough that a single-stage image full of devDependencies should fail.

## Clean up (optional)

```bash
docker container rm --force dpl-ex03-app
```
