#!/bin/bash
# Teste le déploiement Kubernetes (k8s/) sur Minikube : déploie l'application et sa base dans un
# namespace jetable, vérifie qu'elles répondent par le Service LoadBalancer, que les données sont bien
# écrites dans PostgreSQL et qu'elles survivent à la suppression des pods, puis supprime le namespace.
# Usage : scripts/test-k8s-deploy.sh [--pause] [--keep]
#   --pause : attend la touche Entrée entre chaque étape (pour suivre pas à pas).
#   --keep  : ne supprime pas le namespace à la fin (pour inspecter le cluster à la main).
# Prérequis : kubectl, Minikube démarré et "minikube tunnel" lancé dans un autre terminal (sans le
# tunnel, le Service LoadBalancer n'a pas d'adresse externe). Le script les vérifie et, s'il manque
# quelque chose, affiche les commandes à lancer.
# Le port 8080 de la machine doit être libre : le tunnel y publie le Service.
# Codes de sortie : 0 = tout est bon, 1 = usage incorrect, 2 = prérequis manquant, 3 = un test a échoué.
set -euo pipefail
cd "$(dirname "$0")/.."

PAUSE=false
KEEP=false
for arg in "$@"; do
	case "$arg" in
		--pause) PAUSE=true ;;
		--keep) KEEP=true ;;
		*)
			echo "Usage : $0 [--pause] [--keep]" >&2
			exit 1
			;;
	esac
done

NS="workshop-test-$RANDOM"
APP="deploy/workshop-organizer-app-deployment"
DB="deploy/workshop-organizer-db-deployment"
SVC="workshop-organizer-app-service"
DB_NAME="workshop-organizer-database"
PASS=0
FAIL=0

pause() {
	if $PAUSE; then
		read -r -p "Entrée pour continuer... "
	fi
}

step() {
	echo
	echo "== $*"
	pause
}

ok() {
	echo "  OK     $*"
	PASS=$((PASS + 1))
}

ko() {
	echo "  ECHEC  $*"
	FAIL=$((FAIL + 1))
}

# check "description" commande... : OK si la commande réussit, ECHEC sinon.
check() {
	local description="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		ok "$description"
	else
		ko "$description"
	fi
}

# ---------- Prérequis ----------
# On accumule les manques pour les afficher tous d'un coup, puis on s'arrête avant de toucher au cluster.
MISSING=()

if ! command -v kubectl >/dev/null 2>&1; then
	MISSING+=("kubectl est absent. Installation : https://kubernetes.io/docs/tasks/tools/")
fi
if ! command -v minikube >/dev/null 2>&1; then
	MISSING+=("minikube est absent. Installation : https://minikube.sigs.k8s.io/docs/start/")
elif ! minikube status >/dev/null 2>&1; then
	MISSING+=("Minikube n'est pas démarré. Lancer :  minikube start")
elif command -v kubectl >/dev/null 2>&1 && [ "$(kubectl config current-context 2>/dev/null)" != "minikube" ]; then
	# Garde-fou : ce script crée et supprime des ressources, il ne doit viser que Minikube.
	MISSING+=("Le contexte kubectl actuel n'est pas \"minikube\" (c'est \"$(kubectl config current-context 2>/dev/null)\"). Lancer :  kubectl config use-context minikube")
fi
if command -v minikube >/dev/null 2>&1 && ! pgrep -f "minikube tunnel" >/dev/null 2>&1; then
	MISSING+=("Le tunnel Minikube n'est pas lancé. Dans un AUTRE terminal, lancer et laisser ouvert :  minikube tunnel")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
	echo "Prérequis manquants :" >&2
	for message in "${MISSING[@]}"; do
		echo "  - $message" >&2
	done
	echo "Puis relancer : $0" >&2
	exit 2
fi

