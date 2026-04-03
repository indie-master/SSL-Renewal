#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SSL Renewal"
APP_SLUG="ssl-renewal"
APP_DIR="/opt/${APP_SLUG}"
ETC_DIR="/etc/${APP_SLUG}"
BIN_LINK="/usr/local/bin/${APP_SLUG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

mkdir -p "${APP_DIR}" "${ETC_DIR}" "${APP_DIR}/logs"

banner() {
cat <<'EOF'
   _____ _____ _        ____                              _
  / ____/ ____| |      |  _ \                            | |
 | (___| (___ | |      | |_) |___ _ __   _____      ____| |
  \___ \\___ \| |      |  _ </ _ \ '_ \ / _ \ \ /\ / / _` |
  ____) |___) | |____  | |_) |  __/ | | |  __/\ V  V / (_| |
 |_____/_____/|______| |____/ \___|_| |_|\___| \_/\_/ \__,_|

 SSL Renewal
 Centralized wildcard certificate issuance, sync, and Telegram alerts

 Developer: Indie_Master
 GitHub: https://github.com/indie-master
EOF
}

say() { printf "\n[%s] %s\n" "$(date '+%F %T')" "$*"; }
warn() { printf "\n[WARN] %s\n" "$*" >&2; }
die() { printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Запусти install.sh от root."
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  else
    die "Поддерживается только apt-based система. Нужен Ubuntu/Debian."
  fi
}

