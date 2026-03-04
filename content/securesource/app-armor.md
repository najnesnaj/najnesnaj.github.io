---
title: 'app armour on ragflow'
draft: false
---

**you can use AppArmor to add an extra layer of confinement when running RAGFlow (especially useful if you're suspicious about potential vulnerabilities, code execution risks in agents, parser bugs, or supply-chain issues).**

RAGFlow is normally run via **docker-compose** with multiple containers (ragflow-server, Elasticsearch/Infinity, MinIO, Redis, MySQL, etc.). AppArmor confinement applies per container.

### Quick options ranked by effort vs. security gain

#### 1. Easiest — just use the built-in `docker-default` profile (almost zero effort)
On Ubuntu / Debian / derivatives where AppArmor is enabled by default, Docker already applies the **`docker-default`** profile to every container unless you override it.

Check whether it's active:

```bash
# On the host
aa-status | grep docker
docker inspect ragflow-server --format '{{.AppArmorProfile}}'
```

→ If you see `docker-default` → you're already getting baseline AppArmor protection (blocks many dangerous operations like mounting filesystems, loading kernel modules, ptrace, etc.).

This is usually "good enough" for most suspicious-but-not-paranoid cases.

#### 2. Medium effort — create a stricter custom profile for ragflow-server
The most interesting container to confine more tightly is usually **ragflow-server** (the Python part that does parsing, agent logic, potential code execution in some features).

Steps:

1. Create a file `/etc/apparmor.d/ragflow-server`

```bash
#include <tunables/global>

/usr/bin/ragflow-server flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  #include <abstractions/python>

  # Allow what Docker normally needs
  capability dac_override,
  capability setgid,
  capability setuid,
  capability sys_chroot,   # sometimes needed

  # Network (RAGFlow needs to talk to other containers + possibly internet)
  network tcp,
  network udp,

  # Very important paths — adjust according to your .env / volumes
  /etc/localtime r,
  /ragflow/ r,
  /ragflow/** rwlk,
  /app/** r,
  /ragflow/docker-entrypoint.sh ix,
  /usr/local/bin/python* ix,
  /usr/bin/python* ix,

  # Allow gunicorn / uvicorn / whatever RAGFlow uses
  /usr/local/lib/python*/site-packages/** r,
  @{PROC}/sys/kernel/random/uuid r,

  # Logging
  /var/log/** rw,

  # Deny dangerous stuff
  deny capability sys_admin,
  deny capability sys_module,
  deny capability sys_ptrace,
  deny /sys/** w,
  deny /proc/** w,
  deny /etc/** w,               # except /etc/localtime if needed
}
```

2. Load & enforce it

```bash
sudo apparmor_parser -r /etc/apparmor.d/ragflow-server
sudo aa-enforce /etc/apparmor.d/ragflow-server
```

3. Tell docker-compose to use it (edit `docker-compose.yml`)

```yaml
services:
  ragflow-server:
    ...
    security_opt:
      - apparmor:ragflow-server
```

4. Restart

```bash
docker compose up -d
```

Start in complain mode first (`aa-complain ...`) → look at `/var/log/syslog` or `dmesg | grep audit` for denials → gradually tighten.

#### 3. Hardest but strongest — very locked-down profile + read-only rootfs + drop caps

Combine:

```yaml
services:
  ragflow-server:
    ...
    security_opt:
      - apparmor:ragflow-locked
    read_only: true
    tmpfs:
      - /tmp:size=256m
      - /var/tmp:size=128m
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      # almost nothing else
```

This requires a quite permissive profile for `/tmp`, log sockets, redis/mysql/minio/tcp connections, etc. — but it dramatically reduces blast radius if something goes wrong inside the container.

### Quick reality check (2026 perspective)

- There have been **serious** issues in RAGFlow (e.g. auth bypass + code execution paths in 2025 → fixed in later releases)
- Many people run somewhat recent versions (v0.23–v0.24+)
- Still: **never expose it directly to untrusted users** if you can avoid it
- AppArmor helps mostly against **post-exploitation inside the container** — it will not prevent you from mounting a malicious model or parser exploit that runs as the container user.

If you're extremely suspicious → strongest combo is:

- up-to-date RAGFlow version  
- custom strict AppArmor profile on ragflow-server  
- read-only rootfs + minimal capabilities  
- network=internal (or no internet for workers)  
- run behind reverse proxy + authentication  
- ideally on a VM with no important data

Check: [GitHub security advisories tab](https://github.com/infiniflow/ragflow/security/advisories).
