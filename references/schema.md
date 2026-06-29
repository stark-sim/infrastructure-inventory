# Inventory Schema

## Top-Level Fields

```yaml
version: 1                 # schema version, optional, default 1
nodes:                     # required, map of node-id -> Node
  <node-id>: { ... }
services:                  # optional, map of service-id -> Service for external/SaaS endpoints
  <service-id>: { ... }
```

## Node Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable display name |
| `role` | string | yes | Functional role from controlled vocabulary |
| `purpose` | string | yes | One-line description |
| `location` | string | no | `local`, `private-network`, `public-cloud`, `on-prem` |
| `ssh` | SSH | yes* | Omit only for local workstations that are never SSH'd into |
| `sudo` | Sudo | no | Defaults to `{ method: nopasswd }` if omitted |
| `resources` | Resources | no | Hardware / OS specs |
| `services` | NodeService[] | no | Services deployed on this node |
| `tags` | string[] | no | Free-form labels for filtering |
| `notes` | string | no | Arbitrary free text |

### SSH Object

```yaml
host: string       # IP address or DNS name
user: string       # SSH login name
port: integer      # default 22
key: string        # absolute or home-relative path to private key
```

### Sudo Object

```yaml
method: password | nopasswd | key
password: string | null   # plaintext only in local non-git files; null for prompt
notes: string             # e.g. "user has NOPASSWD sudo"
```

**Security rule**: `password` MUST be `null` in any file tracked by git. It may be plaintext only in `~/.agents/inventory.yaml` (which should be gitignored).

### Resources Object

```yaml
os: string         # e.g. "macOS 14", "Ubuntu 22.04"
cpu: string        # e.g. "8c"
memory: string     # e.g. "16G"
disk: string       # e.g. "500G SSD"
```

### NodeService Object

```yaml
name: string         # service name, e.g. "nginx", "postgresql"
type: string         # functional type, e.g. "reverse-proxy", "database"
ports: integer[]     # exposed ports
url: string          # optional public/private URL
credentials:         # optional, only in local non-git files
  pat: string        # e.g. GitLab/GitHub personal access token
  username: string   # e.g. Harbor username
  password: string   # e.g. Harbor password
notes: string        # e.g. "also hosts cluster-ops manifests"
```

## External Service Object

Use the top-level `services` map for endpoints that are not tied to a single node (SaaS, mirrors, managed registries).

```yaml
services:
  github:
    name: "GitHub"
    type: git-host
    url: "https://github.com"
    owner: "stark-sim"
    credentials:
      pat: "<token>"
    related_nodes: [mac-local]
    tags: [git, saas, ci]
    notes: "public mirror; GitLab is primary CI"
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | Human-readable name |
| `type` | string | yes | Functional type |
| `url` | string | no | Endpoint URL |
| `owner` | string | no | Account/organization name |
| `credentials` | Credentials | no | Service-specific credentials (local non-git files only) |
| `related_nodes` | string[] | no | Node ids that typically use this service |
| `tags` | string[] | no | Free-form labels |
| `notes` | string | no | Usage notes, including user preference |

## Role Vocabulary

Preferred values (free-form allowed, but prefer these):

- `development-workstation`
- `public-gateway`
- `k8s-master`
- `k8s-worker`
- `ci-server`
- `container-registry`
- `database`
- `cache`
- `monitoring`
- `bastion`

## Service Type Vocabulary

Preferred values for `type` on services:

- `reverse-proxy`
- `ci-server`
- `container-registry`
- `git-host`
- `kubernetes-control-plane`
- `database`
- `cache`
- `monitoring`
