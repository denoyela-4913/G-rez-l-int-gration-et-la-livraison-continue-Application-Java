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
| Version applicative | `version` de `package.json` (mise à jour par la CI) ; l'image reçoit le tag `X.Y.Z` | `ARG APP_VERSION` du Dockerfile et `version` de `build.gradle` (mis à jour par la CI via `update_version.sh`) ; l'image reçoit le tag `X.Y.Z` |

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
(avec `update_version.sh`). Le même script met aussi à jour le tag de l'image dans `values-dev.yaml`.

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

## Déploiement sur Kubernetes (Minikube) et Helm

Deux façons de déployer l'application et sa base PostgreSQL, qui donnent le même résultat en développement :

| | Dossier | Quand l'utiliser |
|---|---|---|
| Manifestes | `k8s/` | déploiement direct : `kubectl apply -f k8s/` |
| Chart Helm | `charts/workshop-organizer/` | plusieurs environnements (dev, staging) avec des valeurs différentes |

Le rendu du chart avec `values-dev.yaml` est identique aux manifestes de `k8s/` (hors étiquettes), à une
variable près : le chart ajoute `PGPORT` pour que `db.port` soit réellement pris en compte par PostgreSQL.

### Le chart Helm

Le schéma des valeurs reprend celui de `values.tpl.yaml` (`app.*` et `db.*`), complété par `app.replicas`,
`db.persistence.*` et `service.*`.

| Valeur | `values-dev.yaml` | `values-staging.yaml` | Rôle |
|---|---|---|---|
| `app.image` | `...:0.3.1` | `...:0.3.1` | image complète, **tag compris** ; obligatoire (le chart refuse de s'installer sans) |
| `app.replicas` | 1 | 1 | nombre de pods de l'application |
| `app.imagePullSecret` | (vide) | (vide) | Secret docker-registry pour un registre **privé** ; le paquet GHCR étant public, il n'est pas utilisé |
| `db.password` | `oc2024` (dev uniquement) | **aucun : à fournir** | obligatoire ; lu par la base et l'application depuis le même Secret |
| `db.persistence.size` | 1Gi | 2Gi | taille du volume de la base |
| `service.port` | 8080 | 8082 | port du Service sur la machine |

Les autres valeurs (`db.image`, `db.port`, `db.username`, `db.database`, `db.persistence.enabled`,
`db.persistence.storageClass`, `service.type`) ont une valeur par défaut dans `values.yaml`.

Staging est sur le port **8082** pour que dev et staging puissent être installés et joignables en même temps :
avec `minikube tunnel`, deux Services sur le même port se partagent le même port de la machine, et l'un masque
l'autre (8081 est déjà utilisé par le staging du dépôt Angular). Ces ports ne sont pas privilégiés : pas de `sudo`.

```bash
helm install workshop charts/workshop-organizer -f charts/workshop-organizer/values-dev.yaml -n workshop-dev --create-namespace
helm install workshop charts/workshop-organizer -f charts/workshop-organizer/values-staging.yaml --set db.password='<mot de passe>' -n workshop-staging --create-namespace
helm list -A                                   # releases installées
helm upgrade workshop charts/workshop-organizer -f charts/workshop-organizer/values-staging.yaml --set db.password='<mot de passe>' -n workshop-staging --set app.replicas=2
helm history workshop -n workshop-staging      # révisions
helm rollback workshop 1 -n workshop-staging   # retour à la révision 1
helm uninstall workshop -n workshop-dev
```

Vérifier un chart sans rien installer : `helm lint charts/workshop-organizer -f charts/workshop-organizer/values-dev.yaml`
(syntaxe) et `helm template workshop charts/workshop-organizer -f charts/workshop-organizer/values-dev.yaml` (rendu).

### Le mot de passe de la base

- Le fichier de dev contient un mot de passe de **développement** (celui de `docker-compose.yml`). Un mot de
  passe réel ne doit pas être versionné dans Git : pour staging, il est fourni à l'installation avec `--set`.
- **PostgreSQL ne lit `POSTGRES_PASSWORD` qu'à la création de la base.** Faire `helm upgrade` avec un autre
  mot de passe met à jour le Secret, mais pas le mot de passe réel stocké dans le volume. Rien ne se
  voit tant que les pods ne redémarrent pas ; au prochain redémarrage de l'application, elle lit le nouveau
  mot de passe et PostgreSQL le refuse (`password authentication failed`). Pour changer un mot de passe déjà
  en place, il faut le changer dans PostgreSQL (`ALTER USER`) **et** dans le Secret, ou recréer le volume.

### Persistance des données

Par défaut, la base écrit dans un volume persistant (`db.persistence.enabled: true`) et ses données survivent à
la suppression du pod. Avec `--set db.persistence.enabled=false`, elle utilise un dossier temporaire : les
données disparaissent avec le pod. Supprimer le namespace (ou le PVC) supprime aussi le volume et ses données.

### Mettre à jour la version déployée

Le tag de l'image est dans `app.image` de chaque fichier de valeurs (et `appVersion` dans `Chart.yaml`, à titre
informatif). Il se met à jour différemment selon l'environnement :

