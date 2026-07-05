#!/usr/bin/env bash
#
# End-to-End-Tests gegen die laufende ps_backend-API (kein XCTest, kein Mocking -
# echte HTTP-Requests gegen den docker-compose-Stack, siehe CLAUDE.md/Memory
# "Teststrategie": E2E-Workflows statt Unit-Tests).
#
# Voraussetzungen: docker, docker compose, curl, jq, xxd.
# Nutzung:
#   ./Tests/ps_backendTests/e2e.sh
#   BASE_URL=http://localhost:8080 ./Tests/ps_backendTests/e2e.sh
#
# Startet den Stack per `docker compose up --build -d`, falls er nicht schon läuft.
# Jeder Lauf legt neue User/Games mit eindeutigem Suffix an (keine Kollisionen bei
# wiederholter Ausführung, aber auch kein automatisches Aufräumen der Testdaten).

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
BASE_URL="${BASE_URL:-http://localhost:8080}"
DB_USER="${DATABASE_USERNAME:-pssose26_admin}"
DB_NAME="${DATABASE_NAME:-ps_database}"
RUN_ID="$(date +%s)"

PASS=0
FAIL=0

# 1x1-PNG (rotes Pixel) als Testbild, hex-kodiert um ohne Binärdatei im Repo auszukommen.
TEST_PNG_HEX="89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000c49444154789c63f8cfc0000003010100c9fe92ef0000000049454e44ae426082"
TEST_PNG="$(mktemp -t e2e-photo.XXXXXX).png"
xxd -r -p <<<"$TEST_PNG_HEX" >"$TEST_PNG"
trap 'rm -f "$TEST_PNG"' EXIT

log()  { echo "[e2e] $*"; }
pass() { PASS=$((PASS + 1)); echo "  OK   $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $* "; }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then pass "$desc"; else fail "$desc (expected '$expected', got '$actual')"; fi
}

assert_true() {
  local desc="$1" condition="$2"
  if [ "$condition" = "true" ]; then pass "$desc"; else fail "$desc"; fi
}

db_exec() {
  docker compose -f "$REPO_ROOT/docker-compose.yml" exec -T db psql -U "$DB_USER" -d "$DB_NAME" -tAc "$1"
}

api() {
  # api METHOD PATH [TOKEN] [BODY-JSON]
  local method="$1" path="$2" token="${3:-}" body="${4:-}"
  local args=(-s -w '\n%{http_code}' -X "$method" "$BASE_URL$path" -H 'Content-Type: application/json')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$body" ] && args+=(-d "$body")
  curl "${args[@]}"
}

# Führt api() aus, setzt HTTP_BODY / HTTP_CODE als globale Variablen (spart Subshell-Parsing).
call() {
  local response
  response="$(api "$@")"
  HTTP_CODE="${response##*$'\n'}"
  HTTP_BODY="${response%$'\n'*}"
}

wait_for_stack() {
  if curl -s -o /dev/null "$BASE_URL/games/00000000-0000-0000-0000-000000000000"; then
    return
  fi
  log "Stack nicht erreichbar, starte docker compose up --build -d ..."
  (cd "$REPO_ROOT" && docker compose up --build -d)
  for _ in $(seq 1 60); do
    curl -s -o /dev/null "$BASE_URL/games/00000000-0000-0000-0000-000000000000" && return
    sleep 2
  done
  echo "Stack nach 120s nicht erreichbar, breche ab." >&2
  exit 1
}

force_active_round_deadline_past() {
  # nur die tatsächlich aktive Runde (niedrigste roundNumber, die noch nicht calculateResults ist) -
  # spätere Runden liegen mit deadline=NULL "schlafend" vor und dürfen nicht mit-getriggert werden.
  local game_id="$1"
  db_exec "UPDATE rounds SET deadline = now() - interval '1 minute' WHERE id = (
    SELECT id FROM rounds WHERE game_id = '$game_id' AND current_phase != 'calculateResults'
    ORDER BY round_number ASC LIMIT 1
  );" >/dev/null
}

wait_for_phase() {
  # wait_for_phase GAME_ID TOKEN EXPECTED_PHASE
  local game_id="$1" token="$2" expected="$3"
  for _ in $(seq 1 12); do
    call GET "/games/$game_id/current" "$token"
    [ "$(echo "$HTTP_BODY" | jq -r '.phase')" = "$expected" ] && return 0
    sleep 10
  done
  echo "Timeout: Phase '$expected' nicht erreicht (game=$game_id)" >&2
  return 1
}

