![GmaME6AXcAAKWdP](https://github.com/user-attachments/assets/b21b26a5-dba0-4fb1-b7ea-4ef978ef2d5f)

# Pluralis Node Kurulum Rehberi

İçeride 300 kişinin aktif node çalıştırdığı **@PluralisHQ** için adım adım kurulum rehberi.
Hiç bilmeyen biri bile rahatlıkla kurabilir.

---

## Sistem Gereksinimleri

| Gereksinim      | Detaylar                       |
| --------------- | ------------------------------ |
| RAM             | Minimum 16 GB                  |
| CPU             | 6–8 Çekirdek                   |
| GPU             | 16GB+ VRAM (RTX 3090 - A4000 önerilir) |
| Disk            | Minimum 120GB SSD              |

---

## 1- Vast.ai Kayıt – Bakiye Yükleme:

* [https://cloud.vast.ai/?ref\_id=222215](https://cloud.vast.ai/?ref_id=222215) adresine git.
* Sağ üstten **Login** butonuna tıkla ve kayıt ol.
* Sol menüden **Billing → Add Credit** kısmına gir.
* Yükleyeceğin miktarı seç ve **Stripe** ile bakiye yükle.

---

## 2- Huggingface Kayıt – Token Oluşturma:

* [https://huggingface.co](https://huggingface.co) adresine git ve kayıt ol.
* **Settings → Access Token** bölümüne gir.
* **Create New Token** butonuna tıkla.
* **Write** seç, isim ver ve oluştur.
* Oluşturduğun bir yere tokeni kaydet.

![1](https://github.com/user-attachments/assets/b1c8a4e2-c071-401c-886b-1086a7039f04)

---

## 3- Template ve Filtre Ayarları:

* Soldan **Templates** kısmına tıkla.
* En üsttekini seç **NVIDIA CUDA** template'i seçin.
* GPU kısmını **RTX 3090** ile *a4000* yap.
* **Planet Earth** kısmını **North America** seç.
* **Auto Short** kısmını **Price Inc** yap.

---

## 4- 49200 Port Ekleme ve Sunucu Seçimi:

* “NVIDIA Cuda” altındaki kalem ikonuna tıkla.
* Port kısmına **49200** yaz.
* “+” butonuna bas, ardından **Save & Use** seç.
* İnterneti güçlü (500Mbps+) bir sunucu seç.

---

## 5- Terminale Giriş:

* Soldan **Instances** bölümüne git.
* Sunucunun sağındaki terminal ikonuna tıkla.
* **Open Jupyter Terminal** seç.
* Terminal açılması için sunucunun çalışıyor olması gerekir.

---

## 6- Node’u Başlat:

Terminale şu komutları girin:

```bash
wget https://raw.githubusercontent.com/UfukNode/pluralis-setup/refs/heads/main/script.sh
chmod 777 ./script.sh
./script.sh
```

---

## 7- Bilgileri Gir:

**Huggingface / Mail:**

* Huggingface token’i girip Enter’a basın.
* Mail adresinizi girip Enter’a basın.

**Host / Port:**

* Vast.ai → **Instances** bölümüne girin.
* Sunucunun üzerindeki **Verified** kısmının yanındaki IP’ye tıklayın ve kopyalayın.

---

## 8- Node Başlamış mı Kontrol:

Komutu girin:

```bash
screen -r pluralis
```

* Eğer loglarda saniye sayacı görünüyorsa kuyruktasınız.
* Biraz bekleyin, kısa süre içinde node’unuz aktifleşir ve dashboard’da görünür.

---

## 9- Dashboard Kontrol:

* https://dashboard.pluralis.ai/ dashboard bağlantısına git.
* Aşağı inip **sıralama** kısmına gel.
* Huggingface kullanıcı adınızı aratın.
* İsminiz çıkıyorsa node başlamıştır.

---

## 10- Gerekli Komutlar:

* Screen’e giriş:

```bash
screen -r pluralis
```

* Screen’den çıkış (kapatmadan): `CTRL + a + d`
* Screen’i kapatma: `CTRL + c`
* Node’u tekrar başlatma:

```bash
./script.sh
```

---

### UfukDegen
X: [https://x.com/UfukDegen](https://x.com/UfukDegen)

---
