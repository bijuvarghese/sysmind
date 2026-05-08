# SysMind Agent Layer Plan

## Goal

Create a separate Spring Boot agent service that sits between `sysmind-ui`, LM Studio, and `sysmind-mcp`.

The agent layer owns reasoning, model calls, MCP tool orchestration, memory, streaming, and observability. The UI remains a chat interface, and the MCP service remains a focused tool server.

## Target Architecture

```text
sysmind-ui
  -> sysmind-agent
      -> LM Studio
      -> sysmind-mcp
      -> Chroma
```

## Service Responsibilities

| Service | Responsibility |
| --- | --- |
| `sysmind-ui` | Render chat, stream agent events, show tool activity, manage user interaction. |
| `sysmind-agent` | Run the agent loop, call LM Studio, choose tools, call MCP tools, manage memory, stream responses. |
| `sysmind-mcp` | Expose read-only MCP tools through `/mcp`. |
| `chroma` | Store vector data for future retrieval features. |
| LM Studio | Run local models through an OpenAI-compatible API. |

## Recommended Agent Stack

| Concern | Choice |
| --- | --- |
| Language | Java 25 |
| Framework | Spring Boot 4 |
| Web stack | Spring WebFlux |
| Build | Maven |
| LLM integration | Spring AI OpenAI-compatible client or direct WebClient to LM Studio |
| MCP integration | WebClient JSON-RPC client |
| Streaming | WebFlux `Flux<ServerSentEvent<?>>` |
| Validation | Spring Validation / Jakarta Validation |
| Health | Spring Boot Actuator |
| Memory v1 | In-memory session history |
| Memory v2 | SQLite, PostgreSQL, or another persistent store |
| Deployment | Docker Compose |

## Repository Shape

```text
sysmind/
  sysmind-ui/
  sysmind-mcp/
  sysmind-agent/
    pom.xml
    src/main/java/com/bxv/sysmindagent/
      SysMindAgentApplication.java
      api/
      agent/
      config/
      lmstudio/
      mcp/
      memory/
      model/
```

## Initial Endpoints

```text
POST /api/chat
GET  /api/tools
GET  /actuator/health
```

Add streaming after the first non-streaming agent loop is stable:

```text
POST /api/chat/stream
```

## Configuration

Local development:

```env
SERVER_PORT=4000
LM_STUDIO_BASE_URL=http://localhost:1234/v1
LM_STUDIO_API_KEY=lm-studio
LM_STUDIO_MODEL=your-model-name
MCP_BACKEND_URL=http://localhost:8080
MCP_ENDPOINT=/mcp
CHROMA_URL=http://localhost:8000
```

Docker Compose:

```env
SERVER_PORT=4000
LM_STUDIO_BASE_URL=http://host.docker.internal:1234/v1
LM_STUDIO_API_KEY=lm-studio
LM_STUDIO_MODEL=your-model-name
MCP_BACKEND_URL=http://sysmind-mcp:8080
MCP_ENDPOINT=/mcp
CHROMA_URL=http://chroma:8000
```

## Implementation Steps

### 1. Scaffold `sysmind-agent`

Create a new Maven Spring Boot service under `sysmind-agent`.

Include dependencies for:

- Spring Boot WebFlux
- Spring Boot Validation
- Spring Boot Actuator
- Spring AI OpenAI support, if compatible with the chosen LM Studio endpoint
- Jackson
- Reactor Test
- Spring Boot Test

### 2. Add Agent Configuration

Create configuration properties for:

- LM Studio base URL
- LM Studio API key
- LM Studio model
- MCP backend URL
- MCP endpoint path
- Tool timeout
- Agent timeout
- Max tool calls per user request

Suggested defaults:

```text
toolTimeout=10s
agentTimeout=60s
maxToolCalls=3
```

### 3. Build The MCP Client

Create a WebClient-based JSON-RPC client for `sysmind-mcp`.

Support:

- `initialize`
- `tools/list`
- `tools/call`

Target:

```text
POST ${MCP_BACKEND_URL}${MCP_ENDPOINT}
```

Cache tool definitions from `tools/list` for the first version.

### 4. Build The LM Studio Client

Connect to LM Studio through its OpenAI-compatible API.

Start with:

```text
POST /v1/chat/completions
```

Use non-streaming responses first. Add streaming once tool orchestration works.

### 5. Define Internal Models

Create models for:

