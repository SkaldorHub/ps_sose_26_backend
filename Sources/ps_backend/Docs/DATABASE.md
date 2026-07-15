# Datenbankdokumentation

## Schema

```mermaid
erDiagram
    USERS ||--o{ GAMES : hosts
    USERS ||--o{ TEAM_MEMBERS : joins
    USERS ||--o{ ROUND_PHOTOGRAPHERS : "assigned as"
    USERS ||--o{ PHOTOS : takes
    USERS ||--o{ GUESSES : makes

    GAMES ||--o{ ROUNDS : has
    GAMES ||--o{ TEAM_MEMBERS : has
    GAMES ||--o{ PARTICIPATES : has

    TEAMS ||--o{ TEAM_MEMBERS : has
    TEAMS ||--o{ PARTICIPATES : has
    TEAMS ||--o{ ROUND_RESULTS : has
    TEAMS ||--o{ ROUND_PHOTOGRAPHERS : has

    ROUNDS ||--o{ ROUND_PHOTOGRAPHERS : has
    ROUNDS ||--o{ ROUND_RESULTS : has
    ROUNDS ||--o{ GUESSES : has
    ROUNDS ||--o{ PHOTOS : has

    USERS {
        uuid id PK
        string username
        string password_hash
    }

    GAMES {
        uuid id PK
        uuid host_id FK
        string state
        timestamp started_at
        timestamp finished_at
        string code
        string name
        int total_rounds
        int max_players
        int upload_phase_seconds
        int guessing_phase_seconds
        int photo_view_seconds
        int set_marker_seconds
        timestamp created_at
    }

    TEAMS {
        uuid id PK
        string name
    }

    TEAM_MEMBERS {
        uuid id PK
        uuid team_id FK
        uuid user_id FK
        uuid game_id FK
        timestamp joined_at
    }

    ROUNDS {
        uuid id PK
        uuid game_id FK
        int round_number
        string current_phase
        timestamp deadline
    }

    ROUND_PHOTOGRAPHERS {
        uuid id PK
        uuid round_id FK
        uuid team_id FK
        uuid user_id FK
    }

    PHOTOS {
        uuid id PK
        uuid round_id FK
        uuid photographer_id FK
        double latitude
        double longitude
        string hint
        string photo_url
    }

    GUESSES {
        uuid id PK
        uuid user_id FK
        uuid round_id FK
        double latitude
        double longitude
        int points
        double distance
        timestamp viewing_deadline
        timestamp guess_deadline
    }

    PARTICIPATES {
        uuid id PK
        uuid game_id FK
        uuid team_id FK
        bool is_winner
    }

    ROUND_RESULTS {
        uuid id PK
        uuid round_id FK
        uuid team_id FK
        int team_points
    }
```

## Tabellen
| Tabelle | Beschreibung |
|---|---|
| users | Speichert Benutzerkonten mit Anmeldedaten |
| teams | Repräsentiert Teams, jedes Team hat einen Namen |
| team_members | Verknüpft Spieler mit Teams innerhalb eines Spiels |
| games | Repräsentiert eine Spielsitzung, gehostet von einem Benutzer |
| rounds | Repräsentiert einzelne Runden innerhalb eines Spiels |
| round_photographers | Verknüpft die pro Runde und Team rotierend zugeteilte fotografierende Person |
| photos | Fotos die von Fotografen während der Upload-Phase aufgenommen werden |
| guesses | Standortschätzungen von Benutzern während einer Runde |
| participates | Verknüpft Teams mit Spielen und speichert den Gewinner |
| round_results | Speichert die Punkte eines Teams pro Runde |

## Enums
**Spielstatus** (`games.state`)
- `lobby` – Spiel wurde erstellt, Spieler können noch beitreten
- `running` – Spiel läuft gerade
- `gameOver` – Spiel ist beendet

**Rundenphase** (`rounds.current_phase`)
- `upload` – Fotografen laden Fotos hoch
- `guess` – Teams sehen das Foto des Gegners und setzen ihren Tipp auf der Karte
- `calculateResults` – Runde ist beendet, Punkte wurden berechnet
