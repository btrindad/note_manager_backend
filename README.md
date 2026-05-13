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
