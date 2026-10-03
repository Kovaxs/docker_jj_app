# Docker cheat sheet & FastAPI playground

**Build it. Run it. See what happened. Keep the data.**

An everyday Docker reference with a small FastAPI app, plus the less-obvious tools: `init`, `cp`, `diff`, `events`, `top`, `update`, storage inspection, Compose generation and OCI publishing, Buildx history, and Jaeger traces.

Checked on **2026-10-03** against the installed CLI: **Docker 28.5.1**, **Compose v2.40.2-desktop.1**, **Buildx v0.29.1-desktop.1**, and official documentation. Compose configuration and Python syntax were validated. **Live builds and container execution were not tested:** the authoring session could not access the Docker daemon.

Examples target Linux containers, including Docker Desktop on macOS. Run commands from this folder. Recipes are independent; do not paste the whole README into a shell. Registry examples require your own account and publish only when you run them.

## Contents

- [The mental model](#the-mental-model)
- [Run the playground](#run-the-playground)
- [Everyday command card](#everyday-command-card)
- [Scaffold with docker init](#scaffold-with-docker-init)
- [Build and rebuild](#build-and-rebuild)
- [Run, stop, restart, recreate](#run-stop-restart-recreate)
- [Inspect and troubleshoot](#inspect-and-troubleshoot)
- [Copy files from stopped containers](#copy-files-from-stopped-containers)
- [See filesystem changes](#see-filesystem-changes)
- [Listen to Docker events](#listen-to-docker-events)
- [Processes and live resource limits](#processes-and-live-resource-limits)
- [Networking without guesswork](#networking-without-guesswork)
- [Volumes, persistence, and backups](#volumes-persistence-and-backups)
- [Find and reclaim disk space](#find-and-reclaim-disk-space)
- [Compose tricks and live development](#compose-tricks-and-live-development)
- [Generate Compose from existing containers](#generate-compose-from-existing-containers)
- [Publish images and Compose over OCI](#publish-images-and-compose-over-oci)
- [Buildx, BuildKit, and build traces](#buildx-buildkit-and-build-traces)
- [Cool tricks](#cool-tricks)
- [Troubleshooting card](#troubleshooting-card)

## The mental model

| Object          | What it is                                                 | Lifetime                             |
| --------------- | ---------------------------------------------------------- | ------------------------------------ |
| Image           | Read-only filesystem layers and launch configuration       | Until you remove the image           |
| Container       | An instance of an image, with a process and writable layer | Survives stop/start; removed by `rm` |
| Named volume    | Docker-managed persistent data                             | Usually survives container removal   |
| Bind mount      | A host path made available inside a container              | Data lives on the host               |
| Network         | Connectivity and service-name discovery                    | Managed independently or by Compose  |
| Build cache     | Reusable results of build steps                            | Can be reclaimed separately          |
| Compose project | A declared group of services, networks, and volumes        | Managed with `docker compose`        |

```text
Source + Dockerfile ── build ──> Image ── run ──> Container
                                                    │
                                              mount a volume
                                                    │
                                             Persistent data
```

An image tag is a movable name. A digest identifies specific content. Editing a container does not edit its image; rebuilding an image does not automatically replace running containers.

## Run the playground

Included files:

```text
.
├── app/main.py             # FastAPI endpoints
├── requirements.txt
├── Dockerfile              # Multi-stage build, cache mount, non-root runtime
├── .dockerignore
├── compose.yaml            # Local app, healthcheck, volume, resource limits
├── compose.watch.yaml      # Optional source synchronization and reload
└── compose.publish.yaml    # Image-only definition for OCI publishing
```

```bash
docker compose config --quiet
docker compose up --build --wait
curl http://localhost:8000/
curl http://localhost:8000/health
curl -X POST http://localhost:8000/visits
```

Open [the interactive API docs](http://localhost:8000/docs). Every `POST /visits` increments `/data/visits.txt`, stored in a named volume.

Names throughout the guide:

| Name                      | Meaning                                       |
| ------------------------- | --------------------------------------------- |
| `api`                     | Compose service                               |
| `test-app`                | Container name, fixed for convenient examples |
| `docker-project:dev`      | Local image tag                               |
| `docker-project_app-data` | Named volume, with the default project name   |

The counter is a single-process teaching example, not a database. Dependencies use bounded ranges; lock exact versions and image digests when you need reproducible releases. If port 8000 is occupied, change the host port in Compose, for example to `127.0.0.1:8001:8000`.

## Everyday command card

| Intent                      | Single-container Docker              | Compose                                 |
| --------------------------- | ------------------------------------ | --------------------------------------- |
| List running containers     | `docker ps`                          | `docker compose ps`                     |
| Include stopped containers  | `docker ps -a`                       | `docker compose ps -a`                  |
| Follow recent logs          | `docker logs -f --tail 100 test-app` | `docker compose logs -f --tail 100 api` |
| Open a shell                | `docker exec -it test-app sh`        | `docker compose exec api sh`            |
| Stop gracefully             | `docker stop test-app`               | `docker compose stop`                   |
| Start existing containers   | `docker start test-app`              | `docker compose start`                  |
| Restart existing containers | `docker restart test-app`            | `docker compose restart api`            |
| Build and apply the app     | Build, then create a new container   | `docker compose up -d --build`          |
| Remove a stopped container  | `docker rm test-app`                 | `docker compose down`                   |
| Usage snapshot              | `docker stats --no-stream test-app`  | `docker compose stats --no-stream`      |

Compose commands take **service names** such as `api`; container commands take names or IDs such as `test-app`.

## Scaffold with docker init

From an application directory that does not yet have Docker setup:

```bash
docker init
```

Docker Desktop's wizard can create `Dockerfile`, `.dockerignore`, `compose.yaml`, and `README.Docker.md`. Choose Python and provide the application's actual port and start command. For this app, the launch command is:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Review generated files before adopting them. This playground already includes its Docker setup, so you do not need to run `init` here. It can overwrite existing Docker files after prompting. [docker init](https://docs.docker.com/reference/cli/docker/init/)

## Build and rebuild

```bash
docker build -t docker-project:dev .
docker image ls
docker image history docker-project:dev

# Readable build output
docker build --progress=plain -t docker-project:dev .

# Refresh base-image tags and bypass cached build steps
docker build --pull --no-cache -t docker-project:dev .
```

The final `.` is the **build context**. `.dockerignore` keeps irrelevant or private files out of it. `--no-cache` alone does not fetch a newer base image; that is what `--pull` adds.

The sample copies requirements before application code, so code-only changes can reuse the dependency layer. A BuildKit cache mount reuses downloaded packages when dependency installation does run. Cache mounts may persist even with `--no-cache`. Multi-stage builds copy the installed environment into the runtime stage. [Cache optimization](https://docs.docker.com/build/cache/optimize/)

## Run, stop, restart, recreate

Use Compose for this project. To try a standalone equivalent instead, first stop the Compose app so the name and port are free:

```bash
docker compose down
docker run -d --name test-app \
  -p 127.0.0.1:8000:8000 \
  --mount type=volume,source=docker-project_app-data,target=/data \
  docker-project:dev
```

```bash
docker stop test-app
docker start test-app

# Remove this standalone container before returning to Compose
docker stop test-app
docker rm test-app
docker compose up -d
```

| Action                   | What it does                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------- |
| `restart`                | Restarts the same container; does not apply a rebuilt image or changed environment. |
| `up -d --build`          | Builds and recreates services when needed.                                          |
| `up -d --force-recreate` | Forces container replacement even if Compose sees no change.                        |
| `down`                   | Removes project containers and default networks; keeps named volumes by default.    |
| `run --rm`               | Creates a disposable container and removes it when it exits.                        |

`EXPOSE 8000` documents a port; `-p` or Compose `ports` makes it reachable from the host. The app must listen on `0.0.0.0` **inside** the container. Publishing on host `127.0.0.1` keeps this demo local.

## Inspect and troubleshoot

```bash
docker logs --since 10m --timestamps test-app
docker inspect test-app
docker inspect --format '{{json .State}}' test-app
docker inspect --format '{{json .Mounts}}' test-app
docker inspect --format '{{json .State.Health}}' test-app
docker port test-app
```

Run a diagnostic inside the existing container:

```bash
docker compose exec api python --version
docker compose exec api sh
```

Run a separate disposable container with the service's configuration:

```bash
docker compose run --rm --no-deps api python -c 'import fastapi; print(fastapi.__version__)'
```

`exec` needs a running container. `compose run` makes a new one, reusing configured mounts; it does not publish the service's ports by default. Use `exec -T` in scripts when you do not want a pseudo-terminal.

## Copy files from stopped containers

Create a diagnostic file, stop the container, then recover it:

```bash
docker exec test-app sh -c 'printf "diagnostic captured\n" > /tmp/report.txt'
docker stop test-app
mkdir -p recovered
docker cp test-app:/tmp/report.txt ./recovered/report.txt
docker start test-app
```

Copy a directory's **contents**, or copy back into a container:

```bash
docker cp test-app:/app/app/. ./recovered/
docker cp ./recovered/report.txt test-app:/tmp/report-copy.txt
```

`cp` works with running or stopped containers, as long as they still exist. It cannot recover files from an already removed `--rm` container. Destination parent directories must exist. Changes copied into the writable layer disappear when that container is replaced. [docker cp](https://docs.docker.com/reference/cli/docker/container/cp/)

## See filesystem changes

```bash
docker exec test-app sh -c 'printf "hello\n" > /tmp/demo.txt'
docker diff test-app
```

| Marker | Meaning                   |
| ------ | ------------------------- |
| `A`    | Added file or directory   |
| `C`    | Changed file or directory |
| `D`    | Deleted file or directory |

This inspects changes to the container's filesystem since creation. It is **not a line-by-line text diff**, and mounted volume/bind-mount contents are outside the writable-layer comparison. Use it to discover unexpected temporary files or edits, then use `docker cp` to inspect their contents. [docker diff](https://docs.docker.com/reference/cli/docker/container/diff/)

## Listen to Docker events

In one terminal:

```bash
docker events --filter container=test-app
```

In another, restart the app or change its limits. The listener reports lifecycle events until you stop it with `Ctrl+C`.

```bash
# Only exits and out-of-memory events for this container
docker events \
  --filter container=test-app \
  --filter event=die \
  --filter event=oom

# Bounded retrospective query, ending now
docker events --since 10m --until 0s --filter container=test-app

# Machine-readable live stream for this Compose project
docker events \
  --filter label=com.docker.compose.project=docker-project \
  --format '{{json .}}'
```

Repeated values for one filter key are ORed; different filter keys are ANDed. Events describe Docker activity, not application log messages. Historical retention is limited to the last 256 events, so this is not a durable audit log. [docker events](https://docs.docker.com/reference/cli/docker/system/events/)

## Processes and live resource limits

```bash
docker top test-app                 # Process list, not a live dashboard
docker stats test-app               # Live CPU, memory, network and I/O metrics
docker stats --no-stream test-app   # One sample

# Change CPU and memory limits on the existing Linux container
docker update --cpus 0.5 --memory 256m --memory-swap 512m test-app

docker inspect --format '{{json .HostConfig}}' test-app
```

`--cpus 0.5` caps available CPU time at roughly half a CPU. `--memory-swap 512m` means **memory plus swap**, not 512 MiB of swap alone, and swap availability depends on the host. Lowering memory too far can trigger an OOM kill.

`docker update` changes the container but not `compose.yaml`. To keep the limits after recreation, edit the service declaration:

```yaml
services:
  api:
    cpus: 0.5
    mem_limit: 256m
    memswap_limit: 512m
```

Then run `docker compose up -d`. Linux resource limits operate within Docker Desktop's VM limits; they cannot grant resources the VM does not have. [docker update](https://docs.docker.com/reference/cli/docker/container/update/)

## Networking without guesswork

```bash
docker network ls
docker network inspect docker-project_default
docker compose port api 8000
```

| Caller                                               | Address to use                                 |
| ---------------------------------------------------- | ---------------------------------------------- |
| Host browser/curl                                    | `http://localhost:8000` via the published port |
| Another service on this Compose network              | `http://api:8000`                              |
| Container calling a service on Docker Desktop's host | `host.docker.internal`                         |

Inside a container, `localhost` means that container. Do not hard-code container IP addresses. On native Linux, host access may require `--add-host host.docker.internal:host-gateway` or the equivalent Compose `extra_hosts` entry.

For a future database service, use its service name (for example `db:5432`). `depends_on` alone orders startup; use a dependency healthcheck and `condition: service_healthy` when the application needs readiness, plus application-level retries. [Startup ordering](https://docs.docker.com/compose/how-tos/startup-order/)

## Volumes, persistence, and backups

```bash
curl -X POST http://localhost:8000/visits
docker compose down
docker compose up --wait
curl -X POST http://localhost:8000/visits
```

The counter continues because `/data` is in `docker-project_app-data`.

```bash
docker volume ls
docker volume inspect docker-project_app-data
```

For this small file-based demo, stop writes before taking a backup:

```bash
mkdir -p backups
docker compose stop api
docker run --rm \
  --mount type=volume,source=docker-project_app-data,target=/data,readonly \
  --mount type=bind,source="$(pwd)/backups",target=/backup \
  alpine:3.22 tar czf /backup/app-data.tar.gz -C /data .
docker compose start api
```

Restore into a **new** volume so the original remains intact:

```bash
docker volume create docker-project_restored-data
docker run --rm \
  --mount type=volume,source=docker-project_restored-data,target=/data \
  --mount type=bind,source="$(pwd)/backups",target=/backup,readonly \
  alpine:3.22 tar xzf /backup/app-data.tar.gz -C /data
```

Inspect the restored files before configuring a service to use that volume. For databases, use database-aware backup tools; copying live database files is generally not a consistent backup. Bind mounts belong to the machine running the daemon, which matters when using a remote Docker context. [Volumes](https://docs.docker.com/engine/storage/volumes/)

## Find and reclaim disk space

Inspect first:

```bash
docker system df
docker system df -v
docker ps -a --size
docker buildx du
```

Shared image layers mean image sizes do not simply add up. Docker disk usage also differs from the physical size of Docker Desktop's VM disk. [docker system df](https://docs.docker.com/reference/cli/docker/system/df/)

Choose the cleanup matching your intent; these delete resources:

| Command                  | What it removes                                                              |
| ------------------------ | ---------------------------------------------------------------------------- |
| `docker container prune` | All stopped containers, including their writable layers                      |
| `docker image prune`     | Dangling images                                                              |
| `docker image prune -a`  | Images unused by any container                                               |
| `docker buildx prune`    | Unused build cache for the selected builder                                  |
| `docker volume prune`    | Unused anonymous local volumes in this CLI version                           |
| `docker volume prune -a` | Unused named volumes too                                                     |
| `docker system prune`    | Stopped containers, unused networks, dangling images, and unused build cache |

An unused volume can still hold important data. Avoid treating broad prune commands as routine cleanup for one project.

```bash
docker compose down       # Keep the playground's data
docker compose down -v    # RESET: also delete its declared named/attached anonymous volumes
```

External volumes are not removed by `compose down`. There is no general Docker equivalent of `jj undo` after deleting data.

## Compose tricks and live development

```bash
docker compose config --quiet   # Validate configuration
docker compose config          # See the merged/interpolated configuration
docker compose config --services
docker compose --dry-run up --build -d
```

Rendered configuration can contain expanded environment values; review before sharing it.

Start the supplied development override:

```bash
docker compose -f compose.yaml -f compose.watch.yaml up --build --watch
```

Edit `app/main.py`: Compose syncs it into the container and Uvicorn reloads. Requirements changes trigger an image rebuild. Source sync and process reload are separate mechanisms; the override enables both. Use this override for development only. [Compose Watch](https://docs.docker.com/compose/how-tos/file-watch/)

The fixed `container_name: test-app` makes examples convenient but prevents service scaling. Multiple replicas also need different host-port handling and a real shared data store instead of this file counter.

## Generate Compose from existing containers

With `test-app` already created:

```bash
docker compose alpha generate test-app > generated.compose.yaml
docker compose -f generated.compose.yaml config --quiet
```

This reconstructs configuration from an existing container; it does not generate a Dockerfile from source or back up application data. Review image references, mounts, ports, environment, and names before adopting it. Do not launch a second copy with the same name/port alongside the original.

The command is **experimental and version-dependent**. It is present in the installed Compose v2.40.2; check your own installation with:

```bash
docker compose alpha --help
docker compose alpha generate --help
```

Another optional alpha feature produces a service graph:

```bash
docker compose alpha viz --networks --ports > compose.dot
dot -Tsvg compose.dot -o compose.svg
```

The second command requires Graphviz. This is a Compose topology graph, distinct from a build execution trace.

## Publish images and Compose over OCI

**An image and a Compose artifact are different registry objects.** Publish the image first, then publish the application definition that references it.

Set your Docker Hub namespace and a release tag:

```bash
export DOCKER_USER=your-dockerhub-name
export APP_TAG=v1
docker login

docker build -t "docker.io/$DOCKER_USER/docker-project:$APP_TAG" .
docker push "docker.io/$DOCKER_USER/docker-project:$APP_TAG"

docker compose -f compose.publish.yaml config --quiet
docker compose -f compose.publish.yaml publish --resolve-image-digests \
  "docker.io/$DOCKER_USER/docker-project-compose:$APP_TAG"
```

Run the published definition, after stopping the local app to free port 8000:

```bash
docker compose down
docker compose \
  -f "oci://docker.io/$DOCKER_USER/docker-project-compose:$APP_TAG" \
  up -d
```

Use that same `-f oci://...` reference for subsequent `logs`, `ps`, and `down` commands. The release project has its own volume; it does not inherit the local demo's data automatically.

Publishing is now `docker compose publish`, although some installations also expose `alpha publish`. OCI Compose support requires Compose 2.34.0 or later. The supplied publish file has image references and no local bind mounts or build-only services. `--with-env` can include environment values in the artifact; do not use it for secrets. [OCI application guide](https://docs.docker.com/compose/how-tos/oci-artifact/)

## Buildx, BuildKit, and build traces

**Buildx is the CLI frontend; BuildKit executes the build.**

```bash
docker buildx version
docker buildx ls
docker buildx inspect
docker buildx build --load -t docker-project:dev .
```

`--load` imports a build result into the local image store. `--push` exports to a registry. With a `docker-container` builder, omitting both can leave the result only in the build cache; do not assume `docker run` will find it.

### Build history and the Jaeger UI

```bash
docker buildx history ls
docker buildx history inspect BUILD_REF
docker buildx history logs BUILD_REF
docker buildx history open BUILD_REF     # Docker Desktop build view

# Most recent build: opens a temporary Jaeger web UI
docker buildx history trace

# Pick a build and a fixed local UI port
docker buildx history trace BUILD_REF --addr 127.0.0.1:16686

# Compare the most recent trace with the previous one
docker buildx history trace --compare='^1'
```

Replace `BUILD_REF` with a reference from `history ls`. Keep the trace command running while browsing; stop with `Ctrl+C`. This is the “hidden web UI” from the notes: no separate Jaeger container is needed for this viewer. Inspect timing, parallel activity, and slow build steps. It traces **build execution**, not FastAPI requests. [Build trace reference](https://docs.docker.com/reference/cli/docker/buildx/history/trace/)

Records belong to builders. If history is empty, check `docker buildx ls` and select the relevant builder with `--builder NAME`; availability also depends on Buildx/BuildKit versions and record retention. `docker image history` shows image layers, not build-run records.

### Build for Intel and Apple Silicon/Linux ARM

```bash
docker buildx create --name app-builder --driver docker-container --use
docker buildx inspect --bootstrap

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t "docker.io/$DOCKER_USER/docker-project:$APP_TAG" \
  --push .

docker buildx imagetools inspect "docker.io/$DOCKER_USER/docker-project:$APP_TAG"
```

Run the registry-variable setup above first. Reuse an existing builder with `docker buildx use app-builder`. Cross-platform builds need suitable native nodes or emulation; Docker Desktop generally provides emulation. It may be slower than a native build. Registry export avoids local image-store limitations for multi-platform output. [Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)

## Cool tricks

### 1. Extract a file from an image without starting its application

```bash
docker create --name image-extract docker-project:dev
mkdir -p recovered
docker cp image-extract:/app/app/main.py ./recovered/main.py
docker rm image-extract
```

`create` prepares a container filesystem but does not run its entrypoint.

### 2. Transfer an image without a registry

```bash
docker image save -o docker-project.tar docker-project:dev
# Transfer the archive to the other machine, then:
docker image load -i docker-project.tar
```

Use `save/load` for images and their metadata. `export/import` operates on container filesystems and is not an equivalent image backup; mounted volume data is separate in either case.

### 3. Build with a secret without baking it into a layer

If your build needs a private Python package index, replace the dependency installation step with a secret-consuming step:

```dockerfile
RUN --mount=type=secret,id=pip_config,required=true \
    --mount=type=cache,target=/root/.cache/pip \
    PIP_CONFIG_FILE=/run/secrets/pip_config pip install -r requirements.txt
```

Then pass a local secret file at build time:

```bash
docker buildx build --load \
  --secret id=pip_config,src=/path/to/private-pip.conf \
  -t docker-project:dev .
```

Secret mounts are temporary for that build instruction. Do not copy them into the image or echo credentials into build logs. Use this instead of credential-bearing `ARG`/`ENV` instructions. [Build secrets](https://docs.docker.com/build/building/secrets/)

### 4. Get a compact dashboard

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
```

### 5. Check which daemon you are talking to

```bash
docker context show
docker context ls
docker version
docker info
```

Commands act on the selected daemon. Check your context before interpreting “missing” containers or running cleanup on a machine with multiple Docker environments.

## Troubleshooting card

| Symptom                       | First check                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| Cannot connect to Docker      | Is Desktop/Engine running? Check context and socket permissions.                    |
| Browser cannot reach the app  | `docker compose ps`, `docker port test-app`, app bind address, host port.           |
| Container exits immediately   | `docker logs test-app` and `docker inspect --format '{{json .State}}' test-app`.    |
| Process killed / exit 137     | Check `.State.OOMKilled`, memory limits, and events; 137 alone does not prove OOM.  |
| Code change has no effect     | Rebuild/recreate, or use the Watch override. Restart alone cannot update the image. |
| Missing data after recreation | Was the path in a named volume, a bind mount, or only the writable layer?           |
| Disk usage surprises          | `docker system df -v` and `docker buildx du`; inspect before pruning.               |
| `exec` fails on a stopped app | Read logs/inspect, recover files with `cp`, or start it if appropriate.             |
| `bash` or `curl` missing      | Slim images often omit them; use `sh` and the installed Python tools.               |
| Wrong CPU architecture        | Inspect image platforms; build the target architecture or use emulation.            |
| `alpha generate` missing      | Experimental commands vary; use your installed `--help`.                            |
| Trace history empty           | Check the selected builder, Buildx version, and retained records.                   |

For a stuck app, start with **logs → inspect → events → stats**. For a slow build, start with **plain progress → history logs → trace**.