ensure_base_packages() {
  local pm="$1"
  if [[ "$pm" == "apt" ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y curl openssh-client openssh-server ca-certificates nano grep sed gawk coreutils findutils rsync snapd jq
  fi
}

ensure_certbot_main() {
  say "Проверяю certbot и Cloudflare DNS plugin..."
  systemctl enable --now snapd.socket >/dev/null 2>&1 || true
  snap install core >/dev/null 2>&1 || true
  snap refresh core >/dev/null 2>&1 || true
  snap install --classic certbot >/dev/null 2>&1 || true
  snap set certbot trust-plugin-with-root=ok >/dev/null 2>&1 || true
  snap install certbot-dns-cloudflare >/dev/null 2>&1 || true
  ln -sf /snap/bin/certbot /usr/bin/certbot
  certbot plugins | grep -q 'dns-cloudflare' || die "Плагин dns-cloudflare не найден после установки."
}

prompt_default() {
  local prompt="$1" default="${2:-}" value
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " value || true
    printf '%s' "${value:-$default}"
  else
    read -r -p "$prompt: " value || true
    printf '%s' "$value"
  fi
}

prompt_yes_no() {
  local prompt="$1" default="${2:-N}" value
  local suffix="[y/N]"
  [[ "$default" =~ ^[Yy]$ ]] && suffix="[Y/n]"
  read -r -p "$prompt $suffix: " value || true
  value="${value:-$default}"
  [[ "$value" =~ ^[Yy]$ ]]
}

collect_nodes() {
  local nodes=()
  echo
  echo "Введи список нод в формате user@host. Пустая строка завершит ввод."
  while true; do
    local line
    read -r -p "node> " line || true
    [[ -z "$line" ]] && break
    nodes+=("$line")
  done
  printf '%s\n' "${nodes[@]}"
}

deploy_ssh_keys_interactive() {
  local nodes_file="$1"
  [[ -s "$nodes_file" ]] || { warn "nodes.txt пустой, пропускаю деплой ключей."; return 0; }

  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  if [[ ! -f /root/.ssh/id_ed25519 ]]; then
    say "Генерирую SSH-ключ для main..."
    ssh-keygen -t ed25519 -C "ssl-renewal@$(hostname -f 2>/dev/null || hostname)" -f /root/.ssh/id_ed25519 -N ""
  fi

  if ! prompt_yes_no "Попробовать раскидать публичный SSH ключ на ноды сейчас?" "Y"; then
    cat <<EOF

Ручной вариант:
1. Возьми публичный ключ:
   cat /root/.ssh/id_ed25519.pub
2. Добавь его на каждую ноду в ~/.ssh/authorized_keys
3. Затем продолжи установку и проверь доступ:
   ssh root@NODE "hostname"

EOF
    return 0
  fi

  if ! command -v ssh-copy-id >/dev/null 2>&1; then
    apt-get install -y openssh-client >/dev/null 2>&1 || true
  fi

  while IFS= read -r node || [[ -n "$node" ]]; do
    [[ -z "$node" ]] && continue
    say "Пробую настроить SSH доступ для $node"
    if ssh -o BatchMode=yes -o ConnectTimeout=8 "$node" "echo ok" </dev/null >/dev/null 2>&1; then
      say "Ключ уже работает для $node"
      continue
    fi

    echo
    echo "Если у ноды открыт вход по паролю, сейчас ssh-copy-id попросит пароль."
    echo "Если вход только по ключу и текущий ключ не подходит, просто прерви и добавь ключ вручную."
    if ssh-copy-id -i /root/.ssh/id_ed25519.pub "$node"; then
      say "SSH ключ добавлен на $node"
    else
      warn "Не удалось автоматически добавить ключ на $node."
      cat <<EOF
Альтернатива для ручной установки:
  cat /root/.ssh/id_ed25519.pub
  # вставь ключ на ноде в ~/.ssh/authorized_keys
После этого проверь:
  ssh $node "hostname"

EOF
    fi
  done < "$nodes_file"
}

write_main_config() {
  local domain="$1" propagation="$2" target_dir="$3" cf_ini="$4" telegram_enabled="$5" bot_token="$6" chat_id="$7" region_csv="$8"
  mkdir -p "${ETC_DIR}" "${APP_DIR}" "${APP_DIR}/logs"
  cat > "${ETC_DIR}/config.env" <<EOF
ROLE="main"
APP_DIR="${APP_DIR}"
ETC_DIR="${ETC_DIR}"
PRIMARY_DOMAIN="${domain}"
TARGET_DIR="${target_dir}"
CERT_DIR="/etc/letsencrypt/live/${domain}"
CLOUDFLARE_CREDENTIALS="${cf_ini}"
DNS_PROPAGATION_SECONDS="${propagation}"
REGION_WILDCARDS_CSV="${region_csv}"
NODES_FILE="${ETC_DIR}/nodes.txt"
LOG_DIR="${APP_DIR}/logs"
TELEGRAM_ENABLED="${telegram_enabled}"
TELEGRAM_BOT_TOKEN="${bot_token}"
TELEGRAM_CHAT_ID="${chat_id}"
DEVELOPER_NAME="Indie_Master"
DEVELOPER_GITHUB="https://github.com/indie-master"
EOF
  chmod 600 "${ETC_DIR}/config.env"
}

write_node_config() {
  local domain="$1" target_dir="$2"
  mkdir -p "${ETC_DIR}" "${APP_DIR}" "${APP_DIR}/logs"
  cat > "${ETC_DIR}/config.env" <<EOF
ROLE="node"
APP_DIR="${APP_DIR}"
ETC_DIR="${ETC_DIR}"
PRIMARY_DOMAIN="${domain}"
TARGET_DIR="${target_dir}"
CERT_DIR="${target_dir}"
LOG_DIR="${APP_DIR}/logs"
TELEGRAM_ENABLED="0"
DEVELOPER_NAME="Indie_Master"
DEVELOPER_GITHUB="https://github.com/indie-master"
EOF
  chmod 600 "${ETC_DIR}/config.env"
}

install_runtime_files() {
  install -m 755 "${REPO_SCRIPTS_DIR}/ssl-renewal" "${APP_DIR}/ssl-renewal"
  install -m 755 "${REPO_SCRIPTS_DIR}/lib.sh" "${APP_DIR}/lib.sh"
  install -m 755 "${REPO_SCRIPTS_DIR}/deploy-certs.sh" "${APP_DIR}/deploy-certs.sh"
  install -m 755 "${REPO_SCRIPTS_DIR}/telegram-notify.sh" "${APP_DIR}/telegram-notify.sh"
  install -m 755 "${REPO_SCRIPTS_DIR}/node-prep.sh" "${APP_DIR}/node-prep.sh"
  install -m 755 "${REPO_SCRIPTS_DIR}/node-nginx-patch.sh" "${APP_DIR}/node-nginx-patch.sh"
  install -m 755 "${REPO_SCRIPTS_DIR}/disable-renew-on-nodes.sh" "${APP_DIR}/disable-renew-on-nodes.sh"
  ln -sf "${APP_DIR}/ssl-renewal" "${BIN_LINK}"
}

write_certbot_hook() {
  mkdir -p /etc/letsencrypt/renewal-hooks/deploy
  cat > /etc/letsencrypt/renewal-hooks/deploy/ssl-renewal-deploy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -x /opt/ssl-renewal/deploy-certs.sh ]]; then
  /opt/ssl-renewal/deploy-certs.sh
fi
EOF
  chmod +x /etc/letsencrypt/renewal-hooks/deploy/ssl-renewal-deploy.sh
}

