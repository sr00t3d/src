#!/usr/bin/env bash
set -o pipefail

NS1="ns1.joinvix.com.br"
NS2="ns2.joinvix.com.br"
ZONEDIR="/var/named"

dif=0
OUTPUT=""

SECONDS=0  # cronômetro

while IFS= read -r -d '' f; do
  d="${f##*/}"; d="${d%.db}"

  echo "Verificando domínio $d ..."

  # Só checa domínios cujo MX aponta para mail.DOMINIO.
  if grep -Eq "^[[:space:]]*([[:alnum:]_.-]+[[:space:]]+)?IN[[:space:]]+MX[[:space:]]+[0-9]+[[:space:]]+mail\.${d}\.[[:space:]]*$" "$f"; then
    a="$(dig +short @"$NS1" "$d" MX | sort)"
    b="$(dig +short @"$NS2" "$d" MX | sort)"

    # Verificação MX
    if [ "$a" = "$b" ] && grep -qi "^0[[:space:]]\+mail\.${d}\.$" <<<"$a"; then
      resultado="correto"
    else
      resultado="erro"
      dif=1
    fi

    # Verificação registro domínio
    GET=$(whois "$d" 2>/dev/null | grep -i 'No match')
    if [[ -n "$GET" ]]; then
      registrado="não"
    else
      registrado="sim"
    fi

    # Quebra o MX em várias linhas
    first_line=1
    while IFS= read -r mx; do
      if [[ -n "$mx" ]]; then
        if [[ $first_line -eq 1 ]]; then
          OUTPUT+="$d\t$registrado\t$mx\t$resultado\n"
          first_line=0
        else
          OUTPUT+="\t\t$mx\t\n"
        fi
      fi
    done <<< "$a"
  fi
done < <(find "$ZONEDIR" -maxdepth 1 -type f -name '*.db' -print0)

# Imprime tabela
echo
echo "--------------------------------------------------------------------------------"
echo -e "domínio\tregistrado\tMX\tresultado" | column -t -s $'\t'
echo "--------------------------------------------------------------------------------"
echo -e "$OUTPUT" | column -t -s $'\t'
echo "--------------------------------------------------------------------------------"

# resumo + código de saída útil para automação
if [ $dif -eq 0 ]; then
  echo "Resumo: todos corretos"
else
  echo "Resumo: há divergências (erro)"
fi

# tempo de execução
echo "Tempo total: ${SECONDS}s"

exit $dif
