#!/bin/zsh
# Manually run by the owner. Never paste the key into chat, files or shell history.
set -eu
unsetopt BGNICE
cd "${0:A:h:h}"
if python3 -I -c 'import socket,sys; occupied=[]
for port in (8000,8300):
 s=socket.socket(); s.settimeout(1)
 if s.connect_ex(("127.0.0.1",port)) == 0: occupied.append(port)
 s.close()
sys.exit(0 if occupied else 1)'; then
  print -u2 'Auth-Dienst oder Oberfläche läuft bereits. Beende beide in ihren Terminals mit Strg+C und starte danach erneut.'
  exit 2
fi
typeset private_flutter_bin="$HOME/develop/flutter/bin/flutter"
if [[ ! -x "$private_flutter_bin" ]]; then
  print -u2 'Die vorhandene Flutter-Installation fehlt. Keine Installation vorgenommen.'
  exit 2
fi
typeset private_resend_key
read -rs "private_resend_key?Resend-Schlüssel für communityaccess.de (verdeckt): "
print
private_resend_key="${private_resend_key#RESEND_API_KEY=}"
if [[ ! "$private_resend_key" =~ '^re_[A-Za-z0-9_-]+$' ]]; then
  print -u2 'Ungültiger Schlüssel. Bitte ausschließlich den Schlüsselwert eingeben.'
  unset private_resend_key
  exit 2
fi
typeset private_flutter_pid
(
  cd client
  # The UI build receives neither the Resend key nor the auth/dashboard secrets.
  exec env -u RESEND_API_KEY -u BETTER_AUTH_SECRET -u BETTER_AUTH_API_KEY \
    "$private_flutter_bin" run --no-pub -d web-server --web-hostname 127.0.0.1 \
    --web-port 8300 --dart-define=CA_PRIVATE_MAIL=true
) &
private_flutter_pid=$!
trap 'kill "$private_flutter_pid" 2>/dev/null || true; wait "$private_flutter_pid" 2>/dev/null || true' EXIT
RESEND_API_KEY="$private_resend_key" python3 -I scripts/local_auth.py --private-mail
unset private_resend_key
