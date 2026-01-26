#!/bin/bash

# ================= CONFIGURAÇÕES =================
OUTPUT_FILE="relatorio_final.csv"
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

# --- TRATAMENTO DE ARGUMENTOS (--lista) ---
SOURCE_INPUT="domains.txt" # Valor padrão
IS_TEMP_FILE=0

# Verifica se o primeiro argumento é --lista
if [[ "$1" == "--lista" ]]; then
    if [ -n "$2" ]; then
        SOURCE_INPUT="$2"
    else
        echo -e "${RED}Erro: Você usou a flag --lista mas não forneceu o arquivo ou URL.${NC}"
        echo "Exemplo: ./script.sh --lista https://site.com/lista.txt"
        exit 1
    fi
fi

# Verifica se é uma URL (começa com http ou https)
if [[ "$SOURCE_INPUT" == http* ]]; then
    echo -e "${CYAN}>>> Detectado URL. Baixando lista de domínios...${NC}"
    TEMP_FILE="domains_temp_$(date +%s).txt"
    
    # Baixa o arquivo (-L segue redirecionamentos, -s silencioso, -f falha se der erro http)
    if curl -L -s -f "$SOURCE_INPUT" -o "$TEMP_FILE"; then
        INPUT_FILE="$TEMP_FILE"
        IS_TEMP_FILE=1
        echo -e "${GREEN}>>> Lista baixada com sucesso!${NC}"
    else
        echo -e "${RED}Erro: Falha ao baixar a lista da URL informada.${NC}"
        exit 1
    fi
else
    # É um arquivo local
    INPUT_FILE="$SOURCE_INPUT"
fi

# Verifica se o arquivo final existe e não está vazio
if [ ! -f "$INPUT_FILE" ]; then 
    echo -e "${RED}Erro: Arquivo de entrada '$INPUT_FILE' não encontrado.${NC}"; 
    exit 1; 
fi

if ! command -v jq &> /dev/null; then echo "Erro: Instale o 'jq'."; exit 1; fi

# --- INÍCIO DO PROCESSAMENTO ---

# Cabeçalho CSV
echo "\"Domínio\"${SEP}\"IP A\"${SEP}\"HTTP\"${SEP}\"MX\"${SEP}\"Hostname (Sub)\"${SEP}\"Plesk\"${SEP}\"Fortis\"${SEP}\"Org A\"" > "$OUTPUT_FILE"

# Formatação Visual
FMT="%-20s | %-15s | %-4s | %-15s | %-25s | %-5s | %-20s\n"

echo -e "${CYAN}Iniciando auditoria...${NC}"
printf "$FMT" "Domínio" "IP A" "HTTP" "MX" "Hostname (Sub)" "Plesk" "Org A"
echo "---------------------------------------------------------------------------------------------------------------------------------------"

while read -r DOMAIN || [ -n "$DOMAIN" ]; do
    DOMAIN=$(echo "$DOMAIN" | xargs) # Remove espaços
    if [ -z "$DOMAIN" ]; then continue; fi # Pula vazios

    echo -ne ">>> Analisando: $DOMAIN ...\r" >&2

    # --- 1. CONSULTAS DNS ---
    IP_A=$(dig +short "$DOMAIN" A | head -n 1)
    MX_RECORD=$(dig +short "$DOMAIN" MX | head -n 1 | awk '{print $2}' | sed 's/.$//')
    [ -z "$MX_RECORD" ] && MX_RECORD="-"

    # --- 2. HOSTNAME / REVERSE DNS ---
    IP_SUB=$(dig +short "cpanel.$DOMAIN" A | head -n 1)
    ORIGEM_SUB="cPanel"

    if [ -z "$IP_SUB" ]; then
        IP_SUB=$(dig +short "webmail.$DOMAIN" A | head -n 1)
        ORIGEM_SUB="Webmail"
    fi

    WEBHOST_INFO="Não existe" 

    if [ -n "$IP_SUB" ]; then
        PTR_NAME=$(dig +short -x "$IP_SUB" | head -n 1 | sed 's/.$//')
        [ -z "$PTR_NAME" ] && PTR_NAME=$IP_SUB # Se não tiver reverso, usa o IP
        WEBHOST_INFO="$PTR_NAME ($ORIGEM_SUB)"
    fi

    # --- 3. DADOS DO IP PRINCIPAL ---
    ORG_A="-"
    IS_PLESK="Não"
    IS_FORTIS="Não"
    HTTP_CODE="000"
    COLOR_LINE=$NC

    if [ -n "$IP_A" ]; then
        JSON_A=$(curl -s --max-time 4 "https://ipinfo.io/$IP_A/json")
        ORG_A=$(echo "$JSON_A" | jq -r '.org // empty' | tr -d ';\"')
        HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 3 "http://$DOMAIN")

        if [ "$IP_A" == "$IP_ANDAMENTO" ]; then IS_PLESK="Sim"; fi
        if [ "$IP_A" == "$IP_FORTIS" ]; then IS_FORTIS="Sim"; fi
        
        # Cores
        if [[ "$HTTP_CODE" =~ ^(200|301|302)$ ]]; then COLOR_LINE=$GREEN
        elif [ "$HTTP_CODE" == "000" ]; then COLOR_LINE=$RED
        else COLOR_LINE=$YELLOW; fi
        
        if [ "$IS_PLESK" == "Sim" ] || [ "$IS_FORTIS" == "Sim" ]; then COLOR_LINE=$CYAN; fi
    else
        IP_A="N/A"
        COLOR_LINE=$RED
    fi

    # --- SAÍDAS ---
    ORG_A_SHORT=$(echo "$ORG_A" | cut -c 1-20)
    MX_SHORT=$(echo "$MX_RECORD" | cut -c 1-15)
    WEBHOST_SHORT=$(echo "$WEBHOST_INFO" | cut -c 1-25)

    printf "${COLOR_LINE}$FMT${NC}" "$DOMAIN" "$IP_A" "$HTTP_CODE" "$MX_SHORT" "$WEBHOST_SHORT" "$IS_PLESK" "$ORG_A_SHORT"

    echo "\"${DOMAIN}\"${SEP}\"${IP_A}\"${SEP}\"${HTTP_CODE}\"${SEP}\"${MX_RECORD}\"${SEP}\"${WEBHOST_INFO}\"${SEP}\"${IS_PLESK}\"${SEP}\"${IS_FORTIS}\"${SEP}\"${ORG_A}\"" >> "$OUTPUT_FILE"

done < "$INPUT_FILE"

# --- LIMPEZA ---
# Se o arquivo foi baixado da URL, deleta ele agora
if [ "$IS_TEMP_FILE" -eq 1 ]; then
    rm "$INPUT_FILE"
fi

echo -ne "                                            \r" >&2
echo ""
echo -e "✅ ${GREEN}Relatório final gerado: $OUTPUT_FILE${NC}"
