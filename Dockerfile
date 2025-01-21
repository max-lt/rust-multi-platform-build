# https://medium.com/@vladkens/fast-multi-arch-docker-build-for-rust-projects-a7db42f3adde

# (1) installing cargo-chef & build deps
FROM --platform=$BUILDPLATFORM rust:1.84 AS init

RUN mkdir -p /app/target
WORKDIR /app

ENV CARGO_HOME=/usr/local/cargo \
    RUST_BACKTRACE=1

RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    gcc-x86-64-linux-gnu \
    libc6-dev-amd64-cross \
    libc6-dev-arm64-cross

ENV CC_x86_64_unknown_linux_gnu=x86_64-linux-gnu-gcc
ENV CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc

ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=x86_64-linux-gnu-gcc
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc

# RUN cargo install --locked cargo-chef
RUN rustup target add x86_64-unknown-linux-gnu \
                      aarch64-unknown-linux-gnu

FROM init AS builder

ENV RUNTIME_SNAPSHOT_PATH=/app/target/snapshot.bin
RUN touch $RUNTIME_SNAPSHOT_PATH

# (4) Build the Rust project
COPY . .

RUN cargo build --release \
    --target x86_64-unknown-linux-gnu

RUN cargo  build --release \
    --target aarch64-unknown-linux-gnu

FROM debian:bookworm-slim

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT

RUN echo "Building for $TARGETPLATFORM ($TARGETOS/$TARGETARCH/$TARGETVARIANT)"
RUN echo "$PWD"

WORKDIR /app

# Copy the appropriate binary based on the platform
COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/rust-multi-platform-build  /app/amd64
COPY --from=builder /app/target/aarch64-unknown-linux-gnu/release/rust-multi-platform-build /app/arm64

RUN case "$TARGETPLATFORM" in \
    "linux/arm64") mv /app/arm64 /app/output && rm /app/amd64 ;; \
    "linux/amd64") mv /app/amd64 /app/output && rm /app/arm64 ;; \
    *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac

CMD ["/app/output"]

EXPOSE 8080
