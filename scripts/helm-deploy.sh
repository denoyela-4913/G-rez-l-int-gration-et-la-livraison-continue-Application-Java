#!/bin/bash
# Installe ou met à jour l'environnement dev ou staging (workshop-organizer) avec Helm.
# Usage : scripts/helm-deploy.sh <install|upgrade> <dev|staging>
#   install : première installation ; --create-namespace crée le namespace, qui n'existe pas encore.
#   upgrade : applique un nouveau tag d'image ou de nouvelles valeurs à une release déjà installée.
# Raccourcis : install-dev.sh, upgrade-dev.sh, install-staging.sh, upgrade-staging.sh.
# Le tag de l'image dans values-dev.yaml suit chaque release (mis à jour par la CI) ; celui de
# values-staging.yaml est promu à la main.
# Staging exige aussi DB_PASSWORD='<mot de passe>' (mot de passe de la base, hors Git).
# À lancer depuis n'importe où : le script se place à la racine du dépôt.
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION=${1:-}
ENVIRONMENT=${2:-}

# Paramètres propres à chaque environnement : le seul endroit où dev et staging diffèrent.
RELEASE=workshop
CHART=charts/workshop-organizer
case "$ENVIRONMENT" in
  dev)     NAMESPACE=workshop-dev ;;
  staging) NAMESPACE=workshop-staging ;;
  *)
    echo "Usage : $0 <install|upgrade> <dev|staging>" >&2
    exit 1
    ;;
esac
VALUES=$CHART/values-$ENVIRONMENT.yaml

# Options propres à chaque action.
case "$ACTION" in
  install) LABEL="Installation"; ACTION_ARGS=(--create-namespace) ;;
  upgrade) LABEL="Mise à jour";  ACTION_ARGS=() ;;
  *)
    echo "Usage : $0 <install|upgrade> <dev|staging>" >&2
    exit 1
    ;;
esac

PASSWORD_ARGS=()

# Paramètre obligatoire en staging : le mot de passe de la base n'est pas dans Git (voir values-staging.yaml).
# Il est lu dans la variable d'environnement DB_PASSWORD plutôt que sur la ligne de commande, pour ne pas
# apparaître dans l'historique du shell, et transmis à Helm par un fichier temporaire (--set-file, créé en
# lecture seule pour nous et supprimé à la sortie) : il n'apparaît pas non plus dans la liste des processus,
# et les caractères spéciaux (virgule, =, $) ne posent pas de problème.
if [ "$ENVIRONMENT" = staging ]; then
  if [ -z "${DB_PASSWORD:-}" ]; then
    echo "ERREUR : la variable DB_PASSWORD est obligatoire pour staging (mot de passe de la base)." >&2
    echo "Exemple : DB_PASSWORD='<mot de passe>' $0 $ACTION $ENVIRONMENT" >&2
    exit 1
  fi
  PASSWORD_FILE=$(mktemp)
  trap 'rm -f "$PASSWORD_FILE"' EXIT
  printf %s "$DB_PASSWORD" > "$PASSWORD_FILE"
  PASSWORD_ARGS=(--set-file "db.password=$PASSWORD_FILE")
fi

echo "$LABEL de $RELEASE dans le namespace $NAMESPACE (valeurs : $VALUES)..."
helm "$ACTION" "$RELEASE" "$CHART" \
  -f "$VALUES" \
  -n "$NAMESPACE" \
  ${ACTION_ARGS[@]+"${ACTION_ARGS[@]}"} \
  ${PASSWORD_ARGS[@]+"${PASSWORD_ARGS[@]}"}

echo
echo "$LABEL terminée. Suivre le démarrage : kubectl get pods -n $NAMESPACE -w"
