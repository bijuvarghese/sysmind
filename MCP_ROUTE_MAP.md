# SysMind MCP Route Map

Goal: turn `sysmind-mcp` from an MCP-style REST agent backend into a real Model Context Protocol server that MCP clients can discover, initialize, list tools from, and call tools through.

## Current State

`sysmind-mcp` currently exposes a custom REST API:

- `POST /agent` accepts a user prompt, asks the LLM to select a local tool, executes it, then asks the LLM to write the final answer.
- `GET /v1/models` proxies the configured OpenAI-compatible model list.
- Tool implementations already exist behind `SystemTool`: `disk_usage`, `ram_usage`, `latest_news`, and `chroma_status`.

This is useful agent behavior, but it is not MCP-compliant yet because MCP clients expect JSON-RPC protocol methods such as `initialize`, `tools/list`, and `tools/call` over an MCP transport.

## Target Shape

Use Spring AI MCP server support instead of hand-rolling the protocol unless a blocker appears.

Primary target:

- Spring Boot WebFlux server
- Spring AI `spring-ai-starter-mcp-server-webflux`
- Streamable HTTP transport
- Single MCP endpoint: `/mcp`
- Existing REST endpoints preserved during migration

Optional later target:

- Stdio transport for local desktop clients that prefer launching MCP servers as child processes.

## Route Map

| Surface | Route or Method | Purpose | Status |
| --- | --- | --- | --- |
| Legacy REST | `POST /agent` | Existing prompt-to-agent endpoint for SysMind UI | Keep during migration |
| Legacy REST | `GET /v1/models` | Existing model proxy for SysMind UI | Keep during migration |
| MCP HTTP | `POST /mcp` | Receives JSON-RPC MCP requests and notifications | Add |
| MCP HTTP | `GET /mcp` | Optional server-to-client stream for Streamable HTTP | Add if needed by starter |
| MCP HTTP | `DELETE /mcp` | Optional session termination | Add if stateful sessions are enabled |
| MCP JSON-RPC | `initialize` | Protocol and capability negotiation | Add |
| MCP JSON-RPC | `notifications/initialized` | Client initialization notification | Add |
| MCP JSON-RPC | `ping` | Basic health/liveness protocol method | Add |
| MCP JSON-RPC | `tools/list` | Expose SysMind tools to MCP clients | Add |
| MCP JSON-RPC | `tools/call` | Execute one SysMind tool by name with JSON arguments | Add |
| MCP JSON-RPC | `resources/list`, `resources/read` | Future Chroma or project context resources | Later |
| MCP JSON-RPC | `prompts/list`, `prompts/get` | Future reusable prompt templates | Later |

## Phase 1: Protocol Foundation

1. Add Spring AI MCP dependency management and the WebFlux MCP server starter.
2. Configure the MCP server:
   - `spring.ai.mcp.server.name=sysmind-mcp`
   - `spring.ai.mcp.server.version=1.0.0`
   - `spring.ai.mcp.server.protocol=STREAMABLE`
   - endpoint path `/mcp`, if the starter exposes a path property in the chosen version.
3. Keep `spring-boot-starter-webflux`; do not switch the app to MVC.
4. Decide whether sessions are stateful or stateless:
   - Prefer stateless Streamable HTTP first for simpler local use.
   - Move to stateful sessions only if a target client requires resumable streams or server-to-client notifications.

Deliverable: app starts with a real MCP endpoint and answers `initialize`.

## Phase 2: Tool Adapter Layer

Create an adapter that maps existing `SystemTool` implementations into MCP tools.

Required mapping:

| Existing Tool | MCP Tool Name | Arguments Schema | Result Shape |
| --- | --- | --- | --- |
| `DiskTool` | `disk_usage` | `{}` | Text or structured JSON with total/free/used |
| `RamTool` | `ram_usage` | `{}` | Text or structured JSON with total/free/used |
| `NewsTool` | `latest_news` | `query`, `language`, `country`, `ceid` optional strings | Text summary or structured article list |
| `ChromaStatusTool` | `chroma_status` | `{}` | Text or structured JSON with health/version/config |

Implementation notes:

- Preserve the existing `SystemTool` interface initially.
- Add typed argument DTOs where tools accept input, especially `latest_news`.
- Return MCP tool results directly from the tool call; do not route MCP tool calls through the LLM.
- Keep the old `MCPRouter` only for `POST /agent`, because it is an agent orchestration layer, not the MCP protocol layer.

Deliverable: `tools/list` returns all SysMind tools, and `tools/call` executes each one.

## Phase 3: Response Quality and Schemas

1. Define clear JSON schemas for every tool.
2. Normalize tool outputs:
   - Prefer structured content where clients can use it.
   - Include readable text content for broad client compatibility.
3. Add stable error responses:
   - Unknown tool
   - Invalid arguments
   - Upstream news fetch failure
   - Chroma unavailable
4. Ensure logs go to stderr or application logs, never to an MCP transport stream as non-protocol output.

Deliverable: tools are predictable enough for Claude Desktop, Cursor, Codex, and other MCP clients to use.

## Phase 4: Client Configuration and Docker

1. Update Docker and nginx routing:
   - Proxy `/mcp` to `sysmind-mcp:8080`.
   - Preserve `/agent` for SysMind UI.
2. Add example client configs:
   - Streamable HTTP client config pointing to `http://localhost/mcp` or `http://localhost:8080/mcp`.
   - Optional stdio config if stdio support is added.
3. Add security defaults for local HTTP:
   - Bind local dev to localhost where possible.
   - Validate `Origin` for Streamable HTTP when exposed through a browser-capable surface.
   - Avoid exposing host system tools on public interfaces without auth.

Deliverable: documented instructions for connecting a real MCP client.

## Phase 5: Verification

Automated checks:

- Unit tests for every tool adapter.
- Integration test for `initialize`.
- Integration test for `tools/list`.
- Integration test for `tools/call` for each tool.
- Regression tests for existing `POST /agent` and `GET /v1/models`.

Manual checks:

- Start backend locally.
- Connect with an MCP inspector/client.
- Confirm the client lists `disk_usage`, `ram_usage`, `latest_news`, and `chroma_status`.
- Call each tool from the client.
- Confirm SysMind UI still works through `/agent`.

Suggested verification commands:

```bash
cd sysmind-mcp
./mvnw test
./mvnw spring-boot:run
```

## Acceptance Criteria

The migration is done when:

- An MCP client can connect to `/mcp`.
- The server successfully completes MCP initialization.
- `tools/list` returns the SysMind tools with names, descriptions, and schemas.
- `tools/call` executes the tools without requiring an LLM planning step.
- Existing SysMind UI behavior still works.
- Docker/nginx exposes the MCP endpoint intentionally.
- README docs clearly distinguish the legacy REST agent API from the MCP server API.

## Recommended First Pull Request

Keep the first PR small:

1. Add Spring AI MCP WebFlux server dependency and configuration.
2. Expose a minimal `ping` or no-op tool through real MCP.
3. Add one integration test proving initialization and `tools/list`.
4. Update README with the new `/mcp` endpoint.

After that lands, migrate the real tools one at a time.

## References

- MCP transport specification: https://modelcontextprotocol.io/specification/2025-06-18/basic/transports
- Spring AI MCP overview: https://docs.spring.io/spring-ai/reference/api/mcp/mcp-overview.html
