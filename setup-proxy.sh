  esac
done

is_root || die "Please run as root: sudo bash setup-proxy.sh"

case "$MODE" in
  both|http|socks5) ;;
  *) die "--mode must be one of: both, http, socks5" ;;
esac

valid_token "$PROXY_USER" || die "Username may only contain letters, numbers, dot, underscore, @, and hyphen."

valid_port "$HTTP_PORT" || die "Invalid HTTP port: $HTTP_PORT"
valid_port "$SOCKS_PORT" || die "Invalid SOCKS5 port: $SOCKS_PORT"

if [ "$MODE" = "both" ] && [ "$HTTP_PORT" = "$SOCKS_PORT" ]; then
  die "HTTP and SOCKS5 ports must be different when --mode both is used."
fi

if ! command -v apt-get >/dev/null 2>&1; then
  die "This one-click script currently supports Debian/Ubuntu systems with apt-get."
fi

export DEBIAN_FRONTEND=noninteractive
log "Installing dependencies..."
apt-get update -y
apt-get install -y curl ca-certificates openssl

valid_token "$PROXY_PASS" || die "Password may only contain letters, numbers, dot, underscore, @, and hyphen."

install_3proxy_from_release() {
  local version arch asset tmpdeb url
  version="0.9.6"
  arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

  case "$arch" in
    amd64|x86_64)
      asset="3proxy-${version}.x86_64.deb"
      ;;
    arm64|aarch64)
      asset="3proxy-${version}.arm64.deb"
      ;;
    armhf|armv7l|armv6l)
      asset="3proxy-${version}.arm.deb"
      ;;
    *)
      die "Unsupported CPU architecture for 3proxy release package: $arch"
      ;;
  esac

  tmpdeb="$(mktemp)"
  url="https://github.com/3proxy/3proxy/releases/download/${version}/${asset}"
  log "Downloading ${asset}..."
  curl -fL --retry 3 -o "$tmpdeb" "$url"

  if ! apt-get install -y "$tmpdeb"; then
    dpkg -i "$tmpdeb" || true
    apt-get -f install -y
  fi

  rm -f "$tmpdeb"
}

if command -v 3proxy >/dev/null 2>&1; then
  log "3proxy is already installed."
elif apt-cache show 3proxy >/dev/null 2>&1; then
  log "Installing 3proxy from apt..."
  apt-get install -y 3proxy
else
  log "3proxy package not found in apt, installing official release package..."
  install_3proxy_from_release
fi

PROXY_BIN="$(command -v 3proxy || true)"
[ -n "$PROXY_BIN" ] || die "3proxy installation failed."

mkdir -p /etc/3proxy /var/log/3proxy
touch /var/log/3proxy/3proxy.log

acl_line="allow ${PROXY_USER}"
if [ -n "$ALLOW_IP" ]; then
  acl_line="allow ${PROXY_USER} ${ALLOW_IP}"
fi

{
  cat <<CONFIG
nserver 1.1.1.1
nserver 8.8.8.8
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

log /var/log/3proxy/3proxy.log D
logformat "L%d-%m-%Y %H:%M:%S %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

auth strong
users ${PROXY_USER}:CL:${PROXY_PASS}
${acl_line}
internal 0.0.0.0
CONFIG

  if [ "$MODE" = "both" ] || [ "$MODE" = "http" ]; then
    printf 'proxy -p%s\n' "$HTTP_PORT"
  fi

  if [ "$MODE" = "both" ] || [ "$MODE" = "socks5" ]; then
    printf 'socks -p%s\n' "$SOCKS_PORT"
  fi
} > /etc/3proxy/3proxy.cfg

chmod 600 /etc/3proxy/3proxy.cfg

cat > /etc/systemd/system/3proxy.service <<SERVICE
[Unit]
Description=3proxy HTTP/SOCKS5 proxy service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${PROXY_BIN} /etc/3proxy/3proxy.cfg
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable 3proxy >/dev/null
if ! systemctl restart 3proxy; then
  journalctl -u 3proxy --no-pager -n 50
  die "3proxy failed to start."
fi

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  if [ "$MODE" = "both" ] || [ "$MODE" = "http" ]; then
    ufw allow "${HTTP_PORT}/tcp" comment "3proxy-http" >/dev/null || true
  fi
  if [ "$MODE" = "both" ] || [ "$MODE" = "socks5" ]; then
    ufw allow "${SOCKS_PORT}/tcp" comment "3proxy-socks5" >/dev/null || true
  fi
fi

PUBLIC_IP="$(curl -fsS4 --max-time 6 https://api.ipify.org || true)"
if [ -z "$PUBLIC_IP" ]; then
  PUBLIC_IP="<your-server-ip>"
fi

if ! systemctl --no-pager --full status 3proxy >/dev/null; then
  journalctl -u 3proxy --no-pager -n 50
  die "3proxy failed to start."
fi

printf '\n'
log "Done. Use these settings in your fingerprint browser:"
printf '\n'
if [ "$MODE" = "both" ] || [ "$MODE" = "http" ]; then
  printf 'HTTP proxy\n'
  printf '  Host: %s\n' "$PUBLIC_IP"
  printf '  Port: %s\n' "$HTTP_PORT"
  printf '  Username: %s\n' "$PROXY_USER"
  printf '  Password: %s\n' "$PROXY_PASS"
  printf '  URL: http://%s:%s@%s:%s\n\n' "$PROXY_USER" "$PROXY_PASS" "$PUBLIC_IP" "$HTTP_PORT"
fi

if [ "$MODE" = "both" ] || [ "$MODE" = "socks5" ]; then
  printf 'SOCKS5 proxy\n'
  printf '  Host: %s\n' "$PUBLIC_IP"
  printf '  Port: %s\n' "$SOCKS_PORT"
  printf '  Username: %s\n' "$PROXY_USER"
  printf '  Password: %s\n' "$PROXY_PASS"
  printf '  URL: socks5://%s:%s@%s:%s\n\n' "$PROXY_USER" "$PROXY_PASS" "$PUBLIC_IP" "$SOCKS_PORT"
fi

printf 'Useful commands:\n'
printf '  systemctl status 3proxy\n'
printf '  journalctl -u 3proxy -f\n'
printf '  sudo bash setup-proxy.sh --uninstall\n'
printf '\n'
printf 'If your VPS provider has a security group/cloud firewall, open the proxy port there too.\n'
