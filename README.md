# infrastructure

Local development infrastructure for Relay: PostgreSQL 16, an optional self-hosted ZITADEL identity provider and an optional Apache Cassandra node (Docker Compose).

| File | Purpose |
|---|---|
| `docker-compose.yml` | PostgreSQL on `127.0.0.1:5432`, named volume `postgres_data`. A plain `docker compose up` starts only this. |
| `docker-compose.zitadel.yml` | Opt-in overlay: ZITADEL API, Login UI and a Traefik proxy on `127.0.0.1:8081`. |
| `docker-compose.cassandra.yml` | Opt-in, self-contained overlay: a single-node Apache Cassandra 5.0.9 (cluster `relay-local`) on `127.0.0.1:9042`, named volume `cassandra_data`. It does not depend on PostgreSQL or ZITADEL. |
| `zitadel/` | Provisioning script, Traefik config and the ZITADEL setup guide (`zitadel/README.md`). |
| `.env.zitadel.example` | Placeholders only. Copy to `.env.zitadel` (git-ignored) and fill in real values. |

```
docker compose up -d                                                        # PostgreSQL only
docker compose -f docker-compose.yml -f docker-compose.zitadel.yml --env-file .env.zitadel up -d --wait   # + ZITADEL
```

Never run `docker compose down -v` or remove the `postgres_data` volume: it holds every database on this server.

## Cassandra (local development only)

Cassandra is the planned message-history database. Nothing uses it yet. This node is for local development only: it has **no authentication**, so it must never be exposed publicly. CQL is published on `127.0.0.1:9042` only; do not change the binding, publish other Cassandra ports (gossip 7000, JMX 7199) or put it behind a proxy.

```
docker compose -f docker-compose.cassandra.yml up -d --wait   # start Cassandra alone; first start takes about 1-2 minutes
```

To run it alongside the other services, add `-f docker-compose.cassandra.yml` to the commands above. Resources: 512 MB heap, 1.5 GiB memory limit, 2 CPUs.

```
docker compose -f docker-compose.cassandra.yml ps                                    # STATUS should be "healthy"
docker compose -f docker-compose.cassandra.yml exec cassandra cqlsh                  # open a CQL shell
docker compose -f docker-compose.cassandra.yml exec cassandra cqlsh -e 'DESCRIBE KEYSPACES'
docker compose -f docker-compose.cassandra.yml stop cassandra                        # shut down gracefully (up to 60 s), data is kept
```

Clients on the host connect to `127.0.0.1:9042` with cluster name `relay-local` and no credentials. Never run `docker compose down -v` or remove the `cassandra_data` volume: it holds all Cassandra data. The cluster name cannot change once data exists.

The compose project name is derived from the directory name, which must stay `infrastructure` to keep existing containers and volumes.

## Branches

`TASK_<kebab-case>` -> `test` -> `main`, both through pull requests, enforced by the `branch-policy` workflow. Feature branches are created from `test`.
