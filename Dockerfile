# Multi-stage build: compile a static-ish release binary, ship it on a slim base.
# Rename `service-template` to your crate's binary name when you create a repo.
FROM rust:1-slim AS build
WORKDIR /app
COPY . .
RUN cargo build --release --locked

FROM debian:stable-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 service
COPY --from=build /app/target/release/service-template /usr/local/bin/service
USER service
ENTRYPOINT ["/usr/local/bin/service"]
