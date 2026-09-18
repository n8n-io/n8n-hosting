FROM node:24-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY tsconfig.json ./
COPY src ./src

EXPOSE 5701

VOLUME ["/data"]

CMD ["node_modules/.bin/tsx", "src/index.ts"]
