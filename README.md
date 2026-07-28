# Infrastructure Inventory Skill

A minimal agent skill for selecting an available development environment,
device, tool, node, or service before execution.

## The Problem

You say: *"Check the k8s cluster"*  
Agent thinks: *"Let me run kubectl on this mac"*  
Reality: *kubectl only works on the k8s master node*

Or you say: *"Check CI"*  
Agent doesn't know whether you mean GitLab or GitHub.

The same problem occurs when choosing a local runtime, GPU, container engine, or
other development tool. This skill makes the agent read one inventory before
choosing where and with what to run the task.

## Setup

1. Put this skill in your agent's skill directory (e.g. `~/.agents/skills/infrastructure-inventory/`)
2. Create `~/.agents/inventory.yaml`:

```yaml
environments:
  local-shell:
    name: Local shell
    type: shell
    node: mac-local
devices:
  apple-gpu:
    name: Apple GPU
    type: gpu
    node: mac-local
tools:
  nodejs:
    name: Node.js
    type: runtime
    environments: [local-shell]
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

3. Mention a development environment, device, tool, node, service, remote
   operation, deployment, or hardware requirement and the skill can trigger.

## Security

- `~/.agents/inventory.yaml` should be gitignored.
- Keep passwords and tokens as `null` in any git-tracked example/template; set plaintext values only in the local file.

## License

MIT
