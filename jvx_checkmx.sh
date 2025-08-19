#!/bin/bash
# Script para verificar registros DNS nas zonas do servidor cPanel
# Mostra se "mail" é A ou CNAME e lista o destino + IP final

ZONEDIR="/var/named"
OUTPUT="/root/relatorio_dns.txt"

# Limpar relatório
echo "Relatório de DNS - $(date)" > "$OUTPUT"
echo "" >> "$OUTPUT"

# Cabeçalho
echo "MX Existentes:" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"
echo "Dominio | MAIL | Valor | IP Resolvido | MX" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"

mx_tmp=$(mktemp)
nomx_tmp=$(mktemp)

for zonefile in $ZONEDIR/*.db; do
    dominio=$(basename "$zonefile" .db)

    mail_record=$(grep -E "^[[:space:]]*mail[[:space:]]+" "$zonefile" | head -n1)
    mail_type="Não encontrado"
    mail_value="-"
    mail_ip="-"

    if [[ -n "$mail_record" ]]; then
        if echo "$mail_record" | grep -q "CNAME"; then
            mail_type="CNAME"
            mail_value=$(echo "$mail_record" | awk '{print $NF}')
            mail_ip=$(dig +short "$mail_value" A | head -n1)
            [[ -z "$mail_ip" ]] && mail_ip="(sem resposta)"
        elif echo "$mail_record" | grep -q -w "A"; then
            mail_type="A"
            mail_value=$(echo "$mail_record" | awk '{print $NF}')
            mail_ip="$mail_value"
        else
            mail_type="Outro"
            mail_value=$(echo "$mail_record" | awk '{print $NF}')
            mail_ip=$(dig +short "$mail_value" A | head -n1)
            [[ -z "$mail_ip" ]] && mail_ip="(sem resposta)"
        fi
    fi

    if grep -q -w "MX" "$zonefile"; then
        echo "$dominio | $mail_type | $mail_value | $mail_ip | Encontrado" >> "$mx_tmp"
    else
        echo "$dominio | $mail_type | $mail_value | $mail_ip | Não encontrado" >> "$nomx_tmp"
    fi
done

# Adicionar os domínios encontrados
sort "$mx_tmp" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Adicionar os domínios sem MX
echo "MX Não Existentes:" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"
echo "Dominio | MAIL | Valor | IP Resolvido | MX" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"
sort "$nomx_tmp" >> "$OUTPUT"
echo "--------------------------------------------------------------------------------------" >> "$OUTPUT"

rm -f "$mx_tmp" "$nomx_tmp"

echo "Relatório finalizado em $OUTPUT"


# Envia email
{
echo "Subject: Relatório de DNS $(hostname) - $(date +%d/%m/%Y)"
echo "To: percio@joinvix.com.br"
echo "From: root@$(hostname)"
echo
cat "$OUTPUT"
} | sendmail -t