# Quoi qu'il arrive (succès ou échec), le namespace de test est supprimé à la sortie, sauf avec --keep.
# Supprimer le namespace supprime aussi le PVC et le volume de la base.
cleanup() {
	if $KEEP; then
		echo
		echo "Namespace conservé : $NS   (suppression : kubectl delete namespace $NS)"
	else
		echo
		echo "Nettoyage : suppression du namespace $NS..."
		kubectl delete namespace "$NS" --wait=true >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

# http_code URL [options curl] : affiche le code HTTP de la réponse (000 si pas de réponse).
http_code() {
	curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@" 2>/dev/null || true
}

# wait_http_200 URL : attend jusqu'à 60 s que l'URL réponde 200.
wait_http_200() {
	local i
	for i in $(seq 1 30); do
		[ "$(http_code "$1")" = "200" ] && return 0
		sleep 2
	done
	return 1
}

# Atelier de test (nom unique : on est sûr de retrouver notre donnée, pas celle d'un autre test ou
# d'un autre service qui répondrait sur le port 8080).
WORKSHOP="Atelier-$RANDOM"

# count_workshop : nombre de lignes de l'atelier de test, lu directement dans PostgreSQL (dans le pod
# de la base). -t -A : sortie brute, sans en-tête ni mise en forme.
count_workshop() {
	kubectl exec -n "$NS" "$DB" -- psql -U postgres -d "$DB_NAME" -t -A \
		-c "select count(*) from workshop_model where name = '$WORKSHOP'"
}

# wait_workshop_listed : attend jusqu'à 60 s que l'API renvoie l'atelier de test.
wait_workshop_listed() {
	local i
	for i in $(seq 1 30); do
		curl -s --max-time 5 "$URL/api/workshops" | grep -q "$WORKSHOP" && return 0
		sleep 2
	done
	return 1
}

# ---------- Déploiement ----------
step "Déploiement de k8s/ dans le namespace $NS"
kubectl create namespace "$NS" >/dev/null
kubectl apply -n "$NS" -f k8s/
check "la base est prête (rollout)" kubectl rollout status -n "$NS" "$DB" --timeout=120s
check "l'application est prête (rollout)" kubectl rollout status -n "$NS" "$APP" --timeout=180s
check "le PVC de la base est lié à un volume (Bound)" \
	test "$(kubectl get pvc -n "$NS" workshop-organizer-db-pvc -o jsonpath='{.status.phase}')" = "Bound"

# ---------- Accès par le LoadBalancer ----------
step "Adresse externe du Service (fournie par minikube tunnel)"
IP=""
for _ in $(seq 1 30); do
	IP=$(kubectl get svc -n "$NS" "$SVC" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
	[ -n "$IP" ] && break
	sleep 2
done
if [ -z "$IP" ]; then
	ko "le Service n'a pas d'adresse externe : le tunnel ne fonctionne pas (relancer : minikube tunnel)"
	echo
	echo "Résultat : $PASS réussi(s), $FAIL échec(s)" >&2
	exit 3
fi
ok "adresse externe : $IP"
URL="http://$IP:8080"

# ---------- Tests fonctionnels ----------
step "L'application répond par le LoadBalancer"
check "GET / répond 200" wait_http_200 "$URL/"
check "GET /api/workshops répond 200 (l'app lit dans la base)" wait_http_200 "$URL/api/workshops"

step "Écriture par l'API, puis vérification directe dans PostgreSQL"
JSON='Content-Type: application/json'
# Un atelier ne peut référencer que des notions déjà existantes : on crée la notion d'abord.
check "POST /api/notions répond 200" \
	test "$(http_code -X POST "$URL/api/notions" -H "$JSON" -d '{"name":"Pod"}')" = "200"
check "POST /api/workshops répond 200" \
	test "$(http_code -X POST "$URL/api/workshops" -H "$JSON" -d "{\"name\":\"$WORKSHOP\",\"notions\":[{\"name\":\"Pod\"}]}")" = "200"
check "GET /api/workshops contient l'atelier créé" wait_workshop_listed
check "l'atelier est bien dans la table PostgreSQL" test "$(count_workshop)" = "1"

# ---------- Résilience ----------
step "Suppression du pod de la base : les données doivent survivre (PVC)"
kubectl delete pod -n "$NS" -l app=workshop-organizer-db >/dev/null
check "la base est de nouveau prête" kubectl rollout status -n "$NS" "$DB" --timeout=120s
sleep 5
check "l'atelier est toujours dans PostgreSQL" test "$(count_workshop)" = "1"
check "l'application répond de nouveau 200, sans redémarrage" wait_http_200 "$URL/api/workshops"

step "Suppression du pod de l'application : Kubernetes doit le recréer"
kubectl delete pod -n "$NS" -l app=workshop-organizer-app >/dev/null
check "l'application est de nouveau prête" kubectl rollout status -n "$NS" "$APP" --timeout=120s
check "l'application répond 200 et retrouve les données" wait_workshop_listed

# ---------- Résultat ----------
echo
echo "Résultat : $PASS réussi(s), $FAIL échec(s)"
if [ "$FAIL" -gt 0 ]; then
	echo "Pour diagnostiquer : relancer avec --keep, puis  kubectl logs -n <namespace> $APP" >&2
	exit 3
fi
