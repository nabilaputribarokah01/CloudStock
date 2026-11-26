#!/usr/bin/env bash
set -euo pipefail
BASE=http://127.0.0.1:8080
printf '\nHEALTH\n'; curl -fsS "$BASE/health"; echo
printf '\nCREATE (POST)\n'
ITEM=$(curl -fsS -X POST "$BASE/items" -H 'Content-Type: application/json' -d '{"name":"Keyboard","quantity":10,"location":"Rak A"}')
echo "$ITEM"
ID=$(printf '%s' "$ITEM" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
printf '\nREAD (GET)\n'; curl -fsS "$BASE/items"; echo
printf '\nUPDATE (PUT)\n'; curl -fsS -X PUT "$BASE/items/$ID" -H 'Content-Type: application/json' -d '{"name":"Keyboard","quantity":15,"location":"Rak B"}'; echo
printf '\nDELETE (DELETE)\n'; curl -fsS -X DELETE "$BASE/items/$ID"; echo
printf '\nREAD AFTER DELETE\n'; curl -fsS "$BASE/items"; echo
