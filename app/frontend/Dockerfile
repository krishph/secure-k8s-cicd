FROM nginxinc/nginx-unprivileged:1.28-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html app.js style.css /usr/share/nginx/html/
USER 101:101
EXPOSE 8080
# Bypass upstream entrypoint scripts: all configuration is supplied at build time.
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
