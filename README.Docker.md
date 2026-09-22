### Building and running your application

When you're ready, start your application by running:
`docker compose up --build`.

Your application will be available at http://localhost:5002.

### Deploying your application to the cloud

First, build your image, e.g.: `docker build -t test-app .`.
If your cloud uses a different CPU architecture than your development
machine (e.g., you are on a Mac M1 and your cloud provider is amd64),
you'll want to build the image for that platform, e.g.:
`docker build --platform=linux/amd64 -t test-app .`.

Then, push it to your registry, e.g. `docker push myregistry.com/test-app`.

Consult Docker's [getting started](https://docs.docker.com/go/get-started-sharing/)
docs for more detail on building and pushing.

## Running docker container with `secretspec`

```bash
docker image build -t test-app .
```

```bash
secretspec run --provider pass --profile development -- docker run --rm -e DATABASE_URL -e SECRETSPEC_PROVIDER=env test-app
```

## Running docker compose with `secretspec`

```bash
secretspec run --provider pass --profile development -- docker compose up --build
```

### References

- [Docker's Python guide](https://docs.docker.com/language/python/)

