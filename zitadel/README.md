# ZITADEL (local identity provider)

Overlay `docker-compose.zitadel.yml`: `zitadel-api`, `zitadel-login`, `zitadel-proxy` (Traefik, file provider).
It uses its own `zitadel` database and role on the existing `postgres` service. The `relay` database is never touched.
Everything runs from the repository root. This setup is LOCAL ONLY (http, containers as root, PAT valid until 2099).

Prerequisites: Docker Engine 24+, Compose v2, at least 2 GB RAM.

## WARNINGS
- NEVER run `docker compose down -v` or remove `postgres_data`: it wipes BOTH the relay and zitadel databases.
- `ZITADEL_MASTERKEY` is immutable after first start. Back it up OUTSIDE the repo; losing it makes the data unreadable.
- Do not delete the `zitadel-bootstrap` volume separately from the `zitadel` database (they must stay in sync).
- `.env.zitadel` holds secrets and is git-ignored. Never commit it.

## Setup
```sh
cp .env.zitadel .env.zitadel   # then replace every CHANGE_ME_* (generation commands are in the file; DB password: openssl rand -hex 24)
```

## Provision the database (mandatory step 1, before Start; the postgres service must be running)
```sh
./zitadel/create-db.sh
```
Also validates the secrets in `.env.zitadel` (read as plain text, never executed): refuses CHANGE_ME leftovers, a masterkey
that is not 32 chars, or a DB password outside `[A-Za-z0-9_.~-]` / under 16 chars. Additive and idempotent: creates the `zitadel` role/database only if missing. A re-run changes nothing
(it does not rotate the password). Refuses to run if the names match the relay database or the superuser.

Not validated: cookie secret length (`LOGIN_SESSION_COOKIE_SECRET`, >= 32 chars per upstream docs; script only checks presence/placeholder/whitespace); admin password complexity (`ZITADEL_ADMIN_PASSWORD`, 8+ chars with upper, lower, number, symbol per upstream docs). Nothing forces the script to run: if skipped, only the 31-char masterkey placeholder is intentionally invalid, so CHANGE_ME cookie/admin placeholders pass Compose (`${VAR:?}` rejects only empty/unset). The script reads `.env.zitadel` as plain text, while Compose dotenv parsing strips quotes and `#` comments and expands `$`, so quote/`$`/`#` characters in values may be interpreted differently.

## Start
```sh
docker compose -f docker-compose.yml -f docker-compose.zitadel.yml --env-file .env.zitadel up -d --wait
```
- Login: http://localhost:8081
- Console: http://localhost:8081/ui/console?login_hint=zitadel-admin@zitadel.localhost
- Admin: `zitadel-admin@zitadel.localhost`, password = `ZITADEL_ADMIN_PASSWORD` from `.env.zitadel`

Only the proxy is published (127.0.0.1:8081). core-service keeps 8080.

## Stop
```sh
docker compose -f docker-compose.yml -f docker-compose.zitadel.yml --env-file .env.zitadel stop zitadel-proxy zitadel-login zitadel-api
```
A plain `docker compose down` (without both `-f` flags) does not stop the overlay services.
If you use `down`, never add `-v`.

## Upgrade
1. Back up: `docker compose exec -T postgres sh -c 'pg_dump -Fc -U "$POSTGRES_USER" zitadel' > zitadel-backup.dump` (store outside the repo).
2. Bump `ZITADEL_VERSION` in `.env.zitadel`.
3. Run `pull`, then `up -d --wait` with the same `-f ... --env-file` flags as Start.

## Reset ZITADEL only (relay untouched)
1. Run the Stop command above (`stop ... zitadel-api`, then `rm -f zitadel-proxy zitadel-login zitadel-api` with the same flags).
2. `docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE zitadel"'`
3. `docker volume rm infrastructure_zitadel-bootstrap` (check the exact name with `docker volume ls`; never touch `postgres_data`).
4. Run `./zitadel/create-db.sh` and Start again.
