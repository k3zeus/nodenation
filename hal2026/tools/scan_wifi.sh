#!/usr/bin/env bash
# Sistema de Registro - Conexões Wireless - Sqlite3 | Ghost Nodes v0.3 18032026
#
set -euo pipefail

# ─── Pastas e arquivos ────────────────────────────────────────────────────────
DB_DIR="/home/pleb/halfin"
DB="$DB_DIR/wifi_scan.db"
LOG="$DB_DIR/log_scan_wifi.log"

mkdir -p "$DB_DIR"
chmod 700 "$DB_DIR"
touch "$LOG"

SCAN_TMP="$(mktemp /tmp/scan_output.XXXXXX)"
TMP_SQL="$(mktemp /tmp/scan_wifi_sql.XXXXXX)"

# ─── Cleanup automático em caso de erro ───────────────────────────────────────
trap 'rm -f "$SCAN_TMP" "$TMP_SQL"' EXIT

# ─── Cria tabela SQLite se não existir ────────────────────────────────────────
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS networks (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  bssid     TEXT UNIQUE,
  ssid      TEXT,
  mode      TEXT,
  channel   INTEGER,
  security  TEXT,
  password  TEXT,
  last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

# ─── Executa scan e extrai campos por posição de coluna ───────────────────────
# O nmcli sem -t imprime tabela com colunas de largura fixa.
# Usamos -t com --escape no e separador customizado via sed para isolar o BSSID
# (que contém ':') dos demais campos.
#
# Formato com -t --escape no:
#   AA:BB:CC:DD:EE:FF:NomeRede:Infra:6:WPA2
#   O BSSID ocupa sempre os primeiros 17 caracteres (XX:XX:XX:XX:XX:XX)
#   seguido de ':' separando os demais campos.

nmcli --escape no -t -f BSSID,SSID,MODE,CHAN,SECURITY device wifi list \
  2>>"$LOG" \
  | grep -E '^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:' \
  | awk -F'\t' 'BEGIN { OFS="|" }
    {
      # BSSID são sempre os primeiros 17 chars
      bssid   = substr($0, 1, 17)
      rest    = substr($0, 19)          # pula o ":" após o BSSID

      # Divide o restante em até 4 partes pelo ":"
      n = split(rest, f, ":")
      ssid     = (n >= 1 ? f[1] : "")
      mode     = (n >= 2 ? f[2] : "")
      chan     = (n >= 3 ? f[3] : "")
      security = (n >= 4 ? f[4] : "")

      # SSID oculto vira string vazia
      if (ssid == "--") ssid = ""

      print bssid, ssid, mode, chan, security
    }' \
  > "$SCAN_TMP"

# Remove carriage returns (WSL / ambientes híbridos)
sed -i 's/\r$//' "$SCAN_TMP"

# ─── Valida conteúdo do scan ──────────────────────────────────────────────────
if [ ! -s "$SCAN_TMP" ]; then
    echo "$(date '+%F %T') - Nenhuma rede encontrada ou nmcli sem saída." >> "$LOG"
    exit 0
fi

# ─── Gera SQL de upsert ───────────────────────────────────────────────────────
echo "BEGIN TRANSACTION;" > "$TMP_SQL"

while IFS='|' read -r bssid ssid mode chan security; do

    # Valida BSSID mínimo
    if [[ ! "$bssid" =~ ^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}$ ]]; then
        echo "$(date '+%F %T') - BSSID inválido ignorado: '$bssid'" >> "$LOG"
        continue
    fi

    # Escapa aspas simples para SQLite (duplica)
    bssid_s="${bssid//\'/\'\'}"
    ssid_s="${ssid//\'/\'\'}"
    mode_s="${mode//\'/\'\'}"
    security_s="${security//\'/\'\'}"

    # Channel deve ser numérico
    if [[ "$chan" =~ ^[0-9]+$ ]]; then
        chan_sql="$chan"
    else
        chan_sql="NULL"
    fi

    # UPSERT: atualiza se BSSID já existe, insere se não existe
    cat >> "$TMP_SQL" <<ENDSQL
INSERT INTO networks (bssid, ssid, mode, channel, security, last_seen)
  VALUES ('${bssid_s}', '${ssid_s}', '${mode_s}', ${chan_sql}, '${security_s}', CURRENT_TIMESTAMP)
  ON CONFLICT(bssid) DO UPDATE SET
    ssid      = excluded.ssid,
    mode      = excluded.mode,
    channel   = excluded.channel,
    security  = excluded.security,
    last_seen = CURRENT_TIMESTAMP;
ENDSQL

done < "$SCAN_TMP"

echo "COMMIT;" >> "$TMP_SQL"

# ─── Executa SQL no banco ─────────────────────────────────────────────────────
sqlite3 "$DB" < "$TMP_SQL"

# ─── Log final ────────────────────────────────────────────────────────────────
COUNT="$(sqlite3 "$DB" "SELECT COUNT(*) FROM networks;")"
UPDATED="$(wc -l < "$SCAN_TMP")"
echo "$(date '+%F %T') - Scan concluído. Redes processadas: ${UPDATED}. Total no banco: ${COUNT}." >> "$LOG"

exit 0
