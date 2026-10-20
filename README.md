# infrastructure

Local development infrastructure for Relay: PostgreSQL 16 and an optional self-hosted ZITADEL identity provider (Docker Compose).

| File | Purpose |
|---|---|
| `docker-compose.yml` | PostgreSQL on `127.0.0.1:5432`, named volume `postgres_data`. A plain `docker compose up` starts only this. |
| `docker-compose.zitadel.yml` | Opt-in overlay: ZITADEL API, Login UI and a Traefik proxy on `127.0.0.1:8081`. |
| `zitadel/` | Provisioning script, Traefik config and the ZITADEL setup guide (`zitadel/README.md`). |
| `.env.zitadel.example` | Placeholders only. Copy to `.env.zitadel` (git-ignored) and fill in real values. |

```
docker compose up -d                                                        # PostgreSQL only
docker compose -f docker-compose.yml -f docker-compose.zitadel.yml --env-file .env.zitadel up -d --wait   # + ZITADEL
```

Never run `docker compose down -v` or remove the `postgres_data` volume: it holds every database on this server.

The compose project name is derived from the directory name, which must stay `infrastructure` to keep existing containers and volumes.

## Branches

`TASK_<kebab-case>` -> `test` -> `main`, both through pull requests, enforced by the `branch-policy` workflow. Feature branches are created from `test`.
