# Permission issues between unprivileged LXCs and Docker containers

## Problem

<!-- What did you see? Which error messages, which service failed? -->

## Background: UID mapping in unprivileged LXCs

In an unprivileged LXC, UIDs inside the container are shifted on the host by an offset (default `100000`).
A file owned by UID `1000` inside the container appears as UID `101000` on the host.
When several containers share a host directory, their effective UIDs must match, otherwise one side cannot write.

## Analysis

<!-- How did you narrow it down? Commands you used, e.g.: -->

```bash
ls -ln /mnt/media
pct config <ID> | grep mp
cat /etc/subuid /etc/subgid
```

## Solution

<!-- What exactly did you change? idmap entries, chown, setgid bit on directories, category paths, ... -->

## What I learned

<!-- 2–3 sentences -->
