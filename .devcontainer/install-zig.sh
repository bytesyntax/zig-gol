#!/usr/bin/env sh
set -e

##################################
# Architecture detection
##################################

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)
        ZIG_ARCH="x86_64"
        ;;
    aarch64|arm64)
        ZIG_ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

echo "Detected architecture: $ZIG_ARCH"

##################################
# Versions
##################################

ZIG_VERSION="$1"
MINISIGN_VERSION="$2"

HOME_DIR="/home/vscode"
BIN_DIR="$HOME_DIR/.local/bin"
MINISIGN_BIN="$HOME_DIR/minisign-linux/$ZIG_ARCH/minisign"

mkdir -p "$BIN_DIR"
cd "$HOME_DIR"

##################################
# Download & install minisign
##################################

MINISIGN_TARBALL="minisign-${MINISIGN_VERSION}-linux.tar.gz"
MINISIGN_URL="https://github.com/jedisct1/minisign/releases/download/${MINISIGN_VERSION}/${MINISIGN_TARBALL}"
MINISIGN_SIG_URL="${MINISIGN_URL}.minisig"
MINISIGN_PUBKEY="RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"

curl -fsSLO "$MINISIGN_URL"
curl -fsSLO "$MINISIGN_SIG_URL"

tar -xzf "$MINISIGN_TARBALL"

"$MINISIGN_BIN" -Vm "$MINISIGN_TARBALL" -P "$MINISIGN_PUBKEY"

ln -sf "$MINISIGN_BIN" "$BIN_DIR/minisign"

##################################
# Helper: version compare
##################################

version_lt() {
    [ "$1" != "$2" ] && printf '%s\n%s\n' "$1" "$2" | sort -C -V
}

##################################
# Download & install Zig
##################################

if version_lt "$ZIG_VERSION" "0.14.1"; then
    ZIG_TARBALL="zig-linux-${ZIG_ARCH}-${ZIG_VERSION}"
else
    ZIG_TARBALL="zig-${ZIG_ARCH}-linux-${ZIG_VERSION}"
fi

ZIG_URL="https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TARBALL}.tar.xz"
ZIG_SIG_URL="${ZIG_URL}.minisig"
ZIG_PUBKEY="RWSGOq2NVecA2UPNdBUZykf1CCb147pkmdtYxgb3Ti+JO/wCYvhbAb/U"

curl -fsSLO "$ZIG_URL"
curl -fsSLO "$ZIG_SIG_URL"

"$MINISIGN_BIN" -Vm "${ZIG_TARBALL}.tar.xz" -P "$ZIG_PUBKEY"

tar -xf "${ZIG_TARBALL}.tar.xz"
ln -sf "$HOME_DIR/${ZIG_TARBALL}/zig" "$BIN_DIR/zig"

##################################
# Download & install ZLS
##################################

ZLS_VERSION="$(echo "$ZIG_VERSION" | cut -d. -f1,2).0"

if version_lt "$ZLS_VERSION" "0.15.0"; then
    ZLS_TARBALL="zls-linux-${ZIG_ARCH}-${ZLS_VERSION}"
else
    ZLS_TARBALL="zls-${ZIG_ARCH}-linux-${ZLS_VERSION}"
fi

ZLS_URL="https://builds.zigtools.org/${ZLS_TARBALL}.tar.xz"
ZLS_SIG_URL="${ZLS_URL}.minisig"
ZLS_PUBKEY="RWR+9B91GBZ0zOjh6Lr17+zKf5BoSuFvrx2xSeDE57uIYvnKBGmMjOex"

curl -fsSLO "$ZLS_URL"
curl -fsSLO "$ZLS_SIG_URL"

"$MINISIGN_BIN" -Vm "${ZLS_TARBALL}.tar.xz" -P "$ZLS_PUBKEY"

tar -xf "${ZLS_TARBALL}.tar.xz"
ln -sf "$HOME_DIR/zls" "$BIN_DIR/zls"

##################################
# Done
##################################

echo "Zig and ZLS installed successfully"

