#!/bin/bash

# --- CONFIGURAÇÕES ---
EMAIL_DESTINO="leandro.ruthes@joinvix.com.br"
# Adicione os e-mails permitidos separados por ESPAÇO.
# Exemplo: "email1@dominio.com email2@dominio.com"
WHITELIST_EMAILS="root@joinvix.com.br dev@joinvix.com.br" 

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
echo "Ignorando admins listados na Whitelist..."
echo "----------------------------------------------------------------"

for user_dir in /home/*; do
    ((CURRENT++))
    user=$(basename "$user_dir")
    wp_path="${user_dir}/public_html" # Ajuste se o caminho for diferente (ex: domains/domain/public_html)
    
    # Barra de progresso visual
    if [ "$TOTAL" -gt 0 ]; then
        PERCENT=$(( (CURRENT * 100) / TOTAL ))
    else
        PERCENT=0
    fi
    printf "\r[%-3d%%] Processando: %-25s" "$PERCENT" "$user"

    # Verifica se é WordPress válido (tem pasta e config)
    if [ -d "$wp_path" ] && [ -f "$wp_path/wp-config.php" ]; then
        
        # Tenta resgatar domínio principal do user.conf do DirectAdmin
        # Se falhar, usa o nome do usuário como fallback
        if [ -f "/usr/local/directadmin/data/users/$user/user.conf" ]; then
            domain=$(grep "domain=" /usr/local/directadmin/data/users/"$user"/user.conf 2>/dev/null | cut -d= -f2 | head -n1)
        fi
        [ -z "$domain" ] && domain=$user

        # Obtém lista bruta de admins (Login e Email) via WP-CLI
        # --skip-plugins/themes previne erros fatais de PHP
        RAW_DATA=$(sudo -u "$user" -- "$WP_BIN" user list --role=administrator --fields=user_login,user_email --format=csv --skip-plugins --skip-themes --path="$wp_path" 2>/dev/null)

        # Variáveis de controle para este site
        CONTAGEM=0
        LISTA_ADMINS=""

        # Lê a saída linha por linha
        if [ -n "$RAW_DATA" ]; then
            # 'tail -n +2' remove o cabeçalho do CSV gerado pelo WP-CLI
            while IFS=, read -r login email; do
                # Limpeza de caracteres invisíveis
                login=$(echo "$login" | tr -d '\r')
                email=$(echo "$email" | tr -d '\r')

                # --- LÓGICA DE WHITELIST DINÂMICA ---
                # Verifica se o e-mail atual NÃO está contido na string WHITELIST_EMAILS
                # Os espaços extras " $var " garantem que não pegue substrings parciais indesejadas
                if [[ ! " $WHITELIST_EMAILS " =~ " $email " ]]; then
                    
                    ((CONTAGEM++))
                    
                    # Formata a string de saída
                    if [ -z "$LISTA_ADMINS" ]; then
                        LISTA_ADMINS="$login ($email)"
                    else
                        LISTA_ADMINS="$LISTA_ADMINS; $login ($email)"
                    fi
                fi
                # ------------------------------------

            done <<< "$(echo "$RAW_DATA" | tail -n +2)"
        fi

        # Só grava no relatório se houver admins suspeitos
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
    
    SUBJECT="Relatório de Auditoria WP - Admins Suspeitos - $(hostname)"
    BODY="Segue em anexo relatório de sites contendo administradores que NÃO estão na whitelist ($WHITELIST_EMAILS)."
    
    # Envia com anexo (-a)
    echo "$BODY" | mail -s "$SUBJECT" -a "$ARQUIVO_CSV" "$EMAIL_DESTINO"
    
    if [ $? -eq 0 ]; then
        echo "E-mail enviado com sucesso!"
    else
        echo "Falha ao enviar o e-mail."
    fi
else
    echo "ATENÇÃO: Comando 'mail' não encontrado. Instale o pacote mailx ou postfix."
fi
