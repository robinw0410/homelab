# Architecture notes

Proxmox and service details below are derived from the configs in this repo ([`proxmox/`](../proxmox/),
[`services/`](../services/), [`scripts/`](../scripts/)).
Hardware and the Raspberry Pis are documented from my setup; their configs are not in the repo.
Internal addresses are shown as `192.168.x.x`.

## Hardware

| Device | Specs | Role |
|---|---|---|
| HP Mini PC | Intel i5 (6th gen), 16 GB RAM, 2 TB SSD | Proxmox VE host |
| Raspberry Pi 2B | – | Secondary Pi-hole + Unbound |
| Raspberry Pi 3B | Docker | Uptime Kuma, Tailscale backup subnet router |
| External USB HDD | 8 TB, ext4, `/mnt/media` | Media storage and backup target |
| TP-Link switch | – | Rack networking |
| Rack | Lab Rax 10" 5U, 3D-printed | Housing |

## Proxmox host

One bridge (`vmbr0`) on `nic0` with a static address ([`proxmox/interfaces`](../proxmox/interfaces)).
All guests except Home Assistant are unprivileged LXCs with `nesting=1`.

| ID | Hostname | Type | vCPU / RAM | Notes |
|---|---|---|---|---|
| 100 | pihole | LXC (Ubuntu) | 1 / 1 GB | Primary Pi-hole |
| 101 | jellyfin | LXC (Ubuntu) | 2 / 4 GB | `/mnt/media` → `/data`, `/dev/dri/renderD128` passed through |
| 106 | vaultwarden | LXC (Ubuntu) | 1 / 512 MB | `/dev/net/tun` passed through |
| 108 | website | LXC (Ubuntu) | 1 / 512 MB | nginx + cloudflared |
| 109 | haos-17.0 | VM (q35, OVMF) | 2 / 4 GB | Home Assistant OS |
| 110 | immich | LXC (Ubuntu) | 4 / 6 GB | `/mnt/pve/storage/immich-data` → `/mnt/photos`, `/dev/net/tun` |
| 111 | teamspeak | LXC (Ubuntu) | 1 / 1 GB | |
| 112 | bambuddy | LXC (Ubuntu) | 2 / 2 GB | `keyctl=1`, `/dev/net/tun` |
| 113 | tika | LXC (Ubuntu) | 2 / 2 GB | no service config exported |
| 114 | openwebgui | LXC (Debian) | 2 / 2 GB | |
| 116 | crypto | LXC (Debian) | 2 / 4 GB | |
| 119 | listing-search | LXC (Debian) | 2 / 2 GB | Listing search, see [`listing-search/`](../listing-search/); `onboot` not set |

Every guest NIC has the Proxmox firewall flag set (`firewall=1`).

## Services

- **Docker (compose files in the repo):** Immich, TeamSpeak 6 + cloudflare-ddns, Bambuddy (host network),
  Open WebUI + cloudflared.
- **Vaultwarden:** Docker container `vaultwarden` in LXC 106 (originally started with `docker run`, recreated as
  [`docker-compose.yml`](../services/vaultwarden/docker-compose.yml)). Host port 443 → container port 80, data in
  `/vw-data`, Rocket serves TLS itself (`ROCKET_TLS`) with the Tailscale certificate, signups disabled.
- **systemd:** cloudflared in the website LXC, market data collector.

## DNS

- **Primary Pi-hole:** LXC 100 on the Proxmox host.
- **Secondary Pi-hole + Unbound:** Raspberry Pi 2B. Unbound resolves recursively with DNSSEC validation.
- LAN clients use both Pi-holes.
- All LXCs except 100 (pihole) and 119 (listing-search) use the same LAN resolver (`nameserver 192.168.x.x`);
  those two use `8.8.8.8`.

## Storage

From [`proxmox/storage.cfg`](../proxmox/storage.cfg):

| Storage | Path | Used for |
|---|---|---|
| `local-lvm` | LVM thin pool `pve/data` | Root disks of most guests |
| `storage` | `/mnt/pve/storage` (2 TB SSD) | Root disks of LXC 116/119, Immich library (`immich-data`) |
| `hdd-backup` | `/mnt/media/pve-backup` (8 TB USB HDD, ext4) | vzdump backups |

The USB HDD at `/mnt/media` holds media and backups; it is bind-mounted into Jellyfin as `/data`.
Default UID/GID mapping only (`root:100000:65536` in `subuid`/`subgid`), no `lxc.idmap` entries in the guest configs.

## Backups

Nightly sequence, no overlaps:

| Time | Job | Details |
|---|---|---|
| 02:00 | Immich DB dump | Immich's built-in database backup into its upload folder `/mnt/pve/storage/immich-data/backups`, 14 dumps kept |
| 03:00 – ~03:20 | vzdump ([`proxmox/jobs.cfg`](../proxmox/jobs.cfg)) | All guests, snapshot mode, zstd, to `hdd-backup`. Retention 7 daily, 4 weekly, 3 monthly |
| 04:00 | restic ([`scripts/backup/backup-immich.sh`](../scripts/backup/backup-immich.sh)) | Immich library incl. database dumps to `/mnt/media/backup/immich`. Retention 7 daily, 4 weekly, 6 monthly |

- restic runs on the Proxmox host, started by [`backup-immich.timer`](../scripts/backup/systemd/backup-immich.timer)
  (`Persistent=true`, so a missed run is caught up after boot), and refuses to run if `/mnt/media` is not mounted.
- Bind mounts (`mp0`) are not part of LXC backups, so the Immich library is covered by restic instead of vzdump.
- Both backup targets are on the same 8 TB USB HDD.

## Maintenance

- `lxc-update-all` every Sunday 05:00 ([`proxmox/crontab.txt`](../proxmox/crontab.txt)); the script itself is not in the repo.
- `cloudflared update` daily via [`cloudflared-update.timer`](../services/website/systemd/cloudflared-update.timer).

## External access

- **Cloudflare Tunnel (website):** `cloudflared tunnel run` as a systemd service in LXC 108.
- **Cloudflare Tunnel (Open WebUI):** separate `cloudflared` container next to Open WebUI in LXC 114.
- **Tailscale:** Vaultwarden is reached via its MagicDNS name. Its TLS certificate comes from `tailscale cert`
  and is renewed weekly by [`tailscale-cert-renew.timer`](../services/vaultwarden/systemd/tailscale-cert-renew.timer),
  which also restarts the container.
- **Tailscale backup subnet router:** Raspberry Pi 3B (Tailscale configs are not in the repo).
- **TeamSpeak:** no tunnel; `cloudflare-ddns` keeps an unproxied DNS record (`PROXIED=false`) up to date.
  Exposed ports: 9987/udp (voice), 30033/tcp (file transfer), 10080/tcp (web query).

## Monitoring

- Uptime Kuma runs in Docker on the Raspberry Pi 3B.
- Rack temperature and humidity come from the ESP32 [rack fan controller](../hardware/rack-fan/), which also switches the rack fan.
- The market data collector sends heartbeats to an Uptime Kuma push URL (`KUMA_PUSH_URL`).
