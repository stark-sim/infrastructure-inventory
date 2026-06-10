---
name: infrastructure-inventory
description: Read the user's personal infrastructure node registry before doing anything that might involve remote servers, SSH, deployments, or infrastructure operations. Use when the user mentions nodes, servers, clusters, SSH, docker on remote hosts, kubectl, systemctl, nginx, gitlab, harbor, or any operation that might belong on a remote machine rather than the local workstation.
---

# Infrastructure Inventory

A personal node registry so the agent knows which machine does what, and stops trying to run server commands on the local mac.

## Read It First

**At the start of any session involving remote servers, deployments, or infrastructure**: read `~/.agents/inventory.yaml`.

If it doesn't exist, ask the user to create one or bootstrap from context.

## Why It Exists

Common mistake: the user says "check the k8s cluster" or "look at harbor logs" and the agent starts running `kubectl` or `docker logs` on the local mac. **Don't.** Check the inventory first to know which node owns that service, then SSH there.

## Minimal Schema

```yaml
nodes:
  <node-id>:
    name: "Human-readable name"
    role: k8s-master | k8s-worker | public-gateway | ci-server | registry | database | ...
    purpose: "What this node does"
    location: local | private-network | public-cloud
    ssh:
      host: ip-or-hostname
      user: ssh-user
      port: 22
      key: ~/.ssh/id_ed25519
    sudo:
      method: password | nopasswd
      password: null   # only non-null in ~/.agents/inventory.yaml
    services:
      - name: nginx
        type: reverse-proxy
    tags: [prod, k8s]
```

## Rules

1. **Read before acting.** If the user mentions a node name, a service, or a task that sounds like it belongs on a server, read the inventory first.
2. **Run on the right machine.** Do NOT run server-side commands (`kubectl`, `systemctl`, `docker` on remote hosts, editing remote configs, etc.) on the local workstation unless the node has `location: local`.
3. **SSH by default.** For remote nodes, build `ssh -p <port> -i <key> <user>@<host> "<command>"` and run commands there.
4. **No password leaks.** Never echo a stored password in conversation. Never write non-null passwords to git-tracked files.
