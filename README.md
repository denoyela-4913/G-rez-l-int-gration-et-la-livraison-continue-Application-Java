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

Le workflow `.github/workflows/ci.yml` comporte deux jobs : `test` (tests unitaires) puis `build`
(construction, test de fonctionnement et publication de l'image sur GHCR, le GitHub Container
Registry). Le job `build` ne tourne que sur un `push` et seulement si `test` a réussi.

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
