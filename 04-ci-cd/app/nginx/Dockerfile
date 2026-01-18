ARG NGINX_VERSION=1.27-alpine

FROM nginx:${NGINX_VERSION}
RUN mkdir -p /etc/nginx/certs
COPY front-end/build /usr/share/nginx/html
CMD ["nginx","-g","daemon off;"]
