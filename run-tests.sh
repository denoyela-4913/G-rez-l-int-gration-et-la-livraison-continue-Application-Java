#!/bin/bash
set -u
cd "$(dirname "$0")"

./gradlew clean test
RES=$?

if [ "$RES" -eq 0 ]; then
	echo "Tous les tests sont passés"
else
	echo "Échec des tests (code $RES)" >&2
fi

exit "$RES"
