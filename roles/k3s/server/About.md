# K3s Server Role — Architecture & Decisions

## Overview

Single-node k3s server with Caddy on the host handling TLS termination and Traefik inside the cluster handling HTTP ingress routing.

## Traffic Flow

```
Internet → Caddy (TLS on host) → 127.0.0.1:80 → Traefik (HTTP in cluster) → ClusterIP Services → Pods
```

## Architecture Decisions

### Caddy on the host + Traefik in the cluster

- **Caddy** handles TLS termination, certificate management, and is the only process exposed to the internet.
- **Traefik** runs inside k3s as the default ingress controller, configured for HTTP-only on `127.0.0.1:80` via hostPort.
- This separation keeps TLS management simple (Caddy) while leveraging Kubernetes-native ingress routing (Traefik).

### Traefik HTTP-only, bound to localhost

- Traefik's HTTPS (websecure) listener is disabled — Caddy handles TLS.
- Traefik's HTTP port is bound to `127.0.0.1` via hostPort, so it's only reachable from the host.
- A local shell user can reach Traefik on localhost, but Traefik only routes traffic based on Ingress rules (hostname/path), limiting exposure.
- Configuration: `roles/k3s/server/files/traefik-config.yaml` (HelmChartConfig)

### servicelb (Klipper) disabled

- Klipper automatically binds LoadBalancer service ports on all node interfaces — this would expose services to the network, bypassing the localhost-only setup.
- Not needed since Traefik uses hostPort directly.
- On a multi-node setup, Klipper would be useful to expose Traefik on every node without managing hostPort manually. Not applicable here.

### Calico CNI

- Replaces the default Flannel.
- Provides NetworkPolicy support to restrict pod-to-pod traffic — only Traefik should reach application pods.
- Flannel backend is set to `none` and default network policy is disabled in k3s config to let Calico handle everything.

### All application services are ClusterIP only

- No NodePort or hostPort on application pods.
- Services are only reachable through Traefik via Ingress resources.
- This provides network isolation — even with shell access on the host, individual services can't be reached directly (only via Traefik with proper Host headers).
- Multiple replicas work naturally since there's no hostPort conflict on application pods.

### kubeconfig access control

- `write-kubeconfig-mode: 0640` — only root and the `k3s-admin` group can read the kubeconfig.
- A `k3s-admin` group is created and users listed in `k3s_server.admins` are added to it.
- `ExecStartPost` in the systemd service sets the group ownership on every k3s (re)start.
- `KUBECONFIG` env var is set globally via `/etc/profile.d/k3s.sh` — harmless for users not in the group.

## Network Security Summary

| Layer | What it protects |
|-------|-----------------|
| Caddy (host) | TLS termination, only external entry point |
| hostPort 127.0.0.1 | Traefik not reachable from network, only from host |
| Traefik Ingress rules | Routes only matching hostname/path, not a generic proxy |
| Calico NetworkPolicies | Pod-to-pod isolation, only Traefik reaches app pods |
| ClusterIP services | No ports bound on the host for application pods |
| kubeconfig 0640 + k3s-admin | Cluster API access restricted to authorized users |

## Configuration Reference

| File | Purpose |
|------|---------|
| `defaults/main.yaml` | Role variables: CIDRs, DNS, Calico version, admin users |
| `templates/config.yaml.j2` | k3s server config |
| `templates/k3s.service.j2` | systemd unit with kubeconfig group fix |
| `files/traefik-config.yaml` | HelmChartConfig: HTTP-only, localhost binding |
| `files/calico-*.yaml` | Calico CNI manifest |
