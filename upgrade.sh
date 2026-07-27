#!/usr/bin/env bash
#
# EasyMonitor probe-node — upgrade script.
#
# Upgrades a Docker-deployed probe in place:
#   1. Reads the running container's configuration (env vars, network mode,
#      restart policy, port mappings)
#   2. Pulls the new image
#   3. Stops and removes the old container
#   4. Starts a fresh container with the same configuration
#   5. Verifies /health and prints /version
#
# Usage:
#   ./upgrade.sh                          # upgrade to <current repo>:latest
#   ./upgrade.sh easymonitor/probe-node:0.2.0   # upgrade/pin to a specific image
#
# The container name defaults to "easymonitor-probe"; override with
#   PROBE_CONTAINER=my-probe ./upgrade.sh

set -e

# ── colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()   { printf "${BLUE}ℹ${NC}  %s\n" "$1"; }
ok()     { printf "${GREEN}✓${NC}  %s\n" "$1"; }
warn()   { printf "${YELLOW}⚠${NC}  %s\n" "$1"; }
fail()   { printf "${RED}✗${NC}  %s\n" "$1"; exit 1; }
header() { printf "\n${BOLD}━━━ %s ━━━${NC}\n\n" "$1"; }

# ── checks ──────────────────────────────────────────────────────────────────
command -v docker >/dev/null 2>&1 || fail "Required command not found: docker"
command -v curl   >/dev/null 2>&1 || fail "Required command not found: curl"

CONTAINER="${PROBE_CONTAINER:-easymonitor-probe}"

docker inspect "$CONTAINER" >/dev/null 2>&1 \
    || fail "No container named '$CONTAINER' found. Set PROBE_CONTAINER if yours is named differently."

# ── capture current configuration ───────────────────────────────────────────
header "Capturing configuration from '$CONTAINER'"

OLD_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$CONTAINER")
OLD_IMAGE_ID=$(docker inspect --format '{{.Image}}' "$CONTAINER")

if [ -n "$1" ]; then
    NEW_IMAGE="$1"
else
    NEW_IMAGE="${OLD_IMAGE%%:*}:latest"
fi

ENV_ARGS=()
HEALTH_PORT=8080
while IFS= read -r line; do
    case "$line" in
        NODE_ID=*|REDIS_URL=*|REDIS_PASSWORD=*|REDIS_DB=*|JWT_TOKEN=*|PROBE_TAGS=*|DEFAULT_TIMEOUT=*|BATCH_SIZE=*|MAX_CONCURRENCY=*|HEALTH_CHECK_PORT=*)
            ENV_ARGS+=(-e "$line")
            [ "${line%%=*}" = "HEALTH_CHECK_PORT" ] && HEALTH_PORT="${line#*=}"
            ;;
    esac
done < <(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER")

[ ${#ENV_ARGS[@]} -gt 0 ] || fail "Could not read any probe env vars from '$CONTAINER' — aborting."

NETWORK_MODE=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$CONTAINER")
RESTART_POLICY=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$CONTAINER")
[ -n "$RESTART_POLICY" ] && [ "$RESTART_POLICY" != "no" ] || RESTART_POLICY="unless-stopped"

RUN_ARGS=(-d --name "$CONTAINER" --restart "$RESTART_POLICY")

if [ "$NETWORK_MODE" = "host" ]; then
    RUN_ARGS+=(--network host)
    VERIFY_PORT="$HEALTH_PORT"
else
    [ "$NETWORK_MODE" != "default" ] && [ "$NETWORK_MODE" != "bridge" ] && RUN_ARGS+=(--network "$NETWORK_MODE")
    PORT_MAPPINGS=$(docker inspect --format \
        '{{range $p, $bindings := .HostConfig.PortBindings}}{{range $bindings}}{{.HostPort}}:{{$p}} {{end}}{{end}}' \
        "$CONTAINER")
    VERIFY_PORT=""
    for mapping in $PORT_MAPPINGS; do
        RUN_ARGS+=(-p "${mapping%/*}")
        [ -z "$VERIFY_PORT" ] && VERIFY_PORT="${mapping%%:*}"
    done
    [ -n "$VERIFY_PORT" ] || VERIFY_PORT="$HEALTH_PORT"
fi

ok "Configuration captured (image: $OLD_IMAGE, network: $NETWORK_MODE, restart: $RESTART_POLICY)."

# ── pull ────────────────────────────────────────────────────────────────────
header "Pulling $NEW_IMAGE"
if docker pull "$NEW_IMAGE" 2>/dev/null; then
    ok "Image pulled."
elif docker image inspect "$NEW_IMAGE" >/dev/null 2>&1; then
    warn "Could not pull $NEW_IMAGE — using the local copy (expected when rolling back to an image ID)."
else
    fail "Image $NEW_IMAGE not found: pull failed and no local copy exists."
fi

# ── swap ────────────────────────────────────────────────────────────────────
header "Replacing container"
info "Stopping and removing old container..."
docker stop "$CONTAINER" >/dev/null
docker rm "$CONTAINER" >/dev/null
ok "Old container removed (previous image kept as $OLD_IMAGE_ID for rollback)."

info "Starting new container..."
docker run "${RUN_ARGS[@]}" "${ENV_ARGS[@]}" "$NEW_IMAGE" >/dev/null
ok "Container started."

# ── verify ──────────────────────────────────────────────────────────────────
header "Verifying"
info "Waiting for the probe to become healthy on port $VERIFY_PORT..."
HEALTHY=false
for _ in $(seq 1 15); do
    if curl -fsS --max-time 2 "http://localhost:${VERIFY_PORT}/health" >/dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 2
done

if $HEALTHY; then
    ok "Probe is healthy."
    info "Version: $(curl -fsS --max-time 2 "http://localhost:${VERIFY_PORT}/version" 2>/dev/null || echo 'unavailable')"
    header "Done"
    ok "Probe upgraded to $NEW_IMAGE."
else
    warn "Probe did not report healthy within 30s."
    warn "Inspect logs with:  docker logs $CONTAINER"
    warn "Roll back with:     ./upgrade.sh $OLD_IMAGE_ID"
    exit 1
fi
