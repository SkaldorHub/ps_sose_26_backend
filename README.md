# StreetSnap Backend

Vapor-Backend für die StreetSnap iOS App.

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
│       ├── Models/            # Fluent Models
│       ├── Migrations/        # Fluent Migrations
│       ├── DTOs/              # Request/Response Structs (Codable)
│       ├── Services/          # Business Logic (z.B. Score-Berechnung, MinIO)
│       ├── Middleware/        # Auth, Logging, ...
│       ├── Docs/              # Zusatzdokumentation (z.B. Datenbankschema)
│       ├── openapi.yaml       # Source of Truth für alle Endpunkte
│       ├── configure.swift    # App-Konfiguration, DB, Migrations
│       └── routes.swift       # Alle Routen registriert
├── Tests/
│   └── AppTests/
├── Package.swift
├── docker-compose.yml # Container Stack (MinIO, PostgreSQL, Backend)
└── Dockerfile # Vapor Standard Dockerfile
```

## Teststrategie

E2E-Tests, die komplette Gameflows durchspielen, liegen im Frontend-Repo
(`ps_sose_26/scripts/e2e_test.sh`) und laufen wahlweise gegen dieses Backend
lokal (`docker compose up`) oder gegen ein Remote-Deployment.

## Dokumentation

- [Datenbankschema](Sources/ps_backend/Docs/DATABASE.md) — ER-Diagramm & Tabellenübersicht

## Lizenz

Copyright (C) 2026 StreetSnap contributors

AGPLv3 — siehe [LICENSE](LICENSE). Insbesondere: wer eine modifizierte Version
dieses Backends als Netzwerkdienst betreibt, muss den entsprechenden
Quellcode allen Nutzer:innen dieses Dienstes zugänglich machen (§13 AGPLv3).