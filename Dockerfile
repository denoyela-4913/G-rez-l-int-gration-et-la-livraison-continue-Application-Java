# Image de l'application workshop-organizer (Spring Boot, Java 21).
# Build : docker compose build   (le tag vient de APP_VERSION dans .env)
# Build multi-stage : le JDK et les sources restent dans l'étape "build",
# seul le jar est copié dans l'image finale (plus légère, moins de surface d'attaque).

# ---------- Étape 1 : compilation du jar ----------
FROM eclipse-temurin:21-jdk AS build
WORKDIR /workspace

# Les fichiers Gradle d'abord : tant qu'ils ne changent pas, la couche des
# dépendances reste en cache et n'est pas retéléchargée à chaque modification du code.
COPY gradlew build.gradle settings.gradle ./
COPY gradle gradle
RUN ./gradlew dependencies --no-daemon > /dev/null 2>&1 || true

# Les sources ensuite (src/ contient aussi la spec OpenAPI utilisée pour générer du code).
# .env est copié ici (après la couche des dépendances) car build.gradle y lit APP_VERSION :
# changer la version ne relance donc pas le téléchargement des dépendances.
COPY .env .
COPY src src
RUN ./gradlew bootJar -x test --no-daemon

# ---------- Étape 2 : image d'exécution ----------
# Alpine : image minimale (JRE seul). Les commandes addgroup/adduser sont celles de BusyBox.
FROM eclipse-temurin:21-jre-alpine

# /app est créé par root : l'utilisateur "workshop" peut lire le jar mais pas le modifier.
WORKDIR /app

# Utilisateur non-root avec UID/GID fixes (10001), sans mot de passe (-D), sans home (-H)
# et sans shell (nologin). UID fixe = droits prévisibles (volumes, runAsUser dans Kubernetes).
# Convention : 10001 = workshop (java), 10002 = application Angular.
RUN addgroup -g 10001 workshop \
 && adduser -D -H -u 10001 -G workshop -s /sbin/nologin workshop

# Pas de --chown : le jar reste propriétaire root, donc en lecture seule pour "workshop".
COPY --from=build /workspace/build/libs/*.jar app.jar

# UID numérique (et non le nom) pour que Kubernetes puisse vérifier runAsNonRoot.
USER 10001:10001

# Documentation du port d'écoute (la publication se fait dans docker-compose.yml / k8s).
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
