#!/bin/bash

# --- CONFIGURAÇÕES ---
EMAIL_DESTINO="leandro.ruthes@joinvix.com.br"
ARQUIVO_CSV="relatorio_admins_wp_$(date +%Y%m%d).csv"
# ---------------------

WP_BIN=$(which wp)

# Cabeçalho do CSV: Dominio, Quantidade de Admins (fora da allowlist), Lista de Usuários
echo "Dominio,Qtd_Admins,Lista_Usuarios" > "$ARQUIVO_CSV"

# Conta total de pastas para a barra de progresso
TOTAL=$(find /home -maxdepth 1 -type d | wc -l)
TOTAL=$((TOTAL - 1))
CURRENT=0

echo "Iniciando auditoria inteligente em $TOTAL contas..."
echo "Ignorando admins com e-mails: root@joinvix.com.br e dev@joinvix.com.br"
echo "----------------------------------------------------------------"

for user_dir in /home/*; do
    ((CURRENT++))
    user=$(basename "$user_dir")
    wp_path="${user_dir}/public_html"
    
    # Barra de progresso
    PERCENT=$(( (CURRENT * 100) / TOTAL ))
    printf "\r[%-3d%%] Processando: %-25s" "$PERCENT" "$user"

    # Verifica se é WordPress válido
    if [ -d "$wp_path" ] && [ -f "$wp_path/wp-config.php" ]; then
        
        # Resgata domínio
        domain=$(grep "domain=" /usr/local/directadmin/data/users/"$user"/user.conf 2>/dev/null | cut -d= -f2 | head -n1)
        [ -z "$domain" ] && domain=$user

        # Obtém lista bruta de admins (Login e Email) em formato CSV
        # output esperado:
        # user_login,user_email
        # admin,cliente@gmail.com
        # dev,dev@joinvix.com.br
        RAW_DATA=$(sudo -u "$user" -- "$WP_BIN" user list --role=administrator --fields=user_login,user_email --format=csv --skip-plugins --skip-themes --path="$wp_path" 2>/dev/null)

        # Variáveis de controle para este site
        CONTAGEM=0
        LISTA_ADMINS=""

        # Lê a saída linha por linha (pulando o cabeçalho se houver dados)
        if [ -n "$RAW_DATA" ]; then
            # 'tail -n +2' pula a primeira linha (cabeçalho user_login,user_email)
            while IFS=, read -r login email; do
                # Remove espaços em branco e caracteres invisíveis (carriage return)
                login=$(echo "$login" | tr -d '\r')
                email=$(echo "$email" | tr -d '\r')

                # CONDICIONAL DE FILTRO (ALLOWLIST)
                if [[ "$email" != "root@joinvix.com.br" && "$email" != "dev@joinvix.com.br" ]]; then
                    # Se NÃO for da JoinVix, adiciona na lista e conta
                    ((CONTAGEM++))
                    if [ -z "$LISTA_ADMINS" ]; then
                        LISTA_ADMINS="$login ($email)"
                    else
                        LISTA_ADMINS="$LISTA_ADMINS; $login ($email)"
                    fi
                fi
            done <<< "$(echo "$RAW_DATA" | tail -n +2)"
        fi

        # LÓGICA FINAL DO RELATÓRIO
        # Só adiciona no CSV se tiver encontrado admins "estranhos" (Contagem > 0)
        if [ "$CONTAGEM" -gt 0 ]; then
            echo "$domain,$CONTAGEM,\"$LISTA_ADMINS\"" >> "$ARQUIVO_CSV"
        fi
    fi
done

echo -e "\n\n--- Processo Concluído ---"
echo "Relatório salvo em: $ARQUIVO_CSV"

# Rotina de Envio de E-mail
if command -v mail &> /dev/null; then
    echo "Enviando relatório para $EMAIL_DESTINO..."
    
    SUBJECT="Relatório de Admins WP (Filtrado) - $(hostname)"
    BODY="Segue anexo relatório de sites com administradores ALÉM dos padrões da JoinVix (dev/root)."
    
    # Envia com anexo (-a)
    echo "$BODY" | mail -s "$SUBJECT" -a "$ARQUIVO_CSV" "$EMAIL_DESTINO"
    
    if [ $? -eq 0 ]; then
        echo "E-mail enviado com sucesso!"
    else
        echo "Falha ao enviar o e-mail."
    fi
else
    echo "ATENÇÃO: Comando 'mail' não encontrado."
fi
