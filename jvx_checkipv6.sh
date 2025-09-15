#!/bin/bash
######################################
# Author: Percio Andrade
# Version: 1.0
# Info: Checa qual domínio está usando IPv6 no DirectAdmin
######################################

# Arquivo de saída
output="/var/www/html/ipv6-domains.txt"

# Cabeçalho
printf "%-40s | %-39s | %-10s\n" "Domínio" "AAAA" "Usando IPv6?" > "$output"
printf '%.0s-' {1..95} >> "$output"
echo >> "$output"

# Loop para cada domínio
for d in $(cat /usr/local/directadmin/data/users/*/domains.list); do
    aaaa=$(dig +short AAAA $d)
    if [ -z "$aaaa" ]; then
        aaaa="-"
        ipv6="não"
    else
        ipv6="sim"
    fi
    printf "%-40s | %-39s | %-10s\n" "$d" "$aaaa" "$ipv6" >> "$output"
done

echo "Lista gerada em $output"
