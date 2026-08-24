#!/bin/bash
# Runtime tuning of Jobe limits via environment variables.
#
# The image is built with a MAXIMUM number of jobeNN worker accounts
# (see Dockerfile: jobe_max_users=64 at build time). A course that needs
# fewer concurrent jobs sets JOBE_MAX_USERS lower here, without a rebuild.
# Values are clamped to sane bounds so a bad value can't break the server.
#
# Env vars (all optional, set per-course in the e-quiz chart values):
#   JOBE_MAX_USERS        active concurrent job slots (1..64, default 64)
#   JOBE_WAIT_TIMEOUT     secs a submission may queue for a free slot (5..300, default 120)
#   JOBE_PYTHON_MEMMB     per-job memory cap for Python, in MB (128..4000, default 1500)
set -euo pipefail

JOBE_CFG=/var/www/html/jobe/app/Config/Jobe.php
PY_CFG=/var/www/html/jobe/app/Libraries/Python3Task.php

# clamp VALUE LO HI DEFAULT  -> prints VALUE clamped to [LO,HI]; non-numeric -> DEFAULT
clamp() {
    local v="$1" lo="$2" hi="$3" def="$4"
    case "$v" in ''|*[!0-9]*) v="$def" ;; esac
    if [ "$v" -gt "$hi" ]; then v="$hi"; fi
    if [ "$v" -lt "$lo" ]; then v="$lo"; fi
    printf '%s' "$v"
}

MAX_USERS=$(clamp "${JOBE_MAX_USERS:-64}" 1 64 64)
WAIT=$(clamp "${JOBE_WAIT_TIMEOUT:-120}" 5 300 120)
PYMEM=$(clamp "${JOBE_PYTHON_MEMMB:-1500}" 128 4000 1500)

echo "[jobe entrypoint] max_users=${MAX_USERS} wait_timeout=${WAIT}s python_mem=${PYMEM}MB"

sed -i "s/^    public int \$jobe_max_users = .*/    public int \$jobe_max_users = ${MAX_USERS};/" "$JOBE_CFG"
sed -i "s/^    public int \$jobe_wait_timeout = .*/    public int \$jobe_wait_timeout = ${WAIT};  # Max number of secs to wait for a free Jobe user./" "$JOBE_CFG"
sed -i "s|^        \$this->default_params\['memorylimit'\] = .*|        \$this->default_params['memorylimit'] = ${PYMEM}; // Per-job memory cap (MB) for Python, enforced by runguard RLIMIT_AS.|" "$PY_CFG"

# sed -i rewrites the files as root; restore ownership so PHP (www-data) still owns them.
chown www-data:www-data "$JOBE_CFG" "$PY_CFG" || true

exec /usr/sbin/apache2ctl -D FOREGROUND
