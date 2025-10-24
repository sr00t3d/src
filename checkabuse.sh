#!/bin/bash
# -----------------------------------------------------------
# check_smtp_abuse.sh
# Verifica contas que estão abusando de SMTP no cPanel/CloudLinux.
# Analisa os logs do Exim e lista remetentes que mais enviaram mensagens.
#
# Autor: Atlas (ajudante de Mateus)
# -----------------------------------------------------------

# CONFIGURAÇÕES
LOG_DIR="/var/log"
EXIM_LOGS="$LOG_DIR/exim_mainlog*"
THRESHOLD=50       # mínimo de envios para reportar
HOURS=3            # intervalo em horas a analisar
OUTPUT="/root/smtp_abuse_report.txt"

# -----------------------------------------------------------
# Funções auxiliares
# -----------------------------------------------------------

echo ""
echo "[+] Analisando logs de Exim das últimas $HOURS horas..."
echo "[+] Threshold mínimo: $THRESHOLD mensagens"

# Define o timestamp limite
CUTOFF=$(date -d "$HOURS hours ago" "+%Y-%m-%d %H:%M:%S")

# Arquivo temporário
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Extrai remetentes (linhas com "<=" indicam envio)
# Formato padrão do exim_mainlog: "YYYY-MM-DD HH:MM:SS ... <= remetente@dominio ..."
# Filtra apenas linhas dentro do intervalo de tempo.
for log in $EXIM_LOGS; do
    if [[ -f "$log" ]]; then
        if [[ "$log" == *.gz ]]; then
            zgrep -h "<=" "$log" | awk -v cutoff="$CUTOFF" '
                $1" "$2 >= cutoff {print $0}'
        else
            grep "<=" "$log" | awk -v cutoff="$CUTOFF" '
                $1" "$2 >= cutoff {print $0}'
        fi
    fi
done | awk '{for(i=1;i<=NF;i++){if($i=="<="){print $(i+1)}}}' \
| grep -E "^[^ ]+@[^ ]+$" \
| sort | uniq -c | sort -nr > "$TMPFILE"

# -----------------------------------------------------------
# Relatório
# -----------------------------------------------------------

echo ""
echo "[+] Gerando relatório em: $OUTPUT"
echo "--------------------------------------------" > "$OUTPUT"
echo "SMTP Abuse Report - $(date)" >> "$OUTPUT"
echo "Intervalo: últimas $HOURS horas" >> "$OUTPUT"
echo "Limite mínimo: $THRESHOLD mensagens" >> "$OUTPUT"
echo "--------------------------------------------" >> "$OUTPUT"
echo "" >> "$OUTPUT"

while read -r line; do
    COUNT=$(echo "$line" | awk '{print $1}')
    SENDER=$(echo "$line" | awk '{print $2}')

    if (( COUNT >= THRESHOLD )); then
        DOMAIN=$(echo "$SENDER" | cut -d'@' -f2)

        # Descobre o usuário cPanel associado ao domínio
        CPUSER=$(grep -i "^$DOMAIN:" /etc/trueuserdomains 2>/dev/null | awk '{print $2}')
        if [[ -z "$CPUSER" ]]; then
            CPUSER="(desconhecido)"
        fi

        echo "Remetente: $SENDER" >> "$OUTPUT"
        echo "Envios: $COUNT" >> "$OUTPUT"
        echo "Usuário cPanel: $CPUSER" >> "$OUTPUT"
        echo "--------------------------------------------" >> "$OUTPUT"
    fi
done < "$TMPFILE"

# Mostra resultado final
if grep -q "Remetente:" "$OUTPUT"; then
    echo "[+] Contas com possível abuso de SMTP:"
    grep "Remetente:" "$OUTPUT" | awk '{print " - "$2}'
else
    echo "[✓] Nenhum abuso de SMTP detectado nas últimas $HOURS horas."
fi

echo ""
echo "[i] Relatório completo salvo em: $OUTPUT"
echo ""
