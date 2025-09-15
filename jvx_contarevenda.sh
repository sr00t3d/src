#!/bin/bash
# ------------------------------------------------------------------------------
# Script: jvx_contarevenda
# Autor: Percio Andrade <percio@joinvix.com.br>
#
# Changelog: 
#
# Versão:
# 1.0.0
# ------------------------------------------------------------------------------
#
# Descrição:
#   Script para gerar relatório de uso de espaço por revendedor e contas filhas do revendedor
#   Uso: ./jvx_contarevenda.sh USUARIO_REVENDEDOR
# ------------------------------------------------------------------------------

# Verifica se foi passado o parâmetro
if [ -z "$1" ]; then
    echo "Uso: $0 NOME_REVENDEDOR"
    exit 1
fi

REVENDEDOR="$1"
SAIDA="/var/www/html/relatorio-$REVENDEDOR.txt"

# Lista de usuários do revendedor
USUARIOS=($(grep "$REVENDEDOR" /etc/trueuserowners | awk -F':' '{print $1}'))
TOTAL_USUARIOS=${#USUARIOS[@]}

if [ $TOTAL_USUARIOS -eq 0 ]; then
    echo "Nenhum usuário encontrado para o revendedor $REVENDEDOR."
    exit 1
fi

total=0
contador=0

# Cabeçalho do relatório
{
    echo -e "Conta\t\tUso"
    echo "------------------------"
} > "$SAIDA"

# Loop pelos usuários
for user in "${USUARIOS[@]}"; do
    uso_mb=$(du -sm /home/$user 2>/dev/null | cut -f1)
    uso_gb=$(echo "scale=2; $uso_mb/1024" | bc)
    total=$(echo "$total + $uso_gb" | bc)

    printf "%-15s %6s GB\n" "$user" "$uso_gb" >> "$SAIDA"

    # Atualiza contador e barra de progresso
    contador=$((contador + 1))
    perc=$((contador * 100 / TOTAL_USUARIOS))
    echo -ne "Progresso: $perc% \r"
done

# Finaliza relatório
{
    echo "------------------------"
    echo "TOTAL: $(echo "scale=2; $total" | bc) GB"
} >> "$SAIDA"

echo -e "\nRelatório gerado em: $SAIDA"
