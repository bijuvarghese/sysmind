# AGENTS.md

## Repo Layout

- `sysmind-ui`: Next.js 16 frontend.
- `sysmind-mcp`: Spring Boot 4 MCP backend.

## Working Commands

### Repository root

- Initialize service submodules after clone: `./bootstrap-submodules.sh`
- Create local environment file from the sample: `cp .env.example .env`
- Rebuild and start the full Docker stack: `./deploy.sh`
- Stop the Compose stack: `./shutdown.sh`
- Remove this project’s Compose services, anonymous volumes, and local images: `./cleanup-project.sh`
- Run global Docker cleanup only with explicit confirmation: `./cleanup-docker-global.sh --force`
- Run the standard verification pass: `cd sysmind-mcp && ./mvnw test && cd ../sysmind-ui && npm run lint && npm run build`

### `sysmind-ui`

- Install deps: `npm ci`
- Start dev server: `npm run dev`
- Build production bundle: `npm run build`
- Start production server: `npm run start`
- Run lint: `npm run lint`

### `sysmind-mcp`

- Start locally: `./mvnw spring-boot:run`
- Run tests: `./mvnw test`
- Build jar: `./mvnw clean package`

## Local Integration Notes

- UI routes in `sysmind-ui/app/api/*` proxy to `MCP_BACKEND_URL`, defaulting to `http://localhost:8080`.
- Real MCP clients call the stateless JSON-RPC endpoint at `POST /mcp`; no `Mcp-Session-Id` header is required.
- Default local flow: run `sysmind-mcp` on `:8080` and run `sysmind-ui` on `:3000`.
- `deploy.sh` runs `./bootstrap-submodules.sh` before `docker compose up -d --build`.
- `bootstrap-submodules.sh` first syncs/init submodules when `.gitmodules` exists, then clones missing `sysmind-ui` and `sysmind-mcp` checkouts; it exits if either target directory is non-empty but not a Git checkout.
- `deploy.sh`, `shutdown.sh`, and `cleanup-project.sh` wait for Docker Desktop to come up if `docker info` is not yet available.
- The root Compose stack exposes only nginx on `${NGINX_PORT:-80}`; `sysmind-ui` and `sysmind-mcp` stay on the internal Compose network.

## Container Commands

- UI Docker image build runs `npm ci` and `npm run build`.
- MCP Docker image build runs `./mvnw dependency:go-offline` and `./mvnw clean package -DskipTests`.
