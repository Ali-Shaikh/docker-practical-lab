FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:24-alpine
LABEL cloudsprocket.lab=docker
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8212
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
EXPOSE 8212
CMD ["node", "dist/server.js"]
