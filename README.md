# Infrastructure Inventory Skill

A minimal agent skill that reads your personal node and service registry so the agent knows which machine does what, which service to use, and where credentials live — without running server commands on your local workstation.

## The Problem

You say: *"Check the k8s cluster"*  
Agent thinks: *"Let me run kubectl on this mac"*  
Reality: *kubectl only works on the k8s master node*

Or you say: *"Check CI"*  
Agent doesn't know whether you mean GitLab or GitHub.

This skill fixes both by making the agent read your infrastructure list before acting.

## Setup

1. Put this skill in your agent's skill directory (e.g. `~/.agents/skills/infrastructure-inventory/`)
2. Create `~/.agents/inventory.yaml`:

```yaml
nodes:
  my-server:
    name: "My Server"
    role: k8s-master
    purpose: "Kubernetes control plane"
    location: private-network
    ssh:
      host: 192.168.1.10
      user: admin
      port: 22
      key: ~/.ssh/id_ed25519
    sudo:
      method: password
      password: null   # set plaintext only in local files
    services:
      - name: gitlab
        type: ci-server
        url: https://gitlab.example.com
        credentials:
          pat: "<token>"   # local files only
    tags: [prod]

services:
  github:
    name: "GitHub"
    type: git-host
    url: https://github.com
    owner: my-org
    credentials:
      pat: "<token>"       # local files only
    notes: "mirror only; GitLab is primary CI"
```

3. Mention servers, SSH, deployments, CI, or registry tokens — the skill triggers automatically.

## Security

- `~/.agents/inventory.yaml` should be gitignored.
- Keep passwords and tokens as `null` in any git-tracked example/template; set plaintext values only in the local file.

## License

MIT
