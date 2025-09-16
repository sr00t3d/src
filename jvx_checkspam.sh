#!/bin/bash
#
# Script: exim-relatorio.sh
# Uso: ./jvx_checkspam.sh email@dominio.com
# Gera relatório confiável de envios do Exim para cPanel/WHM
# Saída: tabela formatada
#

if [ -z "$1" ]; then
  echo "Uso: $0 email@dominio.com"
  exit 1
fi

EMAIL="$1"
LOGS="/var/log/exim_mainlog*"
SAIDA="/var/www/html/relatorio-exim-$(echo $EMAIL | tr @ _).txt"

zcat -f $LOGS | awk -v email="$EMAIL" '
BEGIN {
  PROCINFO["sorted_in"] = "@ind_str_asc"
}

/<=/ {
  # total disparos
  if ($0 ~ ("<= <" email ">") || $0 ~ ("<= " email)) {
    date = substr($1,9,2) "/" substr($1,6,2)
    msg = $3
    msg_date[msg] = date
    total[date]++

    # captura Return-Path se houver
    if (match($0, /H=<[^>]+>/)) {
      r = substr($0, RSTART+3, RLENGTH-4)
      ret_count[date SUBSEP r]++
    }
  }
}

/=>/ {
  msg = $3
  if (msg_date[msg]) {
    date = msg_date[msg]
    rec = "-"
    # pega destinatário real após =>
    if (match($0, /=>[ ]*([^\ ]+)/, arr)) {
      rec = arr[1]
    }
    rec_count[date SUBSEP rec]++
    delivered[date]++
  }
}

/blacklist|rbl|blocked|refused|deny/i {
  msg = $3
  if (msg_date[msg]) black[msg_date[msg]] = 1
}

/failed|bounce|error|reject|returned/i {
  msg = $3
  if (msg_date[msg]) fails[msg_date[msg]]++
}

END {
  # cabeçalho
  printf "%-8s | %-14s | %-10s | %-9s | %-30s | %-30s\n",
         "data", "total disparos", "reputação", "blacklist", "retorno", "destino" > "'"$SAIDA"'"

  for (d in total) {
    # Return-Path mais frequente
    bestret = "-"
    bestretcnt = 0
    for (key in ret_count) {
      split(key, arr, SUBSEP)
      if (arr[1] == d && ret_count[key] > bestretcnt) {
        bestretcnt = ret_count[key]; bestret = arr[2]
      }
    }

    # Destino mais frequente
    bestrec = "-"
    bestreccnt = 0
    for (key in rec_count) {
      split(key, arr, SUBSEP)
      if (arr[1] == d && rec_count[key] > bestreccnt) {
        bestreccnt = rec_count[key]; bestrec = arr[2]
      }
    }

    succ = delivered[d] + 0
    fail = fails[d] + 0
    reputation = succ - fail
    isblack = (black[d] ? "sim" : "nao")

    printf "%-8s | %-14d | %-10d | %-9s | %-30s | %-30s\n",
           d, total[d]+0, reputation, isblack,
           (bestret==""? "-" : bestret),
           (bestrec==""? "-" : bestrec) >> "'"$SAIDA"'"
  }
}
'

echo "Relatório gerado em: $SAIDA"
