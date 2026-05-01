# SysMind

SysMind is a two-service local agent workspace:

- `sysmind-ui`: Next.js 16 chat UI.
- `sysmind-mcp`: Spring Boot 4 MCP-style backend that routes prompts to system tools or an OpenAI-compatible local LLM endpoint.

The usual local stack is:

- MCP backend on `http://localhost:8080`
- UI on `http://localhost:3000`
- LLM endpoint at `LLM_URL`

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
LLM_URL=http://host.docker.internal:1234
LLM_TIMEOUT=3m
NEWS_LANGUAGE=en-US
NEWS_COUNTRY=US
NEWS_CEID=
NEWS_FEED_URL=https://news.google.com/rss?hl={language}&gl={country}&ceid={ceid}
NEWS_LOCATION_FEED_URL_TEMPLATE=https://news.google.com/rss/search?q={query}&hl={language}&gl={country}&ceid={ceid}
MCP_BACKEND_URL=http://sysmind-mcp:8080
SPRING_PROFILES_ACTIVE=docker
NGINX_PORT=80
```

News URL templates support `{query}`, `{language}`/`{hl}`, `{country}`/`{gl}`, `{languageCode}`, and `{ceid}`. If `NEWS_CEID` is empty, the backend derives it from `NEWS_COUNTRY` and `NEWS_LANGUAGE`, for example `US:en`.

For direct local JVM runs of `sysmind-mcp`, set `LLM_URL` to `http://localhost:1234` if the LLM is running on the same host.

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
