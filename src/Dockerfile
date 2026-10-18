FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

ARG GIT_SHA=unknown
ENV GIT_SHA=$GIT_SHA

EXPOSE 3000

CMD ["node", "server.js"]