run_remaining_rounds_to_finish() {
  # Jede verbleibende Runde braucht 2 Scheduler-Ticks (upload->guess, guess->calculateResults),
  # der Scheduler läuft alle 60s -> für bis zu 5 Runden (10 Ticks) reichlich Budget einplanen.
  local game_id="$1" token="$2"
  for _ in $(seq 1 50); do
    force_active_round_deadline_past "$game_id"
    call GET "/games/$game_id" "$token"
    [ "$(echo "$HTTP_BODY" | jq -r '.status')" = "finished" ] && return 0
    sleep 15
  done
  return 1
}

wait_for_game_status() {
  # wait_for_game_status GAME_ID TOKEN EXPECTED_STATUS
  local game_id="$1" token="$2" expected="$3"
  for _ in $(seq 1 12); do
    call GET "/games/$game_id" "$token"
    [ "$(echo "$HTTP_BODY" | jq -r '.status')" = "$expected" ] && return 0
    sleep 10
  done
  echo "Timeout: Game-Status '$expected' nicht erreicht (game=$game_id)" >&2
  return 1
}

register() {
  # register USERNAME -> setzt TOKEN / USER_ID
  local username="$1"
  call POST /auth/register '' "{\"username\":\"$username\",\"password\":\"secret123\"}"
  TOKEN="$(echo "$HTTP_BODY" | jq -r '.token')"
  USER_ID="$(echo "$HTTP_BODY" | jq -r '.userId')"
}

create_game_with_two_players() {
  # create_game_with_two_players TOKEN_A TOKEN_B -> setzt GAME_ID, TEAM_OF_A, TEAM_OF_B
  local token_a="$1" token_b="$2"
  call POST /games "$token_a" '{"name":"E2E-Testspiel"}'
  GAME_ID="$(echo "$HTTP_BODY" | jq -r '.id')"
  local code
  code="$(echo "$HTTP_BODY" | jq -r '.code')"

  call POST /games/join "$token_b" "{\"code\":\"$code\"}"
  call POST "/games/$GAME_ID/start" "$token_a"

  echo "DEBUG /teams response: $HTTP_BODY"

  call GET "/games/$GAME_ID/teams" "$token_a"
  TEAM_OF_A="$(echo "$HTTP_BODY" | jq -r --arg u "$USERNAME_A" '.[] | select(.players[].username == $u) | .id')"
  TEAM_OF_B="$(echo "$HTTP_BODY" | jq -r --arg u "$USERNAME_B" '.[] | select(.players[].username == $u) | .id')"
}

upload_photo() {
  # upload_photo TOKEN GAME_ID LAT LNG
  curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/games/$2/current/photo" \
    -H "Authorization: Bearer $1" -F "photo=@$TEST_PNG" -F "lat=$3" -F "lng=$4"
}

# ─────────────────────────────────────────────
# Test: Auth
# ─────────────────────────────────────────────
test_auth() {
  log "Test: Auth (register/login/duplicate/wrong-password)"
  local username="e2e_auth_${RUN_ID}"

  call POST /auth/register '' "{\"username\":\"$username\",\"password\":\"secret123\"}"
  assert_eq "register -> 201" "201" "$HTTP_CODE"
  assert_true "register liefert Token" "$([ -n "$(echo "$HTTP_BODY" | jq -r '.token')" ] && echo true || echo false)"

  call POST /auth/register '' "{\"username\":\"$username\",\"password\":\"secret123\"}"
  assert_eq "register mit vergebenem Username -> 400" "400" "$HTTP_CODE"

  call POST /auth/login '' "{\"username\":\"$username\",\"password\":\"falsches-passwort\"}"
  assert_eq "login mit falschem Passwort -> 401" "401" "$HTTP_CODE"

  call POST /auth/login '' "{\"username\":\"$username\",\"password\":\"secret123\"}"
  assert_eq "login -> 200" "200" "$HTTP_CODE"
}

