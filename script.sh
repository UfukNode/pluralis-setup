#!/usr/bin/env bash

set -euo pipefail

banner() {
  echo
  echo "========================================"
  echo "   UFUKDEGEN Tarafından Hazırlanmıştır  "
  echo "========================================"
  echo
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[HATA] Lütfen scripti root olarak çalıştırın (sudo ile)."
    exit 1
  fi
}

confirm_debian() {
  command -v apt >/dev/null 2>&1 || { echo "[HATA] Bu script Debian/Ubuntu içindir."; exit 1; }
}

install_packages() {
  echo "[INFO] Paket listesi güncelleniyor..."
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
  command -v conda >/dev/null 2>&1 || eval "$(/opt/miniconda/bin/conda shell.bash hook)"
  if ! conda env list | grep -qE '^\s*node0\s'; then
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
  read -rp "HF Token: " HF_TOKEN;      while [[ -z "${HF_TOKEN}" ]];   do read -rp "HF Token boş olamaz: " HF_TOKEN; done
  read -rp "Email: " EMAIL_ADDR;       while [[ -z "${EMAIL_ADDR}" ]]; do read -rp "Email boş olamaz: " EMAIL_ADDR; done
  read -rp "Announce Port (A_Port): " ANN_PORT
  while ! [[ "${ANN_PORT}" =~ ^[0-9]+$ ]]; do read -rp "Geçerli bir port girin (sayı): " ANN_PORT; done
  HOST_PORT=49200
  export HF_TOKEN EMAIL_ADDR ANN_PORT HOST_PORT
}

generate_start_script() {
  echo "[INFO] generate_script.py çalıştırılıyor, 'n' cevabı otomatik gönderilecek..."
  command -v conda >/dev/null 2>&1 || eval "$(/opt/miniconda/bin/conda shell.bash hook)"
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

# Node'u başlatır, ardından logları canlı olarak ekrana (ve dosyaya) akıtır.
start_and_tail() {
  echo "----- $(date) | start_server.sh başlatılıyor -----" | tee -a logs/run.out

  # start_server.sh bazı kurulumlarda arka plana atıp dosyaya loglayabilir.
  # Bu yüzden çıktıyı doğrudan ekrana alamayabiliriz; onun yerine dosyaları tail edeceğiz.
  if command -v conda >/dev/null 2>&1; then
    conda run -n node0 bash -lc "./start_server.sh" || true &
  else
    /opt/miniconda/bin/conda run -n node0 bash -lc "./start_server.sh" || true &
  fi

  # Biraz nefes ver, log dosyaları oluşsun
  sleep 3
  touch logs/run.out 2>/dev/null || true
  touch logs/server.log 2>/dev/null || true

  # Hem run.out hem server.log'u canlı izle
  tail -n +1 -F logs/run.out logs/server.log &
  TAILPID=$!

  # Ana süreç çalıştığı sürece bekle
  # node0 süreçlerini izlemek için basit bir döngü:
  while pgrep -f 'python.*node0|hivemind|averager|server.runtime' >/dev/null 2>&1; do
    sleep 5
  done

  # Süreç sonlandıysa tail'i kapat
  kill "${TAILPID}" >/dev/null 2>&1 || true
}

echo "[INFO] Gözetmen döngüsü başlıyor. Loglar ekranda ve logs/run.out içinde."
while true; do
  start_and_tail
  echo "[WARN] Node sonlandı. 10 sn sonra yeniden denenecek..." | tee -a logs/run.out
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
  echo "=================================================================="
  echo " Kurulum tamamlandı. Komutlar:"
  echo "  • Screen'e gir (canlı logları görmek için):  screen -r pluralis"
  echo "  • Ekrandan ayrıl:                            Ctrl-A, sonra D"
  echo "=================================================================="
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
