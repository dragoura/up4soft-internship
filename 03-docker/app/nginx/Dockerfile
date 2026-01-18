ARG NGINX_VERSION=1.27-alpine
ARG NODE_VERSION=22.9.0-alpine

FROM node:${NODE_VERSION} AS builder
WORKDIR /app
COPY front-end/package*.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm ci --ignore-scripts --no-audit --no-fund --progress=false
COPY front-end/ ./
RUN npm run build

FROM nginx:${NGINX_VERSION}
RUN mkdir -p /etc/nginx/certs
COPY --from=builder /app/build /usr/share/nginx/html
CMD ["nginx","-g","daemon off;"]
