# NoteManager

This acts as the backend API for the Note Management project. This project is the final for CSCI 6421 in Spring 2026 at GWU.

## How to Run

The easiest way to run this just to interact with it is with Docker.

```
docker compose -f docker-compose.production.yml up -d
```

This will take care of pretty much everything, and it will take a while the first time. It will first pull the base images, build the
application, save that application as a local image, stand up and provision the database, and finally launch the application.

Docker will be listening on port 4000 on your localhost. To view the API Specification visit the URL [http://localhost:4000/api/json/swaggerui].

The available routes are also shown below for your reference.

```
 *       /api/json/swaggerui         OpenApiSpex.Plug.SwaggerUI [path: "/api/json/open_api", default_model_expand_depth: 4]
 GET     /api/json/notes/:id         NoteManagerWeb.AshJsonApiRouter NoteManager.KnowledgeBase.Note.read
 POST    /api/json/notes             NoteManagerWeb.AshJsonApiRouter NoteManager.KnowledgeBase.Note.create
 DELETE  /api/json/notes/:id         NoteManagerWeb.AshJsonApiRouter NoteManager.KnowledgeBase.Note.destroy
 GET     /api/json/notes/search      NoteManagerWeb.AshJsonApiRouter NoteManager.KnowledgeBase.Note.search
 WS      /live/websocket             Phoenix.LiveView.Socket
 GET     /live/longpoll              Phoenix.LiveView.Socket
 POST    /live/longpoll              Phoenix.LiveView.Socket
```

## Utilities

### Loading Sample Data

#### Single-Node (Development)

For quick testing on a single node, you can load Wikipedia data interactively:

```bash
iex -S mix
```

Then in the iex prompt:

```elixir
NoteManager.Demo.SampleGenerator.save_notes(20)
```

**Note:** This will block the node while fetching and inserting Wikipedia pages. The node will not respond to client requests during this time.

#### Multi-Node (Production-like / Demonstration)

To load data without blocking API traffic, use the dedicated `seed.load_notes` Mix task on a separate node:

**Setup:** Start a 3-node cluster with nginx load balancer:

```bash
docker compose -f docker-compose.cluster.yml up -d --scale api=3
```

**In Terminal 1:** Monitor the cluster:

```bash
watch -n 1 './demo/cluster_status.sh'
```

**In Terminal 2:** Load data on a dedicated seed node (does not serve API traffic):

```bash
docker compose -f docker-compose.cluster.yml run --rm api mix seed.load_notes 50
```

**In Terminal 3:** Generate HTTP traffic to verify API remains responsive:

```bash
./demo/traffic.sh
```

**What you'll see:**

- Terminal 1: All 3 nodes remain healthy and connected.
- Terminal 2: Notes are being fetched from Wikipedia and inserted (progress shown).
- Terminal 3: HTTP requests complete successfully (ok count keeps rising), **even while seeding**.

This demonstrates that your distributed system handles long-running background tasks without impacting client requests.

**Options for seed.load_notes:**

```bash
# Load 20 notes (default)
mix seed.load_notes

# Load 50 notes
mix seed.load_notes 50

# Load with custom batch size
mix seed.load_notes 100 --batch-size 5

# Local multi-node example (if running nodes with iex)
RELEASE_NODE="note_manager@127.0.0.1" iex -S mix seed.load_notes 30
```

### Why This Matters

In a single-node setup, long-running tasks (like `save_notes(20)`) block the entire application, making it unresponsive to clients. In a multi-node cluster:

- **Node A**: Runs API server, handles client requests (responsive).
- **Node B**: Runs seed/batch task, generates and inserts data (independent).
- **nginx**: Routes requests to healthy nodes, transparently failover if one dies.

Result: Users never notice background tasks. Your system stays live.
