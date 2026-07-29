#!/bin/sh

set -eu

login_keychain="${HOME}/Library/Keychains/login.keychain-db"

if ! keychain_info="$(security show-keychain-info "${login_keychain}" 2>&1)"; then
    echo "TestFlight signing preflight failed: the login keychain is not accessible." >&2
    echo "${keychain_info}" >&2
    echo "Stop here. Do not retry the archive or modify Keychain automatically." >&2
    exit 1
fi

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

echo "${keychain_info}"
echo "${identity_info}"
echo "TestFlight signing preflight passed. Keychain was not modified."
