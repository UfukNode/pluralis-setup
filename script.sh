#!/usr/bin/env bash

set -euo pipefail

banner() {
  echo
  echo "========================================="
  echo "   UFUKDEGEN Tarafından Hazırlanmıştır   "
  echo "========================================="
  echo
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[HATA] Lütfen scripti root olarak çalıştırın (sudo ile)."
    exit 1
  fi
}

confirm_debian() {
  if ! command -v apt >/dev/null 2>&1; then
    echo "[HATA] Bu script Debian/Ubuntu (apt) tabanlı sistemler içindir."
    exit 1
  fi
}

install_packages() {
  echo "[INFO] Paket listesi güncelleniyor ve yükseltiliyor..."
  DEBIAN_FRONTEND=noninteractive apt update -y && apt upgrade -y
  echo "[INFO] Gerekli paketler kuruluyor..."
  DEBIAN_FRONTEND=noninteractive apt install -y \
    htop ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    tmux iptables curl nvme-cli git wget make jq libleveldb-dev build-essential \
    pkg-config ncdu tar clang bsdmainutils lsb-release libssl-dev libreadline-dev \
    libffi-dev gcc screen file unzip lz4 bzip2
}

ensure_conda() {
  if command -v conda >/dev/null 2>&1; then
    echo "[INFO] Conda bulundu."
    eval "$(conda shell.bash hook)" || true
    return
  fi
  echo "[INFO] Miniconda kuruluyor..."
  cd /tmp
  MINICONDA=Miniconda3-latest-Linux-x86_64.sh
  wget -q https://repo.anaconda.com/miniconda/${MINICONDA} -O ${MINICONDA}
  bash ${MINICONDA} -b -p /opt/miniconda
  rm -f ${MINICONDA}
  /opt/miniconda/bin/conda init bash >/dev/null 2>&1 || true
  eval "$(/opt/miniconda/bin/conda shell.bash hook)"
  echo "[INFO] Miniconda kuruldu."
}

clone_repo() {
  local DEST="${HOME}/node0"
  if [[ -d "${DEST}/.git" ]]; then
    echo "[INFO] node0 deposu mevcut: ${DEST}"
  else
    echo "[INFO] node0 deposu klonlanıyor..."
    git clone https://github.com/PluralisResearch/node0 "${DEST}"
  fi
  cd "${DEST}"
}

create_env_and_install() {
  if ! command -v conda >/dev/null 2>&1; then
    eval "$(/opt/miniconda/bin/conda shell.bash hook)"
  fi
  if conda env list | grep -qE '^\s*node0\s'; then
    echo "[INFO] 'node0' conda ortamı mevcut."
  else
    echo "[INFO] 'node0' ortamı oluşturuluyor (python=3.11)..."
    conda create -y -n node0 python=3.11
  fi
  echo "[INFO] node0 paketi kuruluyor (pip install .)..."
  conda run -n node0 python -m pip install --upgrade pip
  conda run -n node0 python -m pip install .
}

get_inputs() {
  echo
  echo "=== Başlangıç Scriptini Oluşturalım ==="
  echo " - HF Token (Hugging Face): https://huggingface.co/settings/tokens/new?tokenType=write"
  echo " - Email adresiniz"
  echo " - Announce Port (A_Port) → Vast 'public' port (ör: 25000 gibi)"
  echo

  read -rp "HF Token: " HF_TOKEN
  while [[ -z "${HF_TOKEN}" ]]; do read -rp "HF Token boş olamaz, tekrar girin: " HF_TOKEN; done

  read -rp "Email: " EMAIL_ADDR
  while [[ -z "${EMAIL_ADDR}" ]]; do read -rp "Email boş olamaz, tekrar girin: " EMAIL_ADDR; done

  read -rp "Announce Port (A_Port): " ANN_PORT
  while ! [[ "${ANN_PORT}" =~ ^[0-9]+$ ]]; do read -rp "Geçerli bir port girin (sayı): " ANN_PORT; done

  HOST_PORT=49200
  export HF_TOKEN EMAIL_ADDR ANN_PORT HOST_PORT
}

generate_start_script() {
  echo "[INFO] generate_script.py çalıştırılıyor, 'n' cevabı otomatik gönderilecek..."
  if ! command -v conda >/dev/null 2>&1; then
    eval "$(/opt/miniconda/bin/conda shell.bash hook)"
  fi
  # Interaktif shell + conda activate; stdin pipe ile 'n'
  bash -lc "
    source /opt/miniconda/etc/profile.d/conda.sh || true
    conda activate node0
    printf 'n\n' | python3 generate_script.py \
      --host_port ${HOST_PORT} \
      --announce_port ${ANN_PORT} \
      --token ${HF_TOKEN} \
      --email ${EMAIL_ADDR}
  "
  [[ -f "./start_server.sh" ]] || { echo "[HATA] start_server.sh üretilemedi."; exit 1; }
  echo "[OK] start_server.sh oluşturuldu."
}

create_supervisor() {
  echo "[INFO] Gözetmen script hazırlanıyor (canlı log + yeniden başlatma)..."
  mkdir -p logs
  cat > run_supervised.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p logs
trap 'echo "[INFO] Ctrl-C algılandı ama yoksayıldı. Çıkmak için: Ctrl-A, D";' INT

echo "[INFO] Gözetmen döngüsü başlıyor. Loglar hem ekranda hem logs/run.out içinde."
while true; do
  echo "----- $(date) | start_server.sh başlatılıyor -----" | tee -a logs/run.out
  if command -v conda >/dev/null 2>&1; then
    conda run -n node0 bash -lc "./start_server.sh" 2>&1 | tee -a logs/run.out
  else
    /opt/miniconda/bin/conda run -n node0 bash -lc "./start_server.sh" 2>&1 | tee -a logs/run.out
  fi
  echo "[WARN] start_server.sh sonlandı. 10 sn sonra yeniden denenecek..." | tee -a logs/run.out
  sleep 10
done
BASH
  chmod +x run_supervised.sh
}

start_in_screen() {
  echo "[INFO] 'pluralis' adlı screen oturumu başlatılıyor (detached)..."
  local WD="$(pwd)"
  screen -S pluralis -dm bash -lc "cd '${WD}' && ./run_supervised.sh"
}

print_help() {
  echo
  echo "==============================================================="
  echo " Kurulum tamamlandı. Komutlar:"
  echo "  • Screen'e gir (canlı logları görmek için):  screen -r pluralis"
  echo "  • Ekrandan ayrıl:                            Ctrl-A, sonra D"
  echo "==============================================================="
  echo
}

main() {
  banner
  require_root
  confirm_debian
  install_packages
  ensure_conda
  clone_repo
  create_env_and_install
  get_inputs
  generate_start_script
  create_supervisor
  start_in_screen
  print_help
}

main "$@"
