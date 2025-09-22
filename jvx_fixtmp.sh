#!/bin/bash

# Ativar/desativar alertas
TMP_ALERT=true
TMP_VAR="/var/tmp"
TMP_DIR="/tmp"
TMP_DSK="/usr/tmpDSK"

# Captura informações do /tmp
read TMP_MOUNT_POINT TMP_SIZE TMP_USED TMP_AVAIL TMP_PERCENT <<< $(df -h | awk '/\/tmp$/ {print $1, $2, $3, $4, $5}')

# Remove o símbolo % para comparação numérica
TMP_PERCENT_VAL=$(echo $TMP_PERCENT | tr -d '%')

# Verifica se é tmpfs
if [[ $TMP_MOUNT_POINT == "tmpfs" ]]; then
    echo "O sistema de partição da /tmp é virtual (RAM)."
else
    echo "O sistema de partição da /tmp é físico (disco ou loop)."
fi

# Exibe informações gerais
echo "O /tmp está montado em $TMP_MOUNT_POINT com total de $TMP_SIZE,"
echo "sendo utilizado $TMP_USED, disponível $TMP_AVAIL ($TMP_PERCENT)."

# Se alertas estiverem ativados, verifica limite
if [[ "$TMP_ALERT" == true ]]; then
    if (( TMP_PERCENT_VAL >= 80 )); then
        echo "⚠️  ALERTA: O /tmp está acima de 80% de uso!"
        TMP_SIZE_ALERT=true
    else
        echo "✅ O /tmp está com uso normal."
    fi
fi

if [[ "$TMP_SIZE_ALERT" == "true" ]]; then
    echo "Atenção: É preciso realizar a adequação na tmp para evitar que serviços fiquem fora"
    echo "O processo abaixo será guiado e perguntas serão feitas"
    read -p "Deseja iniciar o procedimento? " START_FIX_TMP
fi

if [[ "$START_FIX_TMP" == [Ss] ]]; then
    echo "Limpando arquivos artigos da tmp com mais de 12 horas"
    tmpwatch --mtime 12 /var/tmp >> /var/log/tmpwatch.log 2>&1
    echo "Arquivos removidos podem ser visualizados em /var/log/tmpwatch.log"

    # Cria backup se for tmpfs
    TMP_FS=$(df -BM "$TMP_DIR" | tail -1 | awk '{print $1}')
    if [[ "$TMP_FS" == "tmpfs" ]]; then
        BACKUP_DIR="/root/tmp_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -a /tmp/* "$BACKUP_DIR/" 2>/dev/null
        echo "Backup do /tmp realizado em $BACKUP_DIR"
    fi

    # Aqui vai os unmount
    if [[ -e "$TMP_VAR" ]]; then
        umount "$TMP_VAR"
    else
        echo "Não foi possível localizar o diretório $TMP_VAR para desmontagem"
    fi

    if [[ -e "$TMP_DIR" ]]; then
        umount "$TMP_DIR"
    else
        echo "Não foi possível localizar o diretório $TMP_DIR para desmontagem"
    fi

    if [[ -e "$TMP_DSK" ]]; then
        rm -f "$TMP_DSK"
    else
        echo "Não foi possível localizar o arquivo $TMP_DSK para remoção"
    fi

    # Reinicia o MySQL/MariaDB
    if systemctl list-units --type=service | grep -q mariadb; then
        echo "Serviço MariaDB encontrado, reiniciando..."
        systemctl restart mariadb
    fi

    echo "Iniciando a configuração"
    echo "Por favor informe o tamanho do tmp o qual deseja configurar em MB"
    echo "Na dúvida, utilize esta calculadora https://www.gbmb.org/gb-to-mb"
    echo "Exemplo: 8GB => 8192, logo o valor é 8192"
    read -p "Informe o valor desejado em MB: " NEW_TMP_SIZE

    # --- VERIFICAÇÃO DE ESPAÇO DISPONÍVEL ---
    #TMP_AVAIL_MB=$(df -BM "$TMP_DIR" | tail -1 | awk '{print $4}' | sed 's/M//g')
    #echo "/tmp está em $TMP_FS e possui $TMP_AVAIL_MB MB disponíveis"

    #if [[ "$TMP_FS" == "tmpfs" ]]; then
    #    echo "✅ /tmp é tmpfs, pode ser remontado com ${NEW_TMP_SIZE}MB"
    #elif (( NEW_TMP_SIZE <= TMP_AVAIL_MB )); then
    #    echo "✅ Espaço suficiente para alocar ${NEW_TMP_SIZE}MB no /tmp"
    #else
    #    echo "❌ Espaço insuficiente! Apenas ${TMP_AVAIL_MB}MB disponíveis."
    #    echo "Opções seguras:"
    #    echo "1) Usar /var/tmp temporariamente"
    #    echo "2) Criar novo loopback para /tmp (avançado, cuidado)"
    #    echo "3) Abort (recomendado em produção)"
    #    read -p "Escolha uma opção [1-3]: " TMP_OPTION
    #    case "$TMP_OPTION" in
    #        1) echo "Usando /var/tmp temporariamente"; TMP_DIR="/var/tmp";;
    #        2) echo "Procedimento avançado de loopback será necessário"; exit 1;;
    #        *) echo "Abortando operação"; exit 1;;
    #    esac
    #fi

    # RAM Virtual - remontagem e restauração
    # Procedimento apenas realizado se o tmp é virtual
    if [[ "$TMP_FS" == "tmpfs" ]]; then
        read -p "Deseja remontar o tmpfs com ${NEW_TMP_SIZE}MB? [S/n] " REMOUNT_TMP
        if [[ "$REMOUNT_TMP" == [Ss] ]]; then
            mount -o remount,size=${NEW_TMP_SIZE}M "$TMP_DIR"
            echo "/tmp tmpfs remontado com ${NEW_TMP_SIZE}MB"
            # Restaura arquivos do backup
            if [[ -d "$BACKUP_DIR" ]]; then
                cp -a "$BACKUP_DIR"/* /tmp/ 2>/dev/null
                echo "Arquivos do backup restaurados em /tmp"
            fi
        fi
    else
        echo "Iniciando o processo de montagem segura do tmp"
        /scripts/securetmp --auto
    fi

    echo "Atualizando o fstab para refletir os novos valores"
    systemctl daemon-reload
    echo "Procedimento finalizado"
fi
