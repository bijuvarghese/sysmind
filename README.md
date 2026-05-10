# SysMind

SysMind is a multi-service local MCP workspace:

- `sysmind-ui`: Next.js 16 chat UI.
- `sysmind-mcp`: Spring Boot 4 stateless MCP tool server.
- `sysmind-agent`: Spring Boot 4 agent service that can use an OpenAI-compatible local model server and call the MCP backend.
- `sysmind-ios`: Native SwiftUI iOS chat app that talks directly to the agent over HTTP and server-sent events.

Local development defaults:

- MCP backend on `http://localhost:8080`
- Stateless MCP endpoint on `http://localhost:8080/mcp`
- UI on `http://localhost:3000`
- Agent on `http://localhost:4000`
- Agent model server on `http://localhost:1234`

The current Docker stack exposes a single nginx entry point:

- UI on `http://localhost:${NGINX_PORT:-80}`
- Stateless MCP endpoint on `http://localhost:${NGINX_PORT:-80}/mcp`

`sysmind-agent` is wired into the root Compose stack between the UI and MCP backend.

## Configuration

Clone this repository with its submodules:

```bash
git clone --recurse-submodules https://github.com/bijuvarghese/sysmind.git
```

If you already cloned it, initialize the service submodules before building:

```bash
./bootstrap-submodules.sh
```

Copy the sample env file before running the Docker stack:

```bash
cp .env.example .env
```

Values in `.env.example`:

```env
NGINX_PORT=80
SPRING_PROFILES_ACTIVE=docker
CHROMA_IMAGE=chromadb/chroma:1.5.0
AGENT_BACKEND_URL=http://sysmind-agent:4000
AGENT_MCP_BACKEND_URL=http://sysmind-mcp:8080
AGENT_MCP_ENDPOINT=/mcp
MCP_CHROMA_URL=http://chroma:8000
AGENT_PORT=4000
AGENT_LM_STUDIO_BASE_URL=http://host.docker.internal:1234
AGENT_LM_STUDIO_API_KEY=lm-studio
AGENT_LM_STUDIO_MODEL=google/gemma-4-e4b
TOOL_TIMEOUT=10s
AGENT_TIMEOUT=60s
MAX_TOOL_CALLS_PER_USER_REQUEST=3
CHROMA_TIMEOUT=5s
CHROMA_TENANT=default_tenant
CHROMA_DATABASE=default_database
CHROMA_COLLECTION=sysmind
NEWS_LANGUAGE=en-US
NEWS_COUNTRY=US
NEWS_CEID=
NEXT_ALLOWED_DEV_ORIGINS=
```

The Docker stack also starts Chroma at `http://chroma:8000` for vector storage. The `chroma_status` tool lets clients verify connectivity before retrieval features are added.

`CHROMA_IMAGE` pins the Chroma container for repeatable local runs. Override it in `.env` when intentionally testing a newer Chroma image.

`NEXT_ALLOWED_DEV_ORIGINS` is optional and only applies to Next.js development. Set it to a comma-separated list of LAN hosts when another device needs to reach `next dev`.

## Services

| Service | Path | Default URL | Role |
| --- | --- | --- | --- |
| UI | `sysmind-ui` | `http://localhost:3000` | Browser chat interface and API proxy for the agent. |
| iOS | `sysmind-ios` | Agent URL from `SysMindIOS/Info.plist` or in-app settings | Native SwiftUI chat client for the agent. |
| MCP backend | `sysmind-mcp` | `http://localhost:8080/mcp` | Stateless MCP server exposing local system, news, and Chroma tools. |
| Agent | `sysmind-agent` | `http://localhost:4000` | Spring AI agent service configured for LM Studio/OpenAI-compatible chat and MCP tool access. |
| Chroma | Compose service | `http://localhost:8000` locally, `http://chroma:8000` in Compose | Vector database used by MCP health checks and future retrieval features. |

The root Compose stack adds health checks for Chroma, MCP, agent, UI, and nginx. Startup dependencies wait for healthy upstreams where Compose supports `depends_on.condition: service_healthy`.

