FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

ARG GIT_SHA=unknown
ENV GIT_SHA=$GIT_SHA

USER node

EXPOSE 3000

CMD ["node", "server.js"]
