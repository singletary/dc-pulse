#!/bin/sh

set -eu

if ! identity_info="$(security find-identity -v -p codesigning 2>&1)"; then
    echo "TestFlight signing preflight failed: signing identities could not be read." >&2
    echo "${identity_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

if ! printf '%s\n' "${identity_info}" | grep -Eq '[1-9][0-9]* valid identities found'; then
    echo "TestFlight signing preflight failed: no valid code-signing identity was found." >&2
    echo "${identity_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

identity_hash="$(
    printf '%s\n' "${identity_info}" |
        awk '/^[[:space:]]*[0-9]+\)/ { print $2; exit }'
)"
if [ -z "${identity_hash}" ]; then
    echo "TestFlight signing preflight failed: a signing identity could not be selected." >&2
    echo "${identity_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

probe_path="$(mktemp "${TMPDIR:-/tmp}/dc-pulse-signing-probe.XXXXXX")"
trap 'rm -f "${probe_path}"' EXIT
cp /usr/bin/true "${probe_path}"

if ! signing_info="$(
    codesign \
        --force \
        --sign "${identity_hash}" \
        --timestamp=none \
        "${probe_path}" 2>&1
)"; then
    echo "TestFlight signing preflight failed: the existing private key could not sign a temporary probe." >&2
    echo "${signing_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

if ! verification_info="$(codesign --verify --strict "${probe_path}" 2>&1)"; then
    echo "TestFlight signing preflight failed: the temporary probe signature could not be verified." >&2
    echo "${verification_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

echo "${identity_info}"
echo "TestFlight signing preflight passed. A temporary file was signed and verified; Keychain was not modified."
