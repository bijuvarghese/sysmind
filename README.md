# SysMind

SysMind is a two-service local MCP workspace:

- `sysmind-ui`: Next.js 16 chat UI.
- `sysmind-mcp`: Spring Boot 4 stateless MCP tool server.

The usual local stack is:

- MCP backend on `http://localhost:8080`
- Stateless MCP endpoint on `http://localhost:8080/mcp`
- UI on `http://localhost:3000`

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

Important values:

```env
CHROMA_URL=http://chroma:8000
CHROMA_TIMEOUT=5s
CHROMA_TENANT=default_tenant
CHROMA_DATABASE=default_database
CHROMA_COLLECTION=sysmind
NEWS_LANGUAGE=en-US
NEWS_COUNTRY=US
NEWS_CEID=
MCP_BACKEND_URL=http://sysmind-mcp:8080
SPRING_PROFILES_ACTIVE=docker
NGINX_PORT=80
```

The Docker stack also starts Chroma at `http://chroma:8000` for vector storage. The first MCP integration exposes a `chroma_status` tool so clients can verify connectivity before retrieval features are added.

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

Call a tool:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "disk_usage",
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

If Next reports another dev server is already running, stop the old process before restarting:

```bash
pkill -f "next dev"
```

## Verification

```bash
cd sysmind-mcp && ./mvnw test
cd ../sysmind-ui && npm run lint && npm run build
```
