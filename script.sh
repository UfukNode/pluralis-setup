#!/usr/bin/env bash
set -euo pipefail

NC='\033[0m'; BOLD='\033[1m'
PURPLE='\033[1;35m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; YELLOW='\033[1;33m'; RED='\033[1;31m'
say(){ printf "%b%s%b\n" "$1" "$2" "$NC"; }

banner() {
  printf "\n${PURPLE}${BOLD}========================================${NC}\n"
  printf "${PURPLE}${BOLD}   UFUKDEGEN Tarafından Hazırlanmıştır  ${NC}\n"
  printf "${PURPLE}${BOLD}========================================${NC}\n\n"
}

need_root(){ if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then say "$RED" "[HATA] Lütfen sudo ile (root) çalıştırın."; exit 1; fi; }
check_apt(){ command -v apt >/dev/null 2>&1 || { say "$RED" "[HATA] Yalnızca Debian/Ubuntu (apt) için."; exit 1; }; }

install_pkgs() {
  say "$CYAN" "[INFO] Paket listesi güncelleniyor..."
  DEBIAN_FRONTEND=noninteractive apt update -y >/dev/null
  DEBIAN_FRONTEND=noninteractive apt upgrade -y >/dev/null || true
  say "$CYAN" "[INFO] Gerekli paketler kuruluyor..."
  DEBIAN_FRONTEND=noninteractive apt install -y \
    htop ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    tmux iptables curl nvme-cli git wget make jq libleveldb-dev build-essential \
    pkg-config ncdu tar clang bsdmainutils lsb-release libssl-dev libreadline-dev \
    libffi-dev gcc screen file unzip lz4 bzip2 >/dev/null
  say "$GREEN" "[OK] Paket kurulumu tamam."
}

conda_hook() {
  local cbin
  cbin="$(command -v conda || true)"
  [[ -z "$cbin" && -x /opt/miniconda/bin/conda ]] && cbin=/opt/miniconda/bin/conda
  [[ -z "$cbin" ]] && return 1
  eval "$("$cbin" shell.bash hook)"
}

ensure_conda() {
  if conda_hook 2>/dev/null; then
    say "$GREEN" "[OK] Conda bulundu."
    return
  fi
  say "$CYAN" "[INFO] Miniconda kuruluyor..."
  cd /tmp
  MINICONDA=Miniconda3-latest-Linux-x86_64.sh
  wget -q https://repo.anaconda.com/miniconda/${MINICONDA} -O ${MINICONDA}
  bash ${MINICONDA} -b -p /opt/miniconda
  rm -f ${MINICONDA}
  conda_hook >/dev/null
  say "$GREEN" "[OK] Miniconda kuruldu."
}

clone_repo() {
  local DEST="${HOME}/node0"
  if [[ -d "${DEST}/.git" ]]; then
    say "$GREEN" "[OK] Repo mevcut: ${DEST}"
  else
    say "$CYAN" "[INFO] node0 deposu klonlanıyor..."
    git clone https://github.com/PluralisResearch/node0 "${DEST}" >/dev/null
    say "$GREEN" "[OK] Repo klonlandı."
  fi
  cd "${DEST}"
}

create_env_and_install() {
  conda_hook >/dev/null
  if conda env list | grep -qE '^\s*node0\s'; then
    say "$GREEN" "[OK] 'node0' ortamı mevcut."
  else
    say "$CYAN" "[INFO] 'node0' ortamı oluşturuluyor (python=3.11)..."
    conda create -y -n node0 python=3.11 >/dev/null
    say "$GREEN" "[OK] 'node0' ortamı oluşturuldu."
  fi
  say "$CYAN" "[INFO] node0 paketi kuruluyor (pip install .)..."
  conda run -n node0 python -m pip install --upgrade pip >/dev/null
  conda run -n node0 python -m pip install . >/dev/null
  say "$GREEN" "[OK] node0 paketi kuruldu."
}

get_inputs() {
  printf "${CYAN}[INFO]${NC} Başlangıç bilgilerini giriniz:\n"
  printf "  HF Token: "; read -r HF_TOKEN; while [[ -z "${HF_TOKEN}" ]]; do printf "${YELLOW}[WARN] Boş olamaz. HF Token: ${NC}"; read -r HF_TOKEN; done
  printf "  Email: "; read -r EMAIL_ADDR; while [[ -z "${EMAIL_ADDR}" ]]; do printf "${YELLOW}[WARN] Boş olamaz. Email: ${NC}"; read -r EMAIL_ADDR; done
  EMAIL_ADDR="$(printf '%s' "$EMAIL_ADDR" | tr -cd '[:print:]')"   # görünmeyen char temizle
  printf "  Announce Port (A_Port) [örn: 25xxx]: "; read -r ANN_PORT
  while ! [[ "${ANN_PORT}" =~ ^[0-9]+$ ]]; do printf "${YELLOW}[WARN] Sayı giriniz. A_Port: ${NC}"; read -r ANN_PORT; done
  HOST_PORT=49200
  export HF_TOKEN EMAIL_ADDR ANN_PORT HOST_PORT
  say "$GREEN" "[OK] Girdiler alındı."
}

generate_start_script() {
  say "$CYAN" "[INFO] start_server.sh üretiliyor (otomatik 'n')..."
  conda_hook >/dev/null
  bash -lc "
    export PYTHONUTF8=1 LC_ALL=C.UTF-8 LANG=C.UTF-8
    if command -v conda >/dev/null 2>&1; then eval \"\$(conda shell.bash hook)\"; fi
    conda activate node0
    printf 'n\n' | python3 generate_script.py \
      --host_port ${HOST_PORT} \
      --announce_port ${ANN_PORT} \
      --token ${HF_TOKEN} \
      --email ${EMAIL_ADDR}
  "
  [[ -f "./start_server.sh" ]] || { say "$RED" "[HATA] start_server.sh üretilemedi!"; exit 1; }
  say "$GREEN" "[OK] start_server.sh hazır."
}

create_wrapper() {
  cat > script.sh <<'EOS'
set -u
cd "$(dirname "$0")"
trap 'exit 0' INT
export PYTHONUTF8=1 LC_ALL=C.UTF-8 LANG=C.UTF-8
if command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)"
elif [[ -x /opt/miniconda/bin/conda ]]; then
  eval "$(/opt/miniconda/bin/conda shell.bash hook)"
fi
conda activate node0
./start_server.sh
while :; do sleep 3600; done
EOS
  chmod +x script.sh
  say "$GREEN" "[OK] script.sh oluşturuldu."
}

start_in_screen() {
  screen -S pluralis -X quit >/dev/null 2>&1 || true
  screen -S pluralis -dm bash -lc "cd ~/node0 && ./script.sh"
  say "$GREEN" "[OK] 'pluralis' screen oluşturuldu ve node başlatıldı."
}

tips() {
  printf "\n${BOLD}Kontrol Komutları:${NC}\n"
  printf "  • Screen'e bağlan:  ${CYAN}screen -r pluralis${NC}\n"
  printf "  • Ekrandan ayrıl:   ${CYAN}Ctrl-A, sonra D${NC}\n"
  printf "  • Kapatmak istersen: ${CYAN}screen -S pluralis -X quit${NC}\n\n"
}

main() {
  banner
  need_root
  check_apt
  install_pkgs
  ensure_conda
  clone_repo
  create_env_and_install
  get_inputs
  generate_start_script
  create_wrapper
  start_in_screen
  tips
}

main "$@"
