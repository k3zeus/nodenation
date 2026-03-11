#!/usr/bin/env bash
set -euo pipefail

# Pastas e arquivos
DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"
LOG="$DB_DIR/log_scan_wifi.log"
mkdir -p "$DB_DIR"
chmod 700 "$DB_DIR"
touch "$LOG"

TMP_SQL="$(mktemp /tmp/scan_wifi_sql.XXXXXX)"
SCAN_TMP="$(mktemp /tmp/scan_output.XXXXXX)"

# Cria tabela SQLite se não existir
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS networks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bssid TEXT UNIQUE,
  ssid TEXT,
  mode TEXT,
  channel INTEGER,
  security TEXT,
  password TEXT,
  last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

# Executa scan Wi-Fi no modo terse (separado por : com escape)
nmcli -t -f BSSID,SSID,MODE,CHAN,SECURITY device wifi list > "$SCAN_TMP" 2>&1

# Remove carriage returns (caso esteja em WSL/ambiente híbrido)
sed -i 's/\r$//' "$SCAN_TMP"

# Verifica se há conteúdo
if [ ! -s "$SCAN_TMP" ]; then
    echo "$(date '+%F %T') - Nenhuma saída do nmcli (arquivo vazio)." >> "$LOG"
    rm -f "$TMP_SQL" "$SCAN_TMP"
    exit 0
fi

# Verifica se a primeira linha parece um erro (não começa com BSSID)
if ! head -n1 "$SCAN_TMP" | grep -qE '^([0-9A-Fa-f]{2}\\:){5}[0-9A-Fa-f]{2}'; then
    echo "$(date '+%F %T') - Saída do nmcli não é uma lista de redes (possível erro):" >> "$LOG"
    cat "$SCAN_TMP" >> "$LOG"
    rm -f "$TMP_SQL" "$SCAN_TMP"
    exit 0
fi

# Inicia transação SQL
echo "BEGIN TRANSACTION;" > "$TMP_SQL"

# Processa com awk: split por ':', desescapa campos, gera SQL
awk -F: '
function unescape(s,    out, i, len) {
    out = ""
    len = length(s)
    for (i = 1; i <= len; i++) {
        c = substr(s, i, 1)
        if (c == "\\" && i < len) {
            nextc = substr(s, i+1, 1)
            if (nextc == ":" || nextc == "\\") {
                out = out nextc
                i++
            } else {
                out = out c
            }
        } else {
            out = out c
        }
    }
    return out
}
{
    if (NF < 5) next

    bssid = unescape($1)
    ssid = unescape($2)
    mode = unescape($3)
    chan = unescape($4)
    security = unescape($5)

    # Trata SSID oculto
    if (ssid == "--") ssid = ""

    # Escapar aspas simples para SQLite
    gsub(/'\''/, "''", bssid)
    gsub(/'\''/, "''", ssid)
    gsub(/'\''/, "''", mode)
    gsub(/'\''/, "''", security)

    # Valida channel
    chan_sql = (chan ~ /^[0-9]+$/ ? chan : "NULL")

    print "UPDATE networks SET ssid='\''" ssid "'\'', mode='\''" mode "'\'', channel=" chan_sql ", security='\''" security "'\'', last_seen=CURRENT_TIMESTAMP WHERE bssid='\''" bssid "'\'';"
    print "INSERT INTO networks(bssid, ssid, mode, channel, security, last_seen) SELECT '\''" bssid "'\'', '\''" ssid "'\'', '\''" mode "'\'', " chan_sql ", '\''" security "'\'', CURRENT_TIMESTAMP WHERE (SELECT changes()) = 0;"
}
' "$SCAN_TMP" >> "$TMP_SQL"

echo "COMMIT;" >> "$TMP_SQL"

# Executa SQL
sqlite3 "$DB" < "$TMP_SQL"

# Limpeza
rm -f "$TMP_SQL" "$SCAN_TMP"

# Log final
COUNT="$(sqlite3 "$DB" "SELECT COUNT(*) FROM networks;")"
echo "$(date '+%F %T') - Scan concluído. Total de redes no banco: $COUNT" >> "$LOG"

exit 0