issue_main_certificate() {
  local domain="$1" propagation="$2" cf_ini="$3" region_csv="$4"
  local -a cmd
  cmd=(certbot certonly --cert-name "$domain" --dns-cloudflare --dns-cloudflare-credentials "$cf_ini" --dns-cloudflare-propagation-seconds "$propagation" -d "$domain" -d "*.${domain}")
  IFS=',' read -r -a regions <<< "$region_csv"
  for region in "${regions[@]}"; do
    region="$(echo "$region" | xargs)"
    [[ -z "$region" ]] && continue
    cmd+=(-d "*.${region}.${domain}")
  done
  printf '\nКоманда выпуска сертификата:\n%s\n\n' "${cmd[*]}"
  if prompt_yes_no "Получить/обновить сертификат сейчас?" "Y"; then
    "${cmd[@]}"
  else
    warn "Пропускаю выпуск сертификата. Позже можно запустить: ssl-renewal issue"
  fi
}

write_nodes_file() {
  local nodes_file="${ETC_DIR}/nodes.txt"
  cat > "$nodes_file"
  chmod 600 "$nodes_file"
}

configure_node_host() {
  local domain="$1" target_dir="$2"
  say "Подготавливаю node..."
  "${APP_DIR}/node-prep.sh"
  if prompt_yes_no "Попробовать автоматически переписать ssl_certificate пути в nginx на ${target_dir}?" "N"; then
    "${APP_DIR}/node-nginx-patch.sh" --apply
  else
    cat <<EOF

Ручной шаблон для nginx:
  ssl_certificate     ${target_dir}/fullchain.pem;
  ssl_certificate_key ${target_dir}/privkey.pem;

Потом:
  nginx -t && systemctl reload nginx

EOF
  fi
}


cloudflare_token_instructions() {
cat <<'EOF'
Как получить Cloudflare API Token:
  1. Открой Cloudflare Dashboard.
  2. Перейди: My Profile -> API Tokens -> Create Token.
  3. Выбери шаблон "Edit zone DNS" или создай custom token.
  4. Выдай права:
       - Zone -> DNS -> Edit
       - Zone -> Zone -> Read
  5. Zone Resources: Include -> Specific zone -> нужная зона (например swiftlessvpn.ru)
  6. Create Token и сохрани его.

Токен будет сохранён в:
  /root/.secrets/certbot/cloudflare.ini

Позже токен можно изменить через:
  ssl-renewal edit-config
и вручную поправить файл credentials.
EOF
}

