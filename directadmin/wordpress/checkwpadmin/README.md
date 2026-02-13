# 🚀 JVX Check WP-Admin

O jvx_checkwpadmin.sh é uma ferramenta de auditoria de segurança desenvolvida para servidores DirectAdmin. O seu objetivo crítico é varrer todas as contas de usuário, identificar instalações WordPress e listar usuários com privilégios de Administrador que não fazem parte da whitelist da equipe (ex: root@joinvix ou dev@joinvix).

Ideal para identificar contas administrativas suspeitas, esquecidas ou criadas por invasores em servidores compartilhados.

🚀 Funcionalidades Principais

- **Varredura Global**: Itera automaticamente sobre todos os usuários do DirectAdmin (`/home/*/domains/*/public_html`).
- **Detecção de WordPress**: Valida se o diretório contém uma instalação WP ativa.
- **Auditoria de Admins (WP-CLI)**: Utiliza wp user list para extrair usuários com a role administrator.
- **Modo de Segurança**: Executa comandos com --skip-plugins e --skip-themes para garantir que a auditoria funcione mesmo em sites com erros fatais ou conflitos.
- **Whitelist Inteligente**: Ignora usuários administrativos padrão da infraestrutura (ex: *`@joinvix.com.br`), focando apenas em usuários desconhecidos.
- **Relatório CSV**: Gera um arquivo `.csv` consolidado com: `Data`, `Usuário DA`, `Domínio`, `Total Admins Suspeitos`, `Lista de Logins`.
- **Feedback Visual**: Exibe uma barra de progresso durante a execução no terminal.
- **Alerta por E-mail**: Envia o relatório final automaticamente para o e-mail configurado.

🛠️ Pré-requisitos
- Servidor com **DirectAdmin** e acesso **root**.
- **WP-CLI** instalado e acessível globalmente.
- Pacote `mail` ou similar configurado para envio do relatório.

## 📦 Instalação e Uso

**1. Download do Script**

```bash
wget https://raw.githubusercontent.com/sr00t3d/src/main/directadmin/wordpress/checkwpadmin/jvx_checkwpadmin.sh
chmod +x jvx_checkwpadmin.sh
```
**2. Configuração (Opcional)**

Edite o cabeçalho do script para ajustar a whitelist de e-mails ou o destinatário do relatório:

```bash
# Exemplo de variáveis internas
EMAIL_REPORT="seu-email@joinvix.com.br"
WHITELIST_EMAILS="root@joinvix.com.br|dev@joinvix.com.br"
```

3. Execução

Rode o script como root para garantir acesso a todos os diretórios de usuários:

```bash
./jvx_checkwpadmin.sh
```

## 📊 Estrutura do Relatório (CSV)

O arquivo gerado (`relatorio_admins_wp.csv`) segue o padrão:

```
Data,User DirectAdmin,Domínio,Qtd. Admins Externos,Logins Encontrados
2026-02-13,cliente01,site.com,1,admin_oculto
2026-02-13,cliente02,https://www.google.com/search?q=loja.com,0,(vazio)
```

## ⚠️ Tratamento de Erros

- O script foi desenhado para **não interromper** a execução caso encontre um site quebrado. Ele:
- Ignora erros de PHP do site (via flags do WP-CLI).
- Registra "Erro ao ler WP" no relatório caso o wp-config.php esteja ilegível ou o banco de dados inacessível.
