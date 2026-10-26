FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter create --org com.deliveric --project-name shipper_app --platforms=web . \
 && flutter pub get \
 && flutter build web --release

FROM node:20-alpine
WORKDIR /srv
COPY server.js .
COPY --from=build /app/build/web ./web
ENV PORT=10000
EXPOSE 10000
CMD ["node", "server.js"]