main_install_flow() {
  ensure_certbot_main

  local domain propagation target_dir region_csv cf_token cf_ini telegram_enabled="0" bot_token="" chat_id=""
  domain="$(prompt_default 'Основной домен' 'swiftlessvpn.ru')"
  propagation="$(prompt_default 'DNS propagation seconds для Cloudflare' '60')"
  target_dir="/etc/letsencrypt/live/${domain}"
  target_dir="$(prompt_default 'Путь, куда nodes будут складывать сертификаты' "$target_dir")"
  region_csv="$(prompt_default 'Список региональных wildcard зон через запятую (пример: de,msk,sk,us)' 'de,msk,sk,us')"

  echo
  echo "Для main нужен Cloudflare API Token с правами Zone:DNS Edit и Zone:Read."
  if prompt_yes_no "Показать краткую инструкцию по получению Cloudflare API Token?" "Y"; then
    cloudflare_token_instructions
  fi

  mkdir -p /root/.secrets/certbot
  cf_ini="/root/.secrets/certbot/cloudflare.ini"

  if prompt_yes_no "Внести Cloudflare API Token сейчас?" "Y"; then
    cf_token="$(prompt_default 'Cloudflare API Token' '')"
    [[ -n "$cf_token" ]] || die "Cloudflare API Token обязателен, если ты выбрал ввод сейчас."
    cat > "$cf_ini" <<EOF
dns_cloudflare_api_token = ${cf_token}
EOF
    chmod 600 "$cf_ini"
  else
    warn "Токен сейчас не внесён. Выпуск сертификата будет пропущен до тех пор, пока ты не заполнишь ${cf_ini}."
    cat > "$cf_ini" <<'EOF'
dns_cloudflare_api_token = PUT_YOUR_TOKEN_HERE
EOF
    chmod 600 "$cf_ini"
  fi

  if prompt_yes_no "Включить уведомления в Telegram?" "Y"; then
    telegram_enabled="1"
    bot_token="$(prompt_default 'Telegram BOT token' '')"
    chat_id="$(prompt_default 'Telegram chat_id' '')"
  fi

  write_main_config "$domain" "$propagation" "$target_dir" "$cf_ini" "$telegram_enabled" "$bot_token" "$chat_id" "$region_csv"
  install_runtime_files

  local tmp_nodes
  tmp_nodes="$(mktemp)"
  collect_nodes > "$tmp_nodes"
  cat "$tmp_nodes" > "${ETC_DIR}/nodes.txt"
  chmod 600 "${ETC_DIR}/nodes.txt"
  deploy_ssh_keys_interactive "${ETC_DIR}/nodes.txt"
  write_certbot_hook

  if [[ -s "${ETC_DIR}/nodes.txt" ]] && prompt_yes_no "Отключить renewal hooks/timers на нодах после первого деплоя?" "Y"; then
    touch "${APP_DIR}/.disable_nodes_after_first_deploy"
  else
    rm -f "${APP_DIR}/.disable_nodes_after_first_deploy"
  fi

  if grep -q 'PUT_YOUR_TOKEN_HERE' "$cf_ini"; then
    warn "Cloudflare token ещё не задан. Пропускаю выпуск сертификата."
    cat <<EOF

Чтобы продолжить позже:
  1. Открой ${cf_ini}
  2. Вставь реальный Cloudflare API Token
  3. Запусти:
     ssl-renewal issue
     ssl-renewal deploy

EOF
  else
    issue_main_certificate "$domain" "$propagation" "$cf_ini" "$region_csv"
  fi

  if [[ -s "${ETC_DIR}/nodes.txt" ]] && prompt_yes_no "Сразу доставить сертификаты на ноды?" "Y"; then
    "${APP_DIR}/deploy-certs.sh" || true
    if [[ -f "${APP_DIR}/.disable_nodes_after_first_deploy" ]]; then
      "${APP_DIR}/disable-renew-on-nodes.sh" || true
    fi
  fi

  cat <<EOF

Установка main завершена.
Дальше команды:
  ssl-renewal doctor
  ssl-renewal status
  ssl-renewal dry-run
  ssl-renewal issue
  ssl-renewal deploy
  ssl-renewal edit-config

EOF
}

node_install_flow() {
  local domain target_dir
  domain="$(prompt_default 'Основной домен сертификата, который приходит с main' 'swiftlessvpn.ru')"
  target_dir="/etc/letsencrypt/live/${domain}"
  target_dir="$(prompt_default 'Единый путь к сертификату на node' "$target_dir")"

  write_node_config "$domain" "$target_dir"
  install_runtime_files
  configure_node_host "$domain" "$target_dir"

  cat <<EOF

Установка node завершена.
Полезные команды:
  ssl-renewal doctor
  ssl-renewal status
  ssl-renewal patch-nginx
  ssl-renewal reload

EOF
}

main() {
  require_root
  banner
  local pm
  pm="$(detect_pkg_manager)"
  ensure_base_packages "$pm"

  local role="${1:-}"
  if [[ -z "$role" ]]; then
    echo
    echo "Выбери роль:"
    echo "  1) main"
    echo "  2) node"
    read -r -p "Роль [1/2]: " ans || true
    case "${ans:-1}" in
      1) role="main" ;;
      2) role="node" ;;
      *) die "Неизвестный выбор роли." ;;
    esac
  fi

  case "$role" in
    main|--role=main) main_install_flow ;;
    node|--role=node) node_install_flow ;;
    *) die "Использование: ./install.sh [main|node|--role=main|--role=node]" ;;
  esac
}

main "$@"
