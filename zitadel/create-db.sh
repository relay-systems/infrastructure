#!/bin/sh
# Creates the ZITADEL role and database on the EXISTING postgres service.
# Purely additive and idempotent: creates only what is missing; never alters, drops or grants anything
# on the relay database. Re-running is a no-op and does NOT rotate an existing role's password.
#
# Usage (from the repository root, postgres service running; mandatory step 1 before starting the stack):
#   ./zitadel/create-db.sh [env-file]      # default env file: ./.env.zitadel
# The env file is NEVER sourced: only exact `KEY=value` lines are read as plain text. An already-exported
# variable overrides the file. Validated (values never printed): ZITADEL_DB_NAME/USER [a-z0-9_]+, ZITADEL_DB_PASSWORD
# [A-Za-z0-9_.~-]{16,} (URL-safe for the DSN; e.g. `openssl rand -hex 24`), ZITADEL_MASTERKEY exactly 32 chars,
# LOGIN_SESSION_COOKIE_SECRET and ZITADEL_ADMIN_PASSWORD non-empty; none may contain CHANGE_ME; the DB values also no quotes/whitespace.
# ZITADEL_PSQL_TARGET overrides the command that reaches postgres (default: docker compose exec -T postgres).
# Safety: the password travels only via stdin (never argv/ps/logs); it is never printed.
set -eu

target=${ZITADEL_PSQL_TARGET:-docker compose exec -T postgres}
envfile=${1:-.env.zitadel}
cr=$(printf '\r')

die() { echo "error: $*" >&2; exit 1; }

# get KEY [strict] -> sets $val (exported env wins; else the single exact KEY=value line of the env file, read as text).
get() {
  k=$1 val=$(printenv "$k" || true)
  if [ -z "$val" ]; then
    [ -f "$envfile" ] || die "$k is missing or empty (set it or provide $envfile)"
    n=$(grep -Ec "^[[:space:]]*(export[[:space:]]+)?$k[[:space:]]*=" "$envfile" || true)
    m=$(grep -c "^$k=" "$envfile" || true)
    [ "$n" -gt 0 ] || die "$k is missing in $envfile"
    [ "$n" -le 1 ] || die "$k is defined $n times in $envfile (exactly one allowed)"
    [ "$m" -eq 1 ] || die "$k line in $envfile is malformed (need exact KEY=value: no export, spaces or indentation)"
    val=$(sed -n "s/^$k=//p" "$envfile")
  fi
  [ -n "$val" ] || die "$k is empty"
  case $val in *"$cr"*) die "$k contains a carriage return (CRLF line endings? use LF)";; esac
  case $val in [[:space:]]*|*[[:space:]]) die "$k has leading or trailing whitespace";; esac
  [ -z "${2:-}" ] || case $val in *[[:space:]]*|*\"*|*\'*) die "$k contains whitespace or quotes";; esac
  case $(printf %s "$val" | tr A-Z a-z) in *change_me*) die "$k still contains the CHANGE_ME placeholder";; esac
}

get ZITADEL_DB_NAME 1; zd=$val
get ZITADEL_DB_USER 1; zu=$val
get ZITADEL_DB_PASSWORD 1; zp=$val
get ZITADEL_MASTERKEY; [ ${#val} -eq 32 ] || die "ZITADEL_MASTERKEY must be exactly 32 characters (got ${#val})"
get LOGIN_SESSION_COOKIE_SECRET
get ZITADEL_ADMIN_PASSWORD

case $zd in *[!a-z0-9_]*) die "ZITADEL_DB_NAME must match [a-z0-9_]+";; esac
case $zu in *[!a-z0-9_]*) die "ZITADEL_DB_USER must match [a-z0-9_]+";; esac
case $zp in *[!A-Za-z0-9_.~-]*) die "ZITADEL_DB_PASSWORD must match [A-Za-z0-9_.~-]+ (e.g. openssl rand -hex 24)";; esac
[ ${#zp} -ge 16 ] || die "ZITADEL_DB_PASSWORD must be at least 16 characters (got ${#zp})"

# Superuser and default db name are read from inside the container.
# shellcheck disable=SC2086
info=$($target sh -c 'printf "%s %s" "$POSTGRES_USER" "$POSTGRES_DB"') || { echo "error: cannot reach postgres via: $target" >&2; exit 1; }
su=${info% *} pgdb=${info#* }
if [ "$zd" = "$pgdb" ] || [ "$zd" = relay ] || [ "$zu" = "$su" ]; then
  echo "error: refusing: ZITADEL_DB_NAME must not be the relay database and ZITADEL_DB_USER must not be the superuser" >&2
  exit 1
fi

# shellcheck disable=SC2086
$target sh -c 'exec psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres' <<SQL
\set zd '$zd'
\set zu '$zu'
\set zp '$zp'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'zu', :'zp')
  WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'zu') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'zd', :'zu')
  WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'zd') \gexec
SQL
echo "ok: role '$zu' and database '$zd' present"
