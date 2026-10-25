# Market data

The market data pipeline runs in its own LXC on the Proxmox host ([`proxmox/lxc/116.conf`](../../proxmox/lxc/116.conf)).
It collects Binance klines over WebSocket and includes a backtesting framework.
Code, systemd units and documentation live in their own repository:
https://github.com/robinw0410/marketdata-pipeline
