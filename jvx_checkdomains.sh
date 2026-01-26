#!/bin/bash

# ================= CONFIGURAÇÕES =================
INPUT_FILE="domains.txt"
OUTPUT_FILE="relatorio_hostnames.csv"
SEP=";" 

IP_FORTIS="148.113.217.151"
IP_ANDAMENTO="200.170.163.67"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
# =================================================

if [ ! -f "$INPUT_FILE" ]; then echo "Erro: Arquivo $INPUT_FILE não encontrado."; exit 1; fi
if ! command -v jq &> /dev/null; then echo "Erro: Instale o 'jq'."; exit 1; fi

# Cabeçalho CSV 
echo "\"Domínio\"${SEP}\"IP A\"${SEP}\"HTTP\"${SEP}\"MX\"${SEP}\"Hostname (Sub)\"${SEP}\"Plesk\"${SEP}\"Fortis\"${SEP}\"Org A\"" > "$OUTPUT_FILE"

# Formatação Visual
FMT="%-20s | %-15s | %-4s | %-15s | %-25s | %-5s | %-20s\n"

echo -e "${CYAN}Iniciando auditoria de Hostnames Reais...${NC}"
printf "$FMT" "Domínio" "IP A" "HTTP" "MX" "Hostname (Sub)" "Plesk" "Org A"
echo "---------------------------------------------------------------------------------------------------------------------------------------"

while read -r DOMAIN || [ -n "$DOMAIN" ]; do
    DOMAIN=$(echo "$DOMAIN" | xargs)
    if [ -z "$DOMAIN" ]; then continue; fi

    echo -ne ">>> Analisando: $DOMAIN ...\r" >&2

    # --- 1. CONSULTAS DNS GERAIS ---
    IP_A=$(dig +short "$DOMAIN" A | head -n 1)
    MX_RECORD=$(dig +short "$DOMAIN" MX | head -n 1 | awk '{print $2}' | sed 's/.$//')
    if [ -z "$MX_RECORD" ]; then MX_RECORD="-"; fi

    # --- 2. LÓGICA DO HOSTNAME (cPanel -> Webmail -> Nada) ---
    # Tenta cPanel primeiro
    IP_SUB=$(dig +short "cpanel.$DOMAIN" A | head -n 1)
    ORIGEM_SUB="cPanel"

    # Se cPanel vazio, tenta Webmail
    if [ -z "$IP_SUB" ]; then
        IP_SUB=$(dig +short "webmail.$DOMAIN" A | head -n 1)
        ORIGEM_SUB="Webmail"
    fi

    WEBHOST_INFO="Não existe" 

    # Se achou IP, faz o REVERSE LOOKUP (PTR) para pegar o Hostname
    if [ -n "$IP_SUB" ]; then
        # AQUI ESTÁ O TRUQUE: dig -x pega o reverso (hostname)
        PTR_NAME=$(dig +short -x "$IP_SUB" | head -n 1 | sed 's/.$//')
        
        # Se o reverso vier vazio, usamos o IP mesmo
        if [ -z "$PTR_NAME" ]; then
            PTR_NAME=$IP_SUB
        fi
        
        WEBHOST_INFO="$PTR_NAME ($ORIGEM_SUB)"
    fi

    # --- 3. PROCESSAMENTO IP PRINCIPAL ---
    ORG_A="-"
    IS_PLESK="Não"
    IS_FORTIS="Não"
    HTTP_CODE="000"
    COLOR_LINE=$NC

    if [ -n "$IP_A" ]; then
        # Ainda pegamos a ORG do IP principal para info
        JSON_A=$(curl -s --max-time 4 "https://ipinfo.io/$IP_A/json")
        ORG_A=$(echo "$JSON_A" | jq -r '.org // empty' | tr -d ';\"')
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 3 "http://$DOMAIN")

        if [ "$IP_A" == "$IP_ANDAMENTO" ]; then IS_PLESK="Sim"; fi
        if [ "$IP_A" == "$IP_FORTIS" ]; then IS_FORTIS="Sim"; fi
        
        # Definição de Cores
        if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "301" ]; then COLOR_LINE=$GREEN
        elif [ "$HTTP_CODE" == "000" ]; then COLOR_LINE=$RED
        else COLOR_LINE=$YELLOW; fi
        
        if [ "$IS_PLESK" == "Sim" ] || [ "$IS_FORTIS" == "Sim" ]; then COLOR_LINE=$CYAN; fi
    else
        IP_A="N/A"
        COLOR_LINE=$RED
    fi

    # --- SAÍDA TELA ---
    ORG_A_SHORT=$(echo "$ORG_A" | cut -c 1-20)
    MX_SHORT=$(echo "$MX_RECORD" | cut -c 1-15)
    WEBHOST_SHORT=$(echo "$WEBHOST_INFO" | cut -c 1-25) # Corte maior para caber o hostname

    printf "${COLOR_LINE}$FMT${NC}" "$DOMAIN" "$IP_A" "$HTTP_CODE" "$MX_SHORT" "$WEBHOST_SHORT" "$IS_PLESK" "$ORG_A_SHORT"

    # --- SAÍDA CSV ---
    echo "\"${DOMAIN}\"${SEP}\"${IP_A}\"${SEP}\"${HTTP_CODE}\"${SEP}\"${MX_RECORD}\"${SEP}\"${WEBHOST_INFO}\"${SEP}\"${IS_PLESK}\"${SEP}\"${IS_FORTIS}\"${SEP}\"${ORG_A}\"" >> "$OUTPUT_FILE"

done < "$INPUT_FILE"

echo -ne "                                            \r" >&2
echo ""
echo -e "✅ ${GREEN}Relatório Hostnames gerado: $OUTPUT_FILE${NC}"
