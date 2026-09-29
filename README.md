# docker-project

A simple FastAPI application to illustrate some cool docker features

## `docker init`

- scaffold: Dockerfile, ignore, compose

## `docker cp`

- copy from stopped containers

## `docker diff`

- see filesystem changes

## `docker events`

- trace what Docker is doing, this is a listener. Yo can apply filters with --filter flag

## `docker top` + `docker update`

- live resource limits

## `docker system df`

- where storage goes: `docker system df -v`

## `docker compose alpha`

generate, publish, run over OCI

- `docker compose alpha generate test-app > test.yaml`

## Bonus: `buildx` and BuildKit

- `docker buildx history ls` > history of builds
- `docker buildx history trace` > building graphs

- hidden web UI (Jaeger)
