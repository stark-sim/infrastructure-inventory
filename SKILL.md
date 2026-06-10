---
name: infrastructure-inventory
description: Maintain and query an infrastructure node registry (servers, VMs, bare metal, cluster nodes) tracking purpose, SSH connection details, sudo auth, deployed services, and resource specs. Use whenever the user mentions nodes, servers, SSH, clusters, deployment targets, environments, infrastructure resources, or needs to connect to, deploy to, or manage remote machines. Also use when setting up CI/CD that targets remote environments or when the user says things like "what machines do I have", "connect to the server", "deploy to staging", or references any named host.
---

# Infrastructure Inventory

Maintain a structured node registry so the agent always knows what infrastructure exists, how to reach it, and what runs on it.

## Security Rules — READ FIRST

This skill handles credentials. Violating these rules can leak passwords to git or conversation history.

1. **NEVER write plaintext passwords to any git-tracked file.** Before writing any inventory file, run `bash scripts/safety-check.sh <file>` to confirm it is safe.
2. **Passwords live ONLY in `~/.agents/inventory.yaml`.** This directory must be gitignored. Project-level files (`harness/infra.yaml`) MUST have `password: null` for every node.
3. **NEVER echo a stored password in conversation.** If the user asks "what is the password?", say "I have it stored locally; I will use it when needed." Do not print it.
4. **SSH keys MUST be mode 0600.** If a key file has looser permissions, warn the user and refuse to use it until fixed.
5. **Before destructive remote operations**, verify the node with `scripts/ssh-test.sh` and log the operation in `harness/operations/` per the Harness Protocol.

## Data File

Read the inventory at the **start of any session** involving remote servers.

- **User-level (secrets allowed)**: `~/.agents/inventory.yaml` — store passwords here only.
- **Project-level (secrets FORBIDDEN)**: `<project-root>/harness/infra.yaml` — node list, roles, services, but `password: null` always.

When both exist, read the user-level file for secrets and the project-level file for node metadata. Do NOT "merge" them into a single file; query both separately.

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
      password: null        # plaintext ONLY in ~/.agents/inventory.yaml
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
- Sudo method (e.g. "password-protected", "nopasswd") — do NOT reveal the password
- Services running on the node
- Resource summary

### Add / Update a Node

1. Collect from user: host, user, key path, role, purpose, services
2. Determine target file:
   - If the user says "add to project" or the node is team-shared → target `harness/infra.yaml`
   - Otherwise → target `~/.agents/inventory.yaml`
3. If target is a git-tracked file (check with `git ls-files --error-unmatch <file>`), set `password: null` unconditionally.
4. If target is `~/.agents/inventory.yaml` and sudo uses a password, ask the user: "I will store this password in ~/.agents/inventory.yaml (not in git). Confirm?"
5. Before writing, run `bash scripts/safety-check.sh <target-file>`
6. Append or update the entry, keeping YAML formatting clean
7. Run `bash scripts/validate.sh <target-file>`
8. Show the user a summary of the new/updated node (with password redacted)

### SSH Connectivity Check

Before executing remote commands, verify reachability:

```bash
bash scripts/ssh-test.sh <node-id>
```

This tests:
- SSH key auth works
- Key file permissions are 0600
- `sudo -n true` succeeds (or password sudo works if a password is stored)
- Basic shell responsiveness

If any check fails, pause and ask the user before proceeding with destructive operations.

### Remote Command Execution

When running commands on a node:

1. Resolve the node from inventory
2. Run `scripts/ssh-test.sh` if not already verified this session
3. Build the SSH command with the correct key, port, and user
4. For sudo operations:
   - Try `sudo -n` first
   - Fall back to password ONLY if stored in `~/.agents/inventory.yaml` AND the user has explicitly approved automated sudo for this session
5. Log the operation under `harness/operations/` per the Harness dangerous-operations protocol

### Inventory Hygiene

Periodically remind the user to:
- Remove retired nodes
- Update service lists after deployments
- Rotate passwords/keys if noted in `notes`
- Run `scripts/validate.sh` on all inventory files
