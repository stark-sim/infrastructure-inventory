# Infrastructure Inventory Skill

A minimal agent skill that reads your personal node registry so the agent knows which machine does what — and stops running server commands on your local workstation.

## The Problem

You say: *"Check the k8s cluster"*  
Agent thinks: *"Let me run kubectl on this mac"*  
Reality: *kubectl only works on the k8s master node*

This skill fixes that by making the agent read your infrastructure list before acting.

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
    tags: [prod]
```

3. Mention servers, SSH, or deployments — the skill triggers automatically.

## License

MIT
