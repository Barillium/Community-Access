#!/bin/zsh
# Run manually: the key is hidden, stays server-side and is never saved.
set -eu
cd "${0:A:h:h}"
typeset auth_dashboard_key
read -rs "auth_dashboard_key?API-Schlüssel des bestehenden Better-Auth-Projekts (verdeckt): "
print
# Accept either the bare value or the dashboard's environment assignment.
auth_dashboard_key="${auth_dashboard_key#BETTER_AUTH_API_KEY=}"
if [[ "$auth_dashboard_key" == \"*\" || "$auth_dashboard_key" == \'*\' ]]; then
  auth_dashboard_key="${auth_dashboard_key[2,-2]}"
fi
if [[ -z "$auth_dashboard_key" ]]; then
  print -u2 'Kein Schlüssel eingegeben. Dashboard nicht gestartet.'
  exit 2
fi
if [[ "$auth_dashboard_key" == *[[:space:]]* || "$auth_dashboard_key" == *\"* || "$auth_dashboard_key" == *\'* ]]; then
  print -u2 'Ungültige Eingabe. Bitte den aktuellen Wert über „Copy key“ kopieren und ohne zusätzliche Befehle eingeben.'
  unset auth_dashboard_key
  exit 2
fi
BETTER_AUTH_API_KEY="$auth_dashboard_key" BETTER_AUTH_DASHBOARD_ENABLED=true \
  python3 -I scripts/local_auth.py
unset auth_dashboard_key
