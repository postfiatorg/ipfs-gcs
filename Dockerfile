FROM node:22-alpine
RUN apk update && apk add python3 make g++ git

WORKDIR /usr/app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000 4002 4003 5002 9090

CMD ["npm", "start"]