# ─────────────────────────────────────────────
# Test: Kompletter Spieldurchlauf mit klarem Gewinner
# ─────────────────────────────────────────────
test_full_game_with_winner() {
  log "Test: Kompletter Rundendurchlauf (Upload -> Guess -> Ergebnis) mit Punktedifferenz"
  USERNAME_A="e2e_alice_${RUN_ID}"
  USERNAME_B="e2e_bob_${RUN_ID}"
  register "$USERNAME_A"; local token_a="$TOKEN"
  register "$USERNAME_B"; local token_b="$TOKEN"

  create_game_with_two_players "$token_a" "$token_b"
  local game_id="$GAME_ID"

  call GET "/games/$game_id/current" "$token_a"
  assert_eq "getCurrentRound zeigt Runde 1 (nicht die zuletzt angelegte)" "1" "$(echo "$HTTP_BODY" | jq -r '.roundNumber')"
  assert_eq "Runde 1 ist in Upload-Phase" "upload" "$(echo "$HTTP_BODY" | jq -r '.phase')"

  assert_eq "uploadPhoto Team A -> 201" "201" "$(upload_photo "$token_a" "$game_id" 48.137 11.576)"
  assert_eq "uploadPhoto Team B -> 201" "201" "$(upload_photo "$token_b" "$game_id" 48.140 11.580)"

  call GET "/games/$game_id/current/status" "$token_a"
  assert_eq "beide Teams uploaded" "2" "$(echo "$HTTP_BODY" | jq '[.[] | select(.status == "uploaded")] | length')"

  force_active_round_deadline_past "$game_id"
  wait_for_phase "$game_id" "$token_a" "guess"

  # binärer Bildinhalt -> nicht per Command-Substitution als Text einlesen, nur Statuscode prüfen
  local photo_status
  photo_status="$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/games/$game_id/current/photo/$TEAM_OF_B" -H "Authorization: Bearer $token_a")"
  assert_eq "getTeamPhoto (Gegner-Foto) -> 200" "200" "$photo_status"

  # Team A tippt sehr nah (~13m, oberste Bucket-Stufe -> 10 P), Team B deutlich weiter weg (~1450m -> 0 P)
  call POST "/games/$game_id/current/guess" "$token_a" '{"lat":48.1401,"lng":11.5801}'
  assert_eq "submitGuess Team A -> 201" "201" "$HTTP_CODE"
  call POST "/games/$game_id/current/guess" "$token_b" '{"lat":48.150,"lng":11.590}'
  assert_eq "submitGuess Team B -> 201" "201" "$HTTP_CODE"

  call GET "/games/$game_id/current/guesses" "$token_a"
  assert_eq "getGuesses liefert beide Guesses" "2" "$(echo "$HTTP_BODY" | jq 'length')"

  force_active_round_deadline_past "$game_id"
  wait_for_phase "$game_id" "$token_a" "upload"  # Runde 2 ist jetzt aktiv

  call GET "/games/$game_id/current/result" "$token_a"
  assert_eq "getCurrentResult zeigt Runde 1" "1" "$(echo "$HTTP_BODY" | jq -r '.roundNumber')"

  call GET "/games/$game_id/current/leaderboard" "$token_a"
  local score_a score_b
  score_a="$(echo "$HTTP_BODY" | jq -r --arg t "$TEAM_OF_A" '.[] | select(.teamId == $t) | .score')"
  score_b="$(echo "$HTTP_BODY" | jq -r --arg t "$TEAM_OF_B" '.[] | select(.teamId == $t) | .score')"
  assert_eq "Team A (nah getippt) hat 10 Punkte" "10" "$score_a"
  assert_eq "Team B (weit weg getippt) hat 0 Punkte" "0" "$score_b"

  # verbleibende Runden 2-5 ohne weitere Interaktion durchlaufen lassen (0:0 je Runde)
  run_remaining_rounds_to_finish "$game_id" "$token_a" || true
  call GET "/games/$game_id" "$token_a"
  assert_eq "Spiel ist nach 5 Runden 'finished'" "finished" "$(echo "$HTTP_BODY" | jq -r '.status')"

  call GET "/games/$game_id/result" "$token_a"
  assert_eq "Gewinner ist eindeutig Team A" "$TEAM_OF_A" "$(echo "$HTTP_BODY" | jq -r '.winnerTeamId')"
}

