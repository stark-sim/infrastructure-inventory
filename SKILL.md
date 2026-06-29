---
name: infrastructure-inventory
description: Read the user's personal infrastructure node and service registry before doing anything that might involve remote servers, SSH, deployments, service APIs, or infrastructure operations. Use when the user mentions nodes, servers, clusters, SSH, docker on remote hosts, kubectl, systemctl, nginx, gitlab, github, harbor, registry tokens, CI PATs, or any operation that might belong on a remote machine or service.
---

# Infrastructure Inventory

A personal registry of **nodes** and **services** so the agent knows which machine does what, which service to use, and where credentials live — without confusing the local workstation with remote hosts.

## Read It First

**At the start of any session involving remote servers, deployments, infrastructure, or service APIs**: read `~/.agents/inventory.yaml`.

If it doesn't exist, ask the user to create one or bootstrap from context.

## Why It Exists

Common mistakes:
- The user says "check the k8s cluster" and the agent runs `kubectl` on the local mac.
- The user says "check CI" and the agent doesn't know whether they mean GitLab or GitHub.
- The user says "worker node" and the agent picks the wrong machine.

**Don't.** Check the inventory first to find the right node or service, then act.

## Minimal Schema

```yaml
nodes:
  <node-id>:
    name: "Human-readable name"
    role: k8s-master | k8s-worker | public-gateway | ci-server | registry | ...
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
      - name: gitlab
        type: ci-server
        url: https://gitlab.example.com
        credentials:
          pat: "<token>"       # local non-git files only
      - name: harbor
        type: container-registry
        url: https://harbor.example.com
        credentials:
          username: "<user>"
          password: "<pass>"    # local non-git files only
    tags: [prod, k8s]

services:
  github:
    name: "GitHub"
    type: git-host
    url: "https://github.com"
    owner: "owner-name"
    credentials:
      pat: "<token>"           # local non-git files only
    related_nodes: [mac-local]
    notes: "mirror only; GitLab is primary CI"
```

- **Node `services`**: services running on that specific machine. A node can have many responsibilities.
- **Top-level `services`**: external/SaaS endpoints not tied to one node.

## Rules

1. **Read before acting.** If the user mentions a node name, a service, a token, or a task that sounds like it belongs on a server, read the inventory first.
2. **Run on the right machine.** Do NOT run server-side commands (`kubectl`, `systemctl`, `docker` on remote hosts, editing remote configs, etc.) on the local workstation unless the node has `location: local`.
3. **Pick the right service.** If multiple services match a request (e.g., GitLab and GitHub both exist), use the `notes` field or ask the user for preference.
4. **SSH by default.** For remote nodes, build `ssh -p <port> -i <key> <user>@<host> "<command>"` and run commands there.
5. **Use credentials from inventory.** For API calls to GitLab/GitHub/Harbor, use the token/password stored in the service's `credentials` block.
6. **No secret leaks.** Never echo a stored password/token in conversation. Never write non-null secrets to git-tracked files.

## Workflows

### Find a Node

Match by `role`, `purpose`, `tags`, or `services.name`.

- "worker node" → `role: k8s-worker`
- "gateway" → `role: public-gateway`
- "where is GitLab?" → node whose `services` contains `name: gitlab`

### Find a Service

Check node `services` and top-level `services` for the requested type.

- "check CI" → `type: ci-server`
- "git host" → `type: git-host`
- "registry" → `type: container-registry`

### Retrieve a Credential

1. Locate the service entry (node-level or top-level).
2. Use the credential inline for the API call.
3. Do not log, commit, or persist the credential elsewhere.
