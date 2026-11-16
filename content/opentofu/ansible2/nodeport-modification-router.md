# Forgejo NodePort access via router / management host

## Context

Forgejo HTTP was changed from `ClusterIP` to a fixed Kubernetes `NodePort`:

- **Service:** `forgejo-http` (namespace `forgejo`)
- **Type:** `NodePort`
- **Ports:** `3000:30000/TCP` (node port **30000**)

Kubernetes NodePorts are exposed on the **cluster nodes** (Talos nodes), not automatically on the management/LXC host.

## Symptom

Accessing the management host on the NodePort fails when nothing is listening/forwarding there:

```bash
$ curl -I http://192.168.0.192:30000
curl: (7) Failed to connect to 192.168.0.192 port 30000 after 0 ms: Could not connect to server
```

Verification:

```bash
# Reachable on cluster nodes
$ ssh root@192.168.0.192 'for ip in 10.10.50.10 10.10.50.21 10.10.50.22; do curl -sS -o /dev/null -w "%{http_code} $ip\n" http://$ip:30000/; done'
200 10.10.50.10
200 10.10.50.21
200 10.10.50.22

# No local listener/forward on the management host
$ ssh root@192.168.0.192 'ss -ltnp | grep 30000 || echo "no listener on 192.168.0.192:30000"'
no listener on 192.168.0.192:30000
```

## Solutions

Choose one of the following depending on where clients connect from.

### 1. Access a cluster node directly (simplest, if reachable)

If your client can route to the Talos subnet (`10.10.50.0/24` in this environment), use any node IP:

```bash
curl -I http://10.10.50.10:30000
# or http://10.10.50.21:30000 / http://10.10.50.22:30000
```

NodePort is served by all nodes for the service.

### 2. Router / gateway port-forwarding to a cluster node

If clients are on the LAN and should reach Forgejo via a LAN/public address, configure the router (or edge firewall) to forward TCP port `30000` to a **cluster node IP** on port `30000`, for example:

- **External/LAN port:** `30000/tcp`
- **Destination:** `10.10.50.10:30000` (or another healthy node / a virtual IP in front of nodes)

Notes:
- The destination must be reachable from the router. If the router is only on the home/LAN network (e.g. `192.168.0.0/24`) and cannot route to `10.10.50.0/24`, forward to an address that can reach the nodes (e.g. the management host, if you add a forward there per option 3) or add appropriate routing.
- Consider forwarding to a stable node/VIP and restricting source addresses if exposed beyond a trusted network.
- Ensure firewall rules allow `30000/tcp` on the path.

### 3. Forward on the management host (`192.168.0.192`)

If you want `192.168.0.192:30000` to serve Forgejo (e.g. router forwards to `192.168.0.192`, or LAN clients connect to it directly), add a TCP forward on that host to a cluster node.

**Temporary (ad hoc, stops when the process exits):**

```bash
ssh root@192.168.0.192 'socat TCP-LISTEN:30000,fork,reuseaddr TCP:10.10.50.10:30000'
```

**Persistent options (choose per host OS/firewall management):**
- Run `socat` (or similar) under a systemd service.
- Add an iptables/nftables DNAT rule forwarding `192.168.0.192:30000` to `10.10.50.10:30000` (and enable forwarding/MASQUERADE as required by your network topology).
- Use the host's existing reverse proxy/load balancer to proxy to `http://10.10.50.10:30000`.

Also ensure the host firewall allows inbound `30000/tcp`.

## Related

- Playbook change and cluster verification: [`forgejo-update.md`](./forgejo-update.md)
- Forgejo playbook: [`forgejo.yml`](./forgejo.yml)
