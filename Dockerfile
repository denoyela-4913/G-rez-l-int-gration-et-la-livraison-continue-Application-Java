# Image de l'application workshop-organizer (Spring Boot, Java 21).
# Build : docker compose build   (tag : workshop-organizer:latest, ou :<version> si APP_VERSION est définie)
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

# Version de l'application : NE PAS MODIFIER À LA MAIN, utiliser ./update_version.sh
# Elle doit être identique à "version" dans build.gradle : le jar est nommé d'après
# build.gradle, donc en cas d'écart le COPY ci-dessous échoue (fichier introuvable).
ARG APP_VERSION=0.2.4

# Pas de --chown : le jar reste propriétaire root, donc en lecture seule pour "workshop".
COPY --from=build /workspace/build/libs/workshop-organizer-${APP_VERSION}.jar app.jar
LABEL org.opencontainers.image.version="${APP_VERSION}"

# UID numérique (et non le nom) pour que Kubernetes puisse vérifier runAsNonRoot.
USER 10001:10001

# Documentation du port d'écoute (la publication se fait dans docker-compose.yml / k8s).
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
