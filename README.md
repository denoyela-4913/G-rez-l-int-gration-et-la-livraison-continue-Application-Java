# Workshop Organizer Web API

Welcome to the Workshop Organizer Web API! This application is designed to facilitate workshops open to the public. Whether you’re organizing coding bootcamps, art classes, or any other type of workshop, this API will help manage registrations, schedules, and resources.

## Table of Contents

1. Context
2. Technical Overview
3. Building and Running
4. Testing
5. Packaging
6. Publishing to GitLab Registry

## Context

Workshops play a crucial role in fostering learning and collaboration. Our application aims to streamline the workshop organization process, making it easier for organizers to manage participants, sessions, and materials. Whether you're a seasoned workshop host or just starting out, this API has got you covered!

## Technical Overview

- **Java Development Kit (JDK):** We use **JDK 21**, tested with **Adoptium**, to power our application.
- **Database:** Our backend relies on a **PostgreSQL 13** database for data storage.
- **Build Tool:** We leverage **Gradle 8.7** for managing dependencies and building the project.
- **Spring Boot:** Our application is based on **Spring Boot 3.2.4**, which provides a robust framework for creating RESTful APIs.
- **Application Server:** Our application can run on Tomcat server that require version 10.1.24.

## Building and Running

To compile and run the application locally, follow these steps:

1. Ensure you have JDK 21 installed.
2. Clone this repository.
3. Navigate to the project root directory.
4. Execute the following command to compile the Java code :
   ```bash
   ./gradlew clean compileJava
   ```
5. To run the application locally, either:
   Execute the main method in the Application class from your IDE.
   Use the Spring Boot Gradle Plugin :
   ```bash
   ./gradlew bootRun
   ```
   For production, package the application as WAR and use a tomcat server

To run correctly the application with docker after you building it with tag workshop-organizer, run the following

```bash
docker compose up -d
```

## Configuration

You can configure the application with these environment variables

- SPRING_DATASOURCE_URL: JDBC URI for DB access (ex. jdbc:postgresql://db:5432/mydatabase)
- SPRING_DATASOURCE_USERNAME: Database user name used by the application
- SPRING_DATASOURCE_PASSWORD: Database user password used by the application

## Testing

We take testing seriously! To verify the correctness of our application, run the following command:

```bash
./gradlew clean test
```

During execution junit reports are generated in the `build/test-results/test` folder.

## Packaging

When you’re ready to package the application for deployment, create a deployable WAR file:

```bash
./gradlew bootWar
```

The generated war file can be used with many application servers such as Tomcat, Wildfly...

## Publishing to GitLab Registry

To publish your application to a GitLab registry, follow these steps:

1. Set up your GitLab project.
2. Ensure you have the following environment variables configured:

   - GITLAB_PROJECT_ID: The ID of your GitLab project.
   - GITLAB_TOKEN_NAME: The name of the GitLab access token.
   - GITLAB_TOKEN: Your GitLab access token.

3. Execute the following command to publish your application:
   ```bash
   ./gradlew publish
   ```
   Remember to replace placeholders with actual values specific to your project.

Feel free to enhance this README with additional details, such as API endpoints, security considerations, and deployment instructions. Happy organizing! 🚀

## CI : build et publication de l'image Docker

Le workflow `.github/workflows/ci.yml` comporte trois jobs : `test` (tests unitaires), `release`
(calcul de la version, voir « Releases et versions » plus bas) puis `build` (construction, test de
fonctionnement et publication de l'image sur GHCR, le GitHub Container Registry). Les jobs `release` et
`build` ne tournent que sur un `push` (et `release` uniquement sur `main`), après la réussite de `test`.

Chaque image reçoit deux tags : `<branche>` (mobile : dernier commit de la branche) et
`<branche>-<sha7>` (immuable : commit exact). Les caractères interdits d'un tag Docker sont remplacés
(`feature/Ma-Branche` devient `feature-ma-branche`). Exemple :
`ghcr.io/<utilisateur>/<dépôt>:main-2f0ba4c`.

Configuration : la variable de dépôt `IMAGE_NAME` (Settings > Secrets and variables > Actions >
Variables) remplace le nom d'image par défaut (le nom du dépôt). Aucun secret à créer : le job utilise
le `GITHUB_TOKEN` avec la permission `packages: write`.

Pour valider le pipeline sans toucher à `main`, pousser une branche de test : l'image est publiée avec
le tag de cette branche.

### Différences entre les projets Angular et Java

| | Angular (Olympic Tracker) | Java (Workshop Organizer) |
|---|---|---|
| Image finale | `nginx:1.27-alpine` + fichiers statiques | `eclipse-temurin:21-jre-alpine` + jar Spring Boot |
| Étape de build dans le Dockerfile | `npm ci` puis `npm run build` | `./gradlew bootJar` |
| Port du conteneur | 8080 (Nginx) | 8080 (Spring Boot) |
| Utilisateur non-root (UID) | 10002 | 10001 |
| Dépendance au runtime | aucune | PostgreSQL (service `db`) |
| Test de fonctionnement en CI | `docker run`, puis `curl` sur `/`, sur une route inconnue (repli vers `index.html`) et sur `/assets/mock/olympic.json`, et contrôle de l'UID | `docker compose up --no-build --wait` (app + db) puis `curl` sur `/` et contrôle de l'UID |
| Version applicative | pas de version dans l'image | `ARG APP_VERSION` du Dockerfile (jar nommé d'après `build.gradle`) |

### Local et CI : ce qui diffère

- La CI part d'un runner vierge : aucun cache de couches Docker, donc la première construction est plus
  longue qu'en local.
- Le nom d'image est calculé à partir du dépôt et mis en minuscules (GHCR l'exige). En local,
  `docker compose` utilise un nom court (`olympic-games-tracker`, `workshop-organizer`).
