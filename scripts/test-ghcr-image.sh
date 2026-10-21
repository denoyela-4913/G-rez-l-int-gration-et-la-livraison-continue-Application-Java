#!/bin/bash
# Teste une image publiée sur GHCR : la télécharge, la lance avec sa base PostgreSQL
# (docker-compose.yml), vérifie qu'elle répond et qu'elle ne tourne pas en root, puis nettoie.
# Usage : scripts/test-ghcr-image.sh [--pause] ghcr.io/<utilisateur>/<image>:<tag>
#   --pause : attend la touche Entrée entre chaque étape (pour suivre pas à pas).
# Attention : à la fin, l'image locale est supprimée (docker rmi) et les volumes du compose aussi.
set -euo pipefail
cd "$(dirname "$0")/.."

PAUSE=false
if [ "${1:-}" = "--pause" ]; then
	PAUSE=true
	shift
fi

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
	echo "Usage : $0 [--pause] <IMAGE>   (exemple : ghcr.io/user/image:main)" >&2
	exit 1
fi
if [[ "$IMAGE" != ghcr.io/* ]]; then
	echo "Ce n'est pas une image GHCR (elle doit commencer par ghcr.io/) : $IMAGE" >&2
	exit 2
fi

pause() {
	if $PAUSE; then
		read -r -p "Entrée pour continuer... "
	fi
}

echo "Téléchargement de l'image depuis GHCR..."
pause
if ! docker pull "$IMAGE"; then
	echo "Image introuvable : $IMAGE" >&2
	exit 3
fi

echo "Lancement du conteneur..."
pause
# docker-compose.yml attend l'image workshop-organizer:latest : on lui donne ce nom,
# et --no-build empêche de la reconstruire (on teste bien l'image téléchargée).
docker tag "$IMAGE" workshop-organizer:latest
docker compose up -d --no-build --wait
docker compose ps

echo "Tests..."
pause
curl -fsSI http://localhost:8080/
test "$(docker compose exec -T app id -u)" = "10001" && echo "OK : le conteneur ne tourne pas en root (UID 10001)"

echo "Nettoyage..."
pause
docker compose down -v
docker rmi "$IMAGE"
