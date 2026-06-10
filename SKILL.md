---
name: infrastructure-inventory
description: Maintain and query an infrastructure node registry (servers, VMs, bare metal, cluster nodes) tracking purpose, SSH connection details, sudo auth, deployed services, and resource specs. Use whenever the user mentions nodes, servers, SSH, clusters, deployment targets, environments, infrastructure resources, or needs to connect to, deploy to, or manage remote machines. Also use when setting up CI/CD that targets remote environments or when the user says things like "what machines do I have", "connect to the server", "deploy to staging", or references any named host.
---

# Infrastructure Inventory

Maintain a structured node registry so the agent always knows what infrastructure exists, how to reach it, and what runs on it.

## Data File

Read the inventory at the **start of any session** involving remote servers. The default path is `~/.agents/inventory.yaml`. A project can also keep a secondary inventory at `<project-root>/harness/infra.yaml` — merge both if present.

If no inventory exists, ask the user whether to create one and bootstrap it from known context.

## Schema

See [references/schema.md](references/schema.md) for the full YAML schema and validation rules.

### Minimal Node Entry

```yaml
nodes:
  <node-id>:
    name: "Human-readable name"
    role: ci-server | k8s-master | k8s-worker | public-gateway | development-workstation | database | registry | ...
    purpose: "One-line description of what this node does"
    ssh:
      host: ip-or-hostname
      user: ssh-username
      port: 22
      key: ~/.ssh/id_ed25519
    sudo:
      method: password | nopasswd | key
      password: null        # plaintext only in local ~/.agents/, never in git-tracked files
    services:
      - name: nginx
        type: reverse-proxy
        ports: [80, 443]
    tags: [prod, k8s]
```

## Workflows

### Query Nodes

When the user references a node by name, role, tag, or purpose, look it up in the inventory and surface:
- Connection string: `ssh -p <port> -i <key> <user>@<host>`
- Sudo method and password hint (if stored)
- Services running on the node
- Resource summary

### Add / Update a Node

1. Collect from user: host, user, key path, role, purpose, services
2. Ask whether sudo is password-protected; if yes and the user agrees, store the password in `~/.agents/inventory.yaml` only
3. Append or update the entry, keeping YAML formatting clean
4. Run the validation script: `bash scripts/validate.sh ~/.agents/inventory.yaml`
5. Show the user a summary of the new/updated node

### SSH Connectivity Check

Before executing remote commands, verify reachability:

```bash
bash scripts/ssh-test.sh <node-id>
```

This tests:
- SSH key auth works
- `sudo -n true` succeeds (or password sudo works if a password is stored)
- Basic shell responsiveness

If any check fails, pause and ask the user before proceeding with destructive operations.

### Remote Command Execution

When running commands on a node:

1. Resolve the node from inventory
2. Run `scripts/ssh-test.sh` if not already verified this session
3. Build the SSH command with the correct key, port, and user
4. For sudo operations, prefer `sudo -n` first; fall back to password only if stored in inventory and the user has previously approved automated sudo
5. Log the operation under `harness/operations/` per the Harness dangerous-operations protocol

### Inventory Hygiene

Periodically remind the user to:
- Remove retired nodes
- Update service lists after deployments
- Rotate passwords/keys if noted in `notes`
