# HTTP / SOCKS5 Proxy One-Click Setup

This script installs a password-protected HTTP and/or SOCKS5 proxy on a Debian/Ubuntu VPS using `3proxy`.

Use it only on servers you own or are authorized to manage, and only for lawful browsing, testing, or account operations you are permitted to perform.

## Quick Start

Run this on your Debian/Ubuntu VPS:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wangsicong057-dotcom/http-sock5-proxy/main/setup-proxy.sh) --mode both)
```

Default result:

- HTTP proxy: port `3128`
- SOCKS5 proxy: port `1080`
- Username: `proxyuser`
- Password: `proxyuser`

The script prints the exact host, port, username, and password after installation.

## Common Examples

Only install SOCKS5:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wangsicong057-dotcom/http-sock5-proxy/main/setup-proxy.sh) --mode socks5
```

Only install HTTP:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wangsicong057-dotcom/http-sock5-proxy/main/setup-proxy.sh) --mode http
```

Restrict access to your own client IP:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wangsicong057-dotcom/http-sock5-proxy/main/setup-proxy.sh) --allow-ip 1.2.3.4
```

Uninstall:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wangsicong057-dotcom/http-sock5-proxy/main/setup-proxy.sh) --uninstall
```

## Fingerprint Browser Fields

For HTTP:

- Proxy type: `HTTP`
- Host: your VPS public IP
- Port: `3128` or your custom port
- Username: the script output
- Password: the script output

For SOCKS5:

- Proxy type: `SOCKS5`
- Host: your VPS public IP
- Port: `1080` or your custom port
- Username: the script output
- Password: the script output

If the browser cannot connect, also check your cloud provider security group/firewall and open the proxy port there.

## Server Commands

```bash
systemctl status 3proxy
journalctl -u 3proxy -f
```
