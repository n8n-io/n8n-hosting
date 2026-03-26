FROM node:24-alpine

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod

COPY tsconfig.json ./
COPY src ./src

EXPOSE 5700 5701

VOLUME ["/data"]

CMD ["node_modules/.bin/tsx", "src/index.ts"]
