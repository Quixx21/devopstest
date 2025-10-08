# 1 stage build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
# 2 stage runtime
FROM node:20-alpine AS runtime
RUN addgroup -S appgroup && adduser -S appuser -G appgroup #no root
WORKDIR /src
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/dist ./dist
RUN npm ci --omit=dev && npm cache clean --force
EXPOSE 3000
USER appuser
CMD ["node", "dist/main.js"]
