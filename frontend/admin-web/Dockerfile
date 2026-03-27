FROM node:20-alpine AS build

WORKDIR /app
ARG VITE_API_BASE_URL=http://127.0.0.1:8888
ARG VITE_BASE_PATH=/
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_BASE_PATH=$VITE_BASE_PATH
COPY package.json tsconfig.json vite.config.ts index.html /app/
COPY src /app/src
RUN npm install && npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
