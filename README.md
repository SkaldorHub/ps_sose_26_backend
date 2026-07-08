# GeoGame Backend

Vapor-Backend für die GeoGame iOS App.

## Stack

| Komponente | Technologie |
|---|----------------------------------------|
| Framework | [Vapor 4](https://vapor.codes) (Swift) |
| Datenbank | PostgreSQL 18 |
| ORM | Fluent (PostgreSQL Driver) |
| Foto-Storage | MinIO (S3-kompatibel) |

## Setup
### 0. Voraussetzungen

- Docker & Docker Compose ([How to Install](https://docs.docker.com/engine/install/))

### 1. Image bauen &  Services starten

``docker compose up --build -d``

Migrations werden automatisch vor dem App-Start ausgeführt.

## Deploy to Server
### 0. Voraussetzung
- rsync
### 1. Instanz stoppen
In `~/geoguesser_backend` ausführen: ``docker compose down``

### 2. Verzeichnis kopieren
Der Befehl soll innerhalb des Projektverzeichnis ausgeführt werden

``rsync -av --exclude='.build' --exclude='*.d' --exclude='*.dia' . local@141.45.191.253:~/geoguesser_backend/``
### 3. Setup
Hier dann die Schritte des Setup nachholen

### 4. Starten
`migrate` und `app` bauen aus demselben Dockerfile das gleiche Image (`ps-backend:latest`). Bei leerem BuildKit-Cache (z.B. nach `docker system prune -a --volumes`) baut Compose beide Services parallel, wodurch zwei `swift build`-Prozesse gleichzeitig in denselben `.build`-Cache-Mount schreiben und mit `multiple producers` fehlschlagen können.

Deshalb Image zuerst einmal seriell bauen, danach ohne `--build` starten:

```
docker compose build app
docker compose up -d
```

# Development Infos

## Umgebungsvariablen

| Variable            | Beschreibung              | Default                 |
|---------------------|---------------------------|-------------------------|
| `DATABASE_NAME`     | PostgreSQL Database       | `ps_database`           |
| `DATABASE_HOST`     | PostgreSQL Host           | `db`                    |
| `DATABASE_USERNAME` | PostgreSQL Login User     | `ps_username`           |
| `DATABASE_PASSWORD` | PostgreSQL Login Password | `ps_password`           |
| `MINIO_ENDPOINT`    | MinIO URL           | `http://minio:9000`     |
| `MINIO_USER`        | MinIO Username      | `minioadmin`            |
| `MINIO_SECRET`      | MinIO Secret Key    | `minioadmin`            |
| `MINIO_BUCKET`      | Bucket für Fotos    | `photos`                |

Überschreiben ist möglich über bspw. `export DATABASE_PASSWORD=secret` oder ein `.env` file, welches dann per `source .env` geladen wird.

## Projektstruktur

```
backend/
├── Sources/
│   └── ps_backend/
│       ├── Controllers/       # Request Handler (Lobby, Round, User, ...)
│       ├── Models/            # Fluent Models & Migrations
│       ├── DTOs/              # Request/Response Structs (Codable)
│       ├── Services/          # Business Logic (z.B. Score-Berechnung, MinIO)
│       ├── WebSockets/        # WebSocket Handler & Message-Typen
│       ├── Middleware/        # Auth, Logging, ...
│       ├── configure.swift    # App-Konfiguration, DB, Migrations
│       └── routes.swift       # Alle Routen registriert
├── Tests/
│   └── AppTests/
├── Package.swift
├── docker-compose.yml # Container Stack (MinIO, PostgreSQL, Backend)
└── Dockerfile # Vapor Standard Dockerfile
```

## Teststrategie

Für den Backend Services sind E2E-Tests geplant, welche definierte User Gameflows durchgehen.

- Spiel starten, spielen und erfolgreich beenden
- 4 User spielen (müssen sich neu registrieren)