# Stage 1: Build kubedoom binary
FROM golang:1.17-alpine AS build-kubedoom
WORKDIR /go/src/kubedoom
ADD go.mod .
ADD kubedoom.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o kubedoom .

# Stage 2: Build essential tools and download WAD file
FROM ubuntu:22.04 AS build-essentials
ARG TARGETARCH=amd64
ARG KUBECTL_VERSION=1.23.2
RUN apt-get update && apt-get install -y \
  --no-install-recommends \
  wget ca-certificates
RUN wget http://distro.ibiblio.org/pub/linux/distributions/slitaz/sources/packages/d/doom1.wad
RUN wget -O /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
  && chmod +x /usr/bin/kubectl

# Stage 3: Build psdoom
FROM ubuntu:22.04 AS build-doom
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  --no-install-recommends \
  build-essential \
  libsdl-mixer1.2-dev \
  libsdl-net1.2-dev \
  gcc
ADD /dockerdoom /dockerdoom
WORKDIR /dockerdoom/trunk
RUN ./configure && make && make install

# Stage 4: Assemble final image
FROM ubuntu:22.04
ARG VNCPASSWORD=idbehold
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
  --no-install-recommends \
  x11vnc \
  xvfb \
  netcat-openbsd \
  libsdl-mixer1.2 \
  libsdl-net1.2 \
  && rm -rf /var/lib/apt/lists/*

# Set up VNC password
RUN mkdir /root/.vnc && x11vnc -storepasswd "${VNCPASSWORD}" /root/.vnc/passwd

# Copy binaries and assets from previous stages
COPY --from=build-essentials /doom1.wad /root/
COPY --from=build-essentials /usr/bin/kubectl /usr/bin/
COPY --from=build-kubedoom /go/src/kubedoom/kubedoom /usr/bin/
COPY --from=build-doom /usr/local/games/psdoom /usr/local/games/

WORKDIR /root
ENTRYPOINT ["/usr/bin/kubedoom"]
