# AGENTS.md

## Repo Layout

- `sysmind-ui`: Next.js 16 frontend.
- `sysmind-mcp`: Spring Boot 4 MCP backend.

## Working Commands

### Repository root

- Initialize service submodules after clone: `./bootstrap-submodules.sh`
- Rebuild and start the full Docker stack: `./deploy.sh`
- Stop the Compose stack: `./shutdown.sh`
- Remove this project’s Compose services, anonymous volumes, and local images: `./cleanup-project.sh`
- Run global Docker cleanup only with explicit confirmation: `./cleanup-docker-global.sh --force`

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
- MCP service reads `LLM_URL`, defaulting to `http://localhost:1234`.
- Default local flow: run `sysmind-mcp` on `:8080`, run `sysmind-ui` on `:3000`, and ensure the LLM endpoint is reachable at `LLM_URL`.
- `deploy.sh` runs `./bootstrap-submodules.sh` before `docker compose up -d --build`.

## Container Commands

- UI Docker image build runs `npm ci` and `npm run build`.
- MCP Docker image build runs `./mvnw dependency:go-offline` and `./mvnw clean package -DskipTests`.
