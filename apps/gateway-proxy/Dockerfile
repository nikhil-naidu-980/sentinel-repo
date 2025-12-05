FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY app.js ./

USER node

EXPOSE 8080

CMD ["node", "app.js"]