- **dev : automatique.** À chaque release, `update_version.sh` (lancé par semantic-release) réécrit le tag de
  `values-dev.yaml`, qui part dans le commit `chore(release)`. Il reste à lancer `helm upgrade` pour que le
  cluster suive.
- **staging : à la main.** `values-staging.yaml` n'est jamais modifié par la CI : staging ne change de version
  que sur décision. Pour promouvoir, recopier dans `values-staging.yaml` un tag déjà passé en dev, puis
  `helm upgrade`.

### Sondes de santé

| Composant | Sonde | Test | Si elle échoue |
|---|---|---|---|
| Application | `startupProbe` | `GET /` (2 s x 30 essais = 60 s de marge) | le conteneur est redémarré ; `readiness` et `liveness` sont suspendues pendant ce temps |
| Application | `readinessProbe` | `GET /` toutes les 5 s, 3 échecs | le pod est **retiré du Service** (aucune requête), sans redémarrage |
| Application | `livenessProbe` | `GET /` toutes les 10 s, 3 échecs | le conteneur est **redémarré** |
| Base | `readinessProbe` | `pg_isready -h 127.0.0.1` toutes les 2 s | le pod est retiré du Service |

- Les durées sont des valeurs du chart (`app.probes.*`, `db.probes.*`). `enabled: false` supprime les sondes
  d'un composant (comparaison, débogage).
- `GET /` ne vérifie pas la base (l'application n'a pas d'Actuator). La liveness est volontairement sur cette
  route : une route qui dépend de la base ferait **redémarrer toute l'application** à chaque panne de la base.
- La base n'a **pas de liveness** : redémarrer une base sur une fausse alerte est plus risqué que d'attendre
  (avec `db.persistence.enabled=false`, ce serait une perte de données).
- `pg_isready` est appelé avec `-h 127.0.0.1` (TCP) : pendant son initialisation, l'image PostgreSQL démarre un
  serveur temporaire **sans TCP**. Sans `-h`, la sonde répondrait « prêt » alors que la base n'existe pas encore.
- Un **`preStop`** (`app.preStopSeconds`, 5 s par défaut) fait attendre l'ancien pod avant son arrêt, lors d'une mise
  à jour : le Service n'a pas encore fini de le retirer de sa liste, et sans pause les requêtes qui lui sont encore
  envoyées échouent. `0` supprime la pause.
- Un **init container** `wait-for-db` attend que la base accepte les connexions avant de lancer l'application.
  Sans lui, comme le Service de la base n'a d'adresse que lorsque la base est prête, l'application démarrait
  avant et était redémarrée une fois à chaque installation (mesuré : 1 redémarrage à chaque essai, 3 essais sur 3 ;
  0 avec l'init container).

Mesures sur Minikube (voir la PR) :

- **Base** : sans sonde, le pod est déclaré prêt 1,4 à 3,3 s **avant** que PostgreSQL accepte une requête SQL ;
  avec la sonde (période de 2 s), il est déclaré prêt 1,3 à 1,7 s **après**. Avec une période de 5 s, ce retard
  était de 4 à 5 s.
- **Mise à jour de l'application** (`rollout restart`, une réplique, requêtes toutes les 0,1 s) : ≈ 3,1 s de coupure
  sans sondes (14 échecs sur ~185 requêtes), ≈ 2 s avec les sondes seules (4 échecs : elles évitent d'envoyer du
  trafic à un pod pas encore prêt, mais l'ancien pod s'arrête avant que le Service ait fini de le retirer de sa
  liste), et **aucune coupure avec les sondes et le `preStop`** (0 échec sur 3 essais).
- **JVM figée** (`SIGSTOP`) : retirée du Service au bout de ~15 s (readiness), redémarrée par la liveness.

### Accès avec `minikube tunnel`

Lancer `minikube tunnel` dans un autre terminal et le laisser ouvert : le Service reçoit alors une adresse
externe (`127.0.0.1`) et l'application est visible sur `http://localhost:<service.port>`.

### Tester le déploiement

```bash
scripts/test-k8s-deploy.sh                    # manifestes de k8s/
scripts/test-k8s-deploy.sh --helm dev         # chart Helm, environnement dev (port 8080)
scripts/test-k8s-deploy.sh --helm staging     # chart Helm, environnement staging (port 8082)
```

Le script vérifie les prérequis (affiche les commandes à lancer s'il en manque), déploie dans un namespace
jetable, teste l'application par le Service, l'écriture dans la base et la survie des données à la suppression
des pods, puis supprime le namespace (`--keep` le conserve, `--pause` attend Entrée entre les étapes). En mode
`--helm`, il passe un mot de passe aléatoire avec `--set` et vérifie qu'il est bien celui du Secret.