- `ChatRequest`
- `ChatResponse`
- `ChatMessage`
- `ChatEvent`
- `ToolDefinition`
- `ToolCall`
- `ToolResult`
- `AgentStep`
- `JsonRpcRequest`
- `JsonRpcResponse`

### 6. Implement The First Agent Loop

Initial flow:

```text
Receive user message
Load available MCP tools
Send user message and tool descriptions to LM Studio
Parse model response
If a tool is requested, call sysmind-mcp
Send tool result back to LM Studio
Return final answer to sysmind-ui
```

Use a simple structured model response for tool decisions:

```json
{
  "type": "tool_call",
  "toolName": "machine_status",
  "arguments": {}
}
```

Final responses should use:

```json
{
  "type": "final",
  "answer": "Your machine looks healthy."
}
```

### 7. Add Tool Execution Guardrails

Before executing a tool:

- Verify the tool exists in the cached MCP registry.
- Validate arguments are valid JSON.
- Enforce max tool-call count.
- Enforce per-tool timeout.
- Log tool start, success, failure, and duration.
- Return graceful errors to the model and user.

### 8. Connect `sysmind-ui` To `sysmind-agent`

Change the UI flow from:

```text
sysmind-ui -> sysmind-mcp
```

to:

```text
sysmind-ui -> sysmind-agent -> sysmind-mcp
```

Add:

```env
AGENT_BACKEND_URL=http://localhost:4000
```

Docker value:

```env
AGENT_BACKEND_URL=http://sysmind-agent:4000
```

### 9. Add Streaming

Add a streaming chat endpoint using WebFlux server-sent events.

Status: complete. `sysmind-agent` exposes `POST /api/chat/stream`, and `sysmind-ui` consumes it through `/api/tool-call/stream`.

Stream event types:

- `message.started`
- `tool.started`
- `tool.finished`
- `message.delta`
- `message.finished`
- `error`

### 10. Add Memory

Start with in-memory session history.

Later add persistent storage for:

- Conversations
- Messages
- Tool calls
- Model metadata
- Latency and error details

### 11. Add Docker Compose Wiring

Add `sysmind-agent` to the root Compose stack.

It should depend on:

- `sysmind-mcp`
- `chroma`

LM Studio usually runs on the host machine, so Docker should use:

```text
http://host.docker.internal:1234/v1
```

### 12. Add Tests

Minimum tests:

- MCP client parses `tools/list`.
- MCP client calls `tools/call`.
- Agent returns a final answer when no tool is needed.
- Agent calls `machine_status` for machine health questions.
- Agent handles MCP failures gracefully.
- Agent stops when max tool calls are reached.

### 13. Add Observability

Add:

- Actuator health endpoint
- Structured logs
- Request IDs
- Tool-call logs
- Model latency logs
- Agent latency logs

Useful log fields:

```text
sessionId
model
toolName
toolDurationMs
agentDurationMs
finishReason
errorType
```

## Milestones

### Milestone 1: Agent Skeleton

- Create `sysmind-agent`.
- Add config.
- Add health endpoint.
- Add Dockerfile.
- Add Compose entry.

### Milestone 2: MCP Client

- Implement `tools/list`.
- Implement `tools/call`.
- Add tests with mocked MCP responses.

### Milestone 3: LM Studio Client

- Connect to LM Studio.
- Send a basic chat request.
- Return a non-streaming model response.

### Milestone 4: First Agent Loop

- Load tools.
- Let model request a tool.
- Execute tool.
- Ask model for final response.
- Return final response to UI.

### Milestone 5: UI Integration

- Point `sysmind-ui` to `sysmind-agent`.
- Replace direct tool-call flow with agent chat flow.
- Show final answers in existing message list.

### Milestone 6: Streaming And Tool Events

- Add SSE endpoint.
- Stream message and tool lifecycle events.
- Show tool progress in the UI.

### Milestone 7: Memory And Hardening

- Add session memory.
- Add persistent memory if needed.
- Add retries, timeouts, request IDs, and structured logs.

## First End-To-End Success Case

The first complete workflow should be:

```text
User asks: "How is my machine doing?"
sysmind-ui sends the message to sysmind-agent.
sysmind-agent asks LM Studio what to do.
LM Studio requests the machine_status tool.
sysmind-agent calls sysmind-mcp tools/call with machine_status.
sysmind-agent sends the tool result back to LM Studio.
LM Studio writes a concise health summary.
sysmind-agent returns the answer to sysmind-ui.
```
