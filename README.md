# docker-project

A simple FastAPI application.

## Running locally

```bash
# Install dependencies
uv sync

# Start the dev server
uv run uvicorn main:app --reload --host 0.0.0.0 --port 5001
```

The API will be available at `http://localhost:5001`.
Interactive docs (Swagger UI) are at `http://localhost:5001/docs`.

## Testing the API with curl

> Assumes the server is running on `http://localhost:5001`.
> If you started the container with a different host port mapping
> (e.g. `docker run -p 8080:5001 ...`), replace `5001` accordingly.

### Root — `GET /`

Returns the loaded `DATABASE_URL` from `secret_setter`.

```bash
curl -i http://localhost:5001/
```

Expected response:

```json
{ "message": "<your DATABASE_URL value>" }
```

### Health check — `GET /health`

```bash
curl -i http://localhost:5001/health
```

Expected response:

```json
{ "status": "ok" }
```

### Create item — `POST /items`

Body schema:

| Field      | Type   | Required | Default | Constraints     |
| ---------- | ------ | -------- | ------- | --------------- |
| `name`     | string | yes      | —       | —               |
| `quantity` | int    | no       | `1`     | must be `>= 1`  |

**Create with default quantity:**

```bash
curl -i -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name": "apple"}'
```

**Create with explicit quantity:**

```bash
curl -i -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name": "banana", "quantity": 5}'
```

Expected response (HTTP `200`):

```json
{ "name": "banana", "status": "created" }
```

**Validation failure (quantity `< 1`):**

```bash
curl -i -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name": "bad", "quantity": 0}'
```

Expected response (HTTP `400`):

```json
{ "detail": "quantity must be >= 1" }
```

### One-liner smoke test

Hit all three endpoints in sequence and print only the HTTP status codes:

```bash
for endpoint in "/" "/health"; do
  curl -s -o /dev/null -w "GET ${endpoint} -> %{http_code}\n" \
    "http://localhost:5001${endpoint}"
done

curl -s -o /dev/null -w "POST /items -> %{http_code}\n" \
  -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name": "smoke-test", "quantity": 1}'
```

Expected output:

```
GET / -> 200
GET /health -> 200
POST /items -> 200
```