# ─────────────────────────────────────────────
# Test: Fehlender Foto-Upload -> 0/10-Regel
# ─────────────────────────────────────────────
test_missing_upload_rule() {
  log "Test: Team ohne Foto-Upload bekommt 0 P, Gegner automatisch 10 P"
  USERNAME_A="e2e_carol_${RUN_ID}"
  USERNAME_B="e2e_dave_${RUN_ID}"
  register "$USERNAME_A"; local token_a="$TOKEN"
  register "$USERNAME_B"; local token_b="$TOKEN"

  create_game_with_two_players "$token_a" "$token_b"
  local game_id="$GAME_ID"

  # nur Team A lädt ein Foto hoch, Team B lässt die Deadline verstreichen
  assert_eq "uploadPhoto Team A -> 201" "201" "$(upload_photo "$token_a" "$game_id" 48.137 11.576)"

  force_active_round_deadline_past "$game_id"
  wait_for_phase "$game_id" "$token_a" "guess"
  force_active_round_deadline_past "$game_id"
  wait_for_phase "$game_id" "$token_a" "upload"

  # Team-Punkte für die fehlende-Upload-Regel landen nur in RoundResult, nicht in den einzelnen
  # Guesses (es gab keine) - daher über das Leaderboard geprüft statt per Guess-Liste.
  call GET "/games/$game_id/current/leaderboard" "$token_a"
  local points_a points_b
  points_a="$(echo "$HTTP_BODY" | jq -r --arg t "$TEAM_OF_A" '.[] | select(.teamId == $t) | .score')"
  points_b="$(echo "$HTTP_BODY" | jq -r --arg t "$TEAM_OF_B" '.[] | select(.teamId == $t) | .score')"
  assert_eq "hochladendes Team bekommt 10 P (Gegner hat nicht hochgeladen)" "10" "$points_a"
  assert_eq "nicht-hochladendes Team bekommt 0 P" "0" "$points_b"
}

# ─────────────────────────────────────────────
# Test: Unentschieden -> kein winnerTeamId
# ─────────────────────────────────────────────
test_tie_break() {
  log "Test: Unentschieden (0:0 über alle Runden) -> winnerTeamId ist null"
  USERNAME_A="e2e_erin_${RUN_ID}"
  USERNAME_B="e2e_frank_${RUN_ID}"
  register "$USERNAME_A"; local token_a="$TOKEN"
  register "$USERNAME_B"; local token_b="$TOKEN"

  create_game_with_two_players "$token_a" "$token_b"
  local game_id="$GAME_ID"

  # niemand lädt jemals ein Foto hoch -> jede Runde endet 0:0 (alle 5 Runden brauchen 10 Ticks)
  run_remaining_rounds_to_finish "$game_id" "$token_a" || true
  call GET "/games/$game_id" "$token_a"
  assert_eq "Spiel ist 'finished'" "finished" "$(echo "$HTTP_BODY" | jq -r '.status')"

  call GET "/games/$game_id/result" "$token_a"
  assert_eq "winnerTeamId ist null bei Gleichstand" "null" "$(echo "$HTTP_BODY" | jq -r '.winnerTeamId')"
}

# ─────────────────────────────────────────────
# Test: replacePhoto/deletePhoto sind entfernt
# ─────────────────────────────────────────────
test_removed_photo_endpoints() {
  log "Test: PUT/DELETE auf /current/photo existieren nicht mehr"
  USERNAME_A="e2e_grace_${RUN_ID}"
  USERNAME_B="e2e_heidi_${RUN_ID}"
  register "$USERNAME_A"; local token_a="$TOKEN"
  register "$USERNAME_B"; local token_b="$TOKEN"
  create_game_with_two_players "$token_a" "$token_b"

  call PUT "/games/$GAME_ID/current/photo" "$token_a"
  assert_true "PUT /current/photo ist kein gültiger Endpoint mehr" "$([ "$HTTP_CODE" != "200" ] && echo true || echo false)"
  call DELETE "/games/$GAME_ID/current/photo" "$token_a"
  assert_true "DELETE /current/photo ist kein gültiger Endpoint mehr" "$([ "$HTTP_CODE" != "204" ] && echo true || echo false)"
}

main() {
  wait_for_stack
  test_auth
  test_full_game_with_winner
  test_missing_upload_rule
  test_tie_break
  test_removed_photo_endpoints

  echo
  log "Ergebnis: $PASS bestanden, $FAIL fehlgeschlagen"
  [ "$FAIL" -eq 0 ]
}

main "$@"
