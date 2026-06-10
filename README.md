# Infrastructure Inventory Skill

An agent skill for maintaining a structured registry of infrastructure nodes (servers, VMs, bare metal, cluster nodes) and using that registry to automate SSH connections, remote operations, and deployment targeting.

## What It Does

- **Tracks nodes**: hostname, role, purpose, SSH credentials, sudo auth, deployed services, resource specs
- **Automates SSH**: builds correct `ssh -i <key> -p <port> <user>@<host>` commands from inventory
- **Validates connectivity**: checks key auth and sudo before destructive operations
- **Enforces hygiene**: validates YAML schema, warns about passwords in git-tracked files

## Quick Start

1. Install the skill into your agent's skill directory (e.g. `~/.agents/skills/`)
2. Create `~/.agents/inventory.yaml` from the template below
3. The agent reads it automatically whenever you mention servers, SSH, or deployments

### Minimal Inventory Template

```yaml
nodes:
  my-server:
    name: "My Server"
    role: k8s-master
    purpose: "Kubernetes control plane and GitLab"
    ssh:
      host: 192.168.1.10
      user: admin
      port: 22
      key: ~/.ssh/id_ed25519
    sudo:
      method: password
      password: null   # set plaintext only in local files, never in git
    services:
      - name: gitlab
        type: ci-server
        ports: [443]
    tags: [prod, k8s]
```

## Scripts

- `scripts/ssh-test.sh <node-id>` — verify SSH key auth and sudo for a node
- `scripts/validate.sh [inventory.yaml]` — validate YAML schema and check for password leaks

## Security Notes

- `sudo.password` should be `null` in any git-tracked file. Only store plaintext passwords in `~/.agents/inventory.yaml`, which should be gitignored.
- The skill prefers `sudo -n` (non-interactive) and falls back to password only when stored and user-approved.

## License

MIT