## MCP Endpoint

The backend exposes a stateless MCP Streamable HTTP endpoint:

- Direct backend: `POST http://localhost:8080/mcp`
- Docker/nginx: `POST http://localhost:${NGINX_PORT:-80}/mcp`

Use these headers from Postman or another JSON-RPC client:

```http
Content-Type: application/json
Accept: application/json, text/event-stream
```

Initialize:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {},
    "clientInfo": {
      "name": "postman",
      "version": "1.0.0"
    }
  }
}
```

List tools:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

Registered tools:

- `latest_news`: fetches current web news headlines from the configured RSS feed.
- `chroma_status`: checks whether the Chroma vector database is reachable.
- `machine_status`: returns computer name, OS, CPU, RAM, storage, and uptime details.

Call a tool:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "machine_status",
    "arguments": {}
  }
}
```

For a complete machine report, call `machine_status` with empty arguments:

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "machine_status",
    "arguments": {}
  }
}
```

The MCP route is stateless, so callers do not need to send `Mcp-Session-Id`.

## Docker

Start or rebuild the full stack:

```bash
./deploy.sh
```

Validate Compose wiring without starting containers:

```bash
docker compose config
```

Stop this Compose project:

```bash
./shutdown.sh
```

Remove this project’s Compose services, anonymous volumes, and locally built images:

```bash
./cleanup-project.sh
```

Global Docker cleanup is intentionally separate and requires an explicit flag:

```bash
./cleanup-docker-global.sh --force
```

## Shell Scripts

Run these from the repository root.

| Script | Usage | What it does |
| --- | --- | --- |
| `bootstrap-submodules.sh` | `./bootstrap-submodules.sh` | Syncs and initializes Git submodules when `.gitmodules` exists. If a service checkout is missing, it clones `sysmind-ui`, `sysmind-mcp`, and `sysmind-agent` from GitHub. If a service directory exists but is not a Git checkout, it stops and asks you to move it aside or clone manually. |
| `deploy.sh` | `./deploy.sh` | Ensures Docker is running, starts Docker Desktop on macOS when needed, runs `bootstrap-submodules.sh`, then rebuilds and starts the Compose stack with `docker compose up -d --build`. |
| `shutdown.sh` | `./shutdown.sh` | Ensures Docker is running, then stops this Compose project with `docker compose down --remove-orphans`. It leaves named volumes and locally built images in place. |
| `cleanup-project.sh` | `./cleanup-project.sh` | Ensures Docker is running, then removes this project’s Compose services, networks, anonymous volumes, orphan containers, and locally built images with `docker compose down --volumes --rmi local --remove-orphans`. It is scoped to this Compose project. |
| `cleanup-docker-global.sh` | `./cleanup-docker-global.sh --force` | Requires `--force`. Stops and removes every Docker container on the machine, then prunes unused images, networks, and volumes with `docker system prune -af --volumes`. Use only when you want machine-wide Docker cleanup. |

The Docker scripts use `open -a Docker` when Docker is not running, so they are tuned for macOS with Docker Desktop. On other platforms, start Docker manually before running them.

## Local Development

Backend:

```bash
cd sysmind-mcp
./mvnw spring-boot:run
```

Frontend:

```bash
cd sysmind-ui
npm ci
npm run dev
```

Agent:

```bash
cd sysmind-agent
./mvnw spring-boot:run
```

iOS:

```bash
cd sysmind-ios
open SysMindIOS.xcodeproj
```

Run the `SysMindIOS` target in Xcode. The iOS app uses a Clean Architecture layout with `App`, `Presentation`, `Domain`, and `Data` folders. Its root screen is `ChatView`, backed by `ChatViewModel`.

If Next reports another dev server is already running, stop the old process before restarting:

```bash
pkill -f "next dev"
```

## Verification

```bash
cd sysmind-mcp && ./mvnw test
cd ../sysmind-agent && ./mvnw test
cd ../sysmind-ui && npm run lint && npm run build
```
