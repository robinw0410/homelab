# Architecture notes

Everything below is derived from the configs in this repo ([`proxmox/`](../proxmox/), [`services/`](../services/),
[`scripts/`](../scripts/)). Internal addresses are shown as `192.168.x.x`.

## Proxmox host

One bridge (`vmbr0`) on `nic0` with a static address ([`proxmox/interfaces`](../proxmox/interfaces)).
All guests except Home Assistant are unprivileged LXCs with `nesting=1`.

| ID | Hostname | Type | vCPU / RAM | Notes |
|---|---|---|---|---|
| 100 | pihole | LXC (Ubuntu) | 1 / 1 GB | |
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
| 119 | listing-search | LXC (Debian) | 2 / 2 GB | `onboot` not set |

Every guest NIC has the Proxmox firewall flag set (`firewall=1`).

## Services

- **Docker (compose files in the repo):** Immich, TeamSpeak 6 + cloudflare-ddns, Bambuddy (host network),
  Open WebUI + cloudflared.
- **Vaultwarden:** runs as a Docker container named `vaultwarden` in LXC 106, data in `/vw-data`.
  How the container is defined (compose file / `docker run`) is not part of the export.
- **systemd:** cloudflared in the website LXC, market data collector.

## DNS

- All LXCs except 100 (pihole) and 119 (listing-search) use the same LAN resolver (`nameserver 192.168.x.x`);
  those two use `8.8.8.8`.

## Storage

From [`proxmox/storage.cfg`](../proxmox/storage.cfg):

| Storage | Path | Used for |
|---|---|---|
| `local-lvm` | LVM thin pool `pve/data` | Root disks of most guests |
| `storage` | `/mnt/pve/storage` (separate mount) | Root disks of LXC 116/119, Immich library (`immich-data`) |
| `hdd-backup` | `/mnt/media/pve-backup` (on the `/mnt/media` mount) | vzdump backups |

`/mnt/media` is also bind-mounted into Jellyfin as `/data`.
Default UID/GID mapping only (`root:100000:65536` in `subuid`/`subgid`), no `lxc.idmap` entries in the guest configs.

## Backups

- **vzdump** ([`proxmox/jobs.cfg`](../proxmox/jobs.cfg)): all guests daily at 03:00, snapshot mode, zstd,
  to `hdd-backup`. Retention: 7 daily, 4 weekly, 3 monthly. Bind mounts (`mp0`) are not part of LXC backups,
  so the Immich library is covered by restic instead.
- **restic** ([`scripts/backup/backup-immich.sh`](../scripts/backup/backup-immich.sh)): runs on the Proxmox host,
  started by [`backup-immich.timer`](../scripts/backup/systemd/backup-immich.timer) daily at 04:00
  (`Persistent=true`, so a missed run is caught up after boot). Backs up `/mnt/pve/storage/immich-data`
  (files only, no database dump) to `/mnt/media/backup/immich` and refuses to run if `/mnt/media` is not mounted.
  Retention: 7 daily, 4 weekly, 6 monthly.
- Both backup targets are on the same `/mnt/media` mount.

## Maintenance

- `lxc-update-all` every Sunday 05:00 ([`proxmox/crontab.txt`](../proxmox/crontab.txt)); the script itself is not in the repo.
- `cloudflared update` daily via [`cloudflared-update.timer`](../services/website/systemd/cloudflared-update.timer).

## External access

- **Cloudflare Tunnel (website):** `cloudflared tunnel run` as a systemd service in LXC 108.
- **Cloudflare Tunnel (Open WebUI):** separate `cloudflared` container next to Open WebUI in LXC 114.
- **Vaultwarden:** TLS certificate via `tailscale cert` for its MagicDNS name, renewed weekly by
  [`tailscale-cert-renew.timer`](../services/vaultwarden/systemd/tailscale-cert-renew.timer).
- **TeamSpeak:** no tunnel; `cloudflare-ddns` keeps an unproxied DNS record (`PROXIED=false`) up to date.
  Exposed ports: 9987/udp (voice), 30033/tcp (file transfer), 10080/tcp (web query).

## Monitoring

- The market data collector sends heartbeats to an Uptime Kuma push URL (`KUMA_PUSH_URL`).