- Le test de la CI exécute l'image qui sera publiée (et non une reconstruction) : ce qui est testé est
  ce qui est livré.

## Releases et versions

La version de l'application est calculée automatiquement par
[semantic-release](https://semantic-release.org/) à chaque push sur `main`, à partir des messages de
commit. Elle n'est plus modifiée à la main : `build.gradle` et `Dockerfile` sont mis à jour par la CI
(avec `update_version.sh`).

### Écrire ses messages de commit

Le format est `type: description` (Conventional Commits). Le type décide de la version suivante :

| Message de commit | Effet | Exemple (depuis 0.2.4) |
|---|---|---|
| `fix: ...` | version corrective (patch) | 0.2.5 |
| `feat: ...` | nouvelle fonctionnalité (minor) | 0.3.0 |
| `feat!: ...` ou `BREAKING CHANGE:` dans le corps | changement cassant (major) | 1.0.0 |
| `docs:`, `ci:`, `chore:`, `test:`, `build:`, `refactor:` | aucune release | inchangée |

Un push sur `main` sans `feat:` ni `fix:` depuis le dernier tag ne crée donc aucune version.

### Ce que fait la CI à chaque release

1. Le job `release` crée le commit `chore(release): X.Y.Z [skip ci]` (mise à jour de `build.gradle` et du
   `Dockerfile`), le tag `vX.Y.Z` et la release GitHub avec ses notes.
2. Le job `build` construit ce tag et publie l'image avec ses tags habituels et le tag `X.Y.Z`.

Le `[skip ci]` empêche la CI de se relancer sur le commit de version. Après une release, penser à faire
`git pull` avant de pousser : la CI a ajouté un commit sur `main`.

### Simuler une release sans rien créer

```bash
npx --yes -p semantic-release@25.0.9 -p @semantic-release/commit-analyzer@13.0.1 \
  -p @semantic-release/release-notes-generator@14.1.1 -p @semantic-release/exec@7.1.0 \
  -p @semantic-release/git@11.0.1 -p @semantic-release/github@12.0.10 \
  -p conventional-changelog-conventionalcommits@9.3.1 \
  semantic-release --dry-run --no-ci
```

Il affiche la version qui serait créée (ou « no release »). Il doit être lancé depuis `main`, avec la
variable `GITHUB_TOKEN` définie (par exemple `GITHUB_TOKEN=$(gh auth token)`).
