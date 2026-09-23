APP ?= main:app
HOST ?= 0.0.0.0
PORT ?= 5001
IMAGE ?= test-app
BASE_URL ?= http://localhost:$(PORT)

.PHONY: dev docker-build docker-run compose-up compose-down compose-logs \
	curl-root curl-health curl-item-default curl-item-quantity \
	curl-item-invalid smoke

dev:
	uv run uvicorn $(APP) --host $(HOST) --port $(PORT) --reload

docker-build:
	docker build -t $(IMAGE) .

docker-run: docker-build
	secretspec run --provider pass --profile development -- \
	docker run --rm -p $(PORT):5001 \
		-e DATABASE_URL -e SECRETSPEC_PROVIDER=env $(IMAGE)

compose-up:
	secretspec run --provider pass --profile development -- \
		docker compose up --build

compose-down:
	docker compose down

compose-logs:
	docker compose logs -f

# Expected: {"message": "<your DATABASE_URL value>"}
curl-root:
	curl -i "$(BASE_URL)/"

# Expected: {"status": "ok"}
curl-health:
	curl -i "$(BASE_URL)/health"

# Create with default quantity
curl-item-default:
	curl -i -X POST "$(BASE_URL)/items" \
		-H "Content-Type: application/json" \
		-d '{"name": "apple"}'

# Expected HTTP 200: {"name": "banana", "status": "created"}
curl-item-quantity:
	curl -i -X POST "$(BASE_URL)/items" \
		-H "Content-Type: application/json" \
		-d '{"name": "banana", "quantity": 5}'

# Expected HTTP 400: {"detail": "quantity must be >= 1"}
curl-item-invalid:
	curl -i -X POST "$(BASE_URL)/items" \
		-H "Content-Type: application/json" \
		-d '{"name": "bad", "quantity": 0}'

# Print status codes; this does not assert expected responses
smoke:
	@for endpoint in "/" "/health"; do \
		curl -sS -o /dev/null \
			-w "GET $${endpoint} -> %{http_code}\n" \
			"$(BASE_URL)$${endpoint}" || exit $$?; \
	done
	@curl -sS -o /dev/null -w "POST /items -> %{http_code}\n" \
		-X POST "$(BASE_URL)/items" \
		-H "Content-Type: application/json" \
		-d '{"name": "smoke-test", "quantity": 1}'
