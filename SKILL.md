---
name: infrastructure-inventory
description: Use when a task may depend on choosing an available development environment, device, tool, node, or service, especially before local or remote execution, SSH, deployment, hardware-intensive work, or service API use. Also use when starting local services that have stateful dependencies (database, Redis, message queue, Docker), when a required dependency or port is missing/conflicting locally, or when deciding where integration/E2E testing infrastructure should run — the answer may be a remote node or an SSH tunnel rather than installing/starting it locally. Also use whenever a workflow step — a check, gate, build, test, deploy, verification script, CI job, or pre-push hook — needs specific tooling (kubectl, docker, a compiler, a service endpoint): read the inventory to decide which registered node actually has that tool before running it anywhere, so cluster-side checks land on cluster nodes instead of rotting on a workstation. Also use before installing anything locally that a remote node already provides. Also use when creating, editing, or reviewing executable workflow artifacts — scripts, gates, pre-push hooks, CI jobs, Makefiles, preflight or drift checks — because every command baked into such an artifact must be matched to a node that actually provides its tool; placement decided at authoring time, not at run time.
---

# Infrastructure Inventory

A registry of available development environments, devices, tools, nodes, and
services. Its job is to answer one question before execution: **where and with
what should this work run?**

## Read It First

Read `~/.agents/inventory.yaml` when the execution target or required capability
is uncertain. This includes local development, hardware selection, remote work,
deployments, and service APIs.

If it doesn't exist, ask the user to create one or bootstrap from context.

## Why It Exists

Common mistakes:
- Starting Docker on a workstation where it is intentionally unavailable.
- Choosing CPU when a compatible GPU environment exists, or choosing a busy GPU.
- Assuming a runtime or CLI is installed without checking its registered location.
- Running a server command locally or choosing the wrong CI/Git service.
- Installing or starting a stateful dependency (Postgres, Redis, Docker) locally
  when the project's sanctioned instance lives on a remote node — prefer an SSH
  tunnel to that node instead.
- **Baking a tool into an executable artifact that the runtime node does not
  provide.** When you write `kubectl`, `docker`, or any node-specific CLI into a
  script, gate, pre-push hook, CI job, or Makefile, you are making a placement
  decision for every future run of that artifact. Check the inventory at
  authoring time: if the tool is not registered on the node where the artifact
  will run, the step belongs on the node that has it. A check that only works
  via a workstation-bundled symlink (e.g. Docker Desktop's `kubectl`) will rot
  the day the bundle updates, and the failure surfaces as a false-positive gate
  blocking unrelated work — long after the authoring decision is forgotten.

**Don't.** Check the inventory first to find the right node or service, then act.

## Entity Model

| Entity | Represents | Examples |
|---|---|---|
| `environments` | Runnable contexts | local shell, conda env, container, k8s context |
| `devices` | Usable hardware | CPU, CUDA GPU, MPS GPU, accelerator |
| `tools` | Installed capabilities | Node.js, Python, Docker, kubectl, compiler |
| `nodes` | Local or remote hosts | workstation, GPU server, cluster node |
| `services` | Addressable endpoints | GitHub, GitLab, registry, database, API |

All sections are maps keyed by stable IDs. Keep only facts that help select or
reach a target; detailed procedures belong in their owning skills.

## Minimal Schema

```yaml
environments:
  local-shell:
    name: "Local shell"
    type: shell
    node: mac-local
    status: available
devices:
  apple-gpu:
    name: "Apple GPU"
    type: gpu
    node: mac-local
    status: available
tools:
  nodejs:
    name: "Node.js"
    type: runtime
    environments: [local-shell]
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

## Selection Rule

1. Determine the capabilities and constraints the task actually needs.
2. Filter inventory entries by availability, compatibility, access, and policy.
3. Choose the smallest capable target. Do not start or install something merely
   because it appears in inventory.
4. Verify volatile facts such as current load, free disk, port use, process
   state, and service health immediately before execution.

Inventory describes known options; it is not live monitoring and does not
authorize an operation.

## Rules

1. **Read before choosing.** If a task depends on an environment, device, tool,
   node, or service, read the inventory first.
2. **Run on the right machine.** Do NOT run server-side commands (`kubectl`, `systemctl`, `docker` on remote hosts, editing remote configs, etc.) on the local workstation unless the node has `location: local`.
2a. **Author on the right machine too.** Before adding any command to an executable artifact (script, gate, hook, CI job, Makefile, preflight/drift check), look up each required tool in the inventory and confirm the node where that artifact runs provides it. Workstation-class tools used only via bundled symlinks do not count as provided. If the right node is remote, make the artifact SSH there (or split the artifact into a local static part and a remote part) instead of embedding the command locally.
3. **Pick the right service.** If multiple services match a request (e.g., GitLab and GitHub both exist), use the `notes` field or ask the user for preference.
4. **SSH by default.** For remote nodes, build `ssh -p <port> -i <key> <user>@<host> "<command>"` and run commands there.
5. **Use credentials from inventory.** For API calls to GitLab/GitHub/Harbor, use the token/password stored in the service's `credentials` block.
6. **No secret leaks.** Never echo a stored password/token in conversation. Never write non-null secrets to git-tracked files.

## Workflows

### Find an Environment, Device, or Tool

Match required capabilities first, then follow its `node`, `environments`, or
related references. Verify dynamic availability at execution time.

- "run a Node build" -> environment containing a compatible Node.js tool
- "GPU test" -> available device plus a compatible runtime environment
- "use Docker" -> node and environment where Docker is permitted

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
