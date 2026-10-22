#!/bin/bash
# Met à jour la version de l'application aux endroits où elle est déclarée :
#   - build.gradle : version = 'X.Y.Z'
#   - Dockerfile   : ARG APP_VERSION=X.Y.Z
#   - values-dev.yaml : tag de app.image (dev suit chaque release ; staging reste promu à la main)
# Usage : ./update_version.sh 0.3.0
set -euo pipefail
cd "$(dirname "$0")"

if [ $# -ne 1 ] || ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "Usage : $0 X.Y.Z   (exemple : $0 0.3.0)" >&2
	exit 1
fi
VERSION="$1"

sed -i -E "s/^version = '[^']*'/version = '${VERSION}'/" build.gradle
sed -i -E "s/^ARG APP_VERSION=.*/ARG APP_VERSION=${VERSION}/" Dockerfile
sed -i -E "s#^(  image: .*:)[0-9]+\.[0-9]+\.[0-9]+\$#\1${VERSION}#" charts/workshop-organizer/values-dev.yaml

echo "Version mise à jour :"
grep -n "^version = " build.gradle
grep -n "^ARG APP_VERSION=" Dockerfile
grep -n "^  image: " charts/workshop-organizer/values-dev.yaml
