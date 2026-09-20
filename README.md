# RTL8188FTV / RTL8188FU USB WiFi — one-command driver installer

**For MX Linux (23.x) and Debian 12-style systems whose kernel is older than 6.2.**
**MX Linux 23.x ve 6.2'den eski çekirdek kullanan Debian 12 tabanlı sistemler için.**

---

## English

### The problem

Cheap Realtek USB WiFi sticks with the Realtek **RTL8188FTV / RTL8188FU** chip (USB ID `0bda:f179`)
are *detected* by the kernel but get **no driver** on kernels older than 6.2 — `lsusb` lists the
adapter, `lsusb -t` shows an empty `Driver=` field, and no `wlanX` interface appears.

Mainline support for this chip arrived with **rtl8xxxu in kernel 6.2**. MX Linux 23.x and Debian 12
ship kernel **6.1.x**, and no `rtl8188fu` package exists in the Debian/MX repositories
(`rtl8812au`, `rtl8814au`, `rtl8821au`, `rtl8821ce`, `rtl8821cu` are packaged — this one is not).
So the driver has to be built out of tree, and that is what this installer does — **via DKMS**, so it
survives kernel updates.

### Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/tarcanm/rtl8188ftv-installer/main/install.sh | sudo bash
```

or, if you prefer to look at the script first:

```bash
git clone https://github.com/tarcanm/rtl8188ftv-installer.git
cd rtl8188ftv-installer
sudo bash install.sh
```

Report only, change nothing:

```bash
sudo bash install.sh --check
```

### What the installer does

1. Finds the adapter on USB (prefers direct ports over hubs, and tells you if it is missing).
2. Checks whether it already works — if an interface exists, it stops instead of touching the system.
3. Installs `build-essential`, `git`, `dkms` and `linux-headers-$(uname -r)`.
4. Clones the upstream driver (https://github.com/kelebek333/rtl8188fu) to `/usr/src/rtl8188fu`.
5. Builds and installs it with DKMS (`dkms install`, with an `add`/`build`/`install` fallback).
6. Copies `rtl8188fufw.bin` to `/lib/firmware/rtlwifi/` and writes
   `/etc/modprobe.d/rtl8188fu.conf` (`rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0`, which avoids
   the usual drop-outs and plug/re-plug failures). On kernel 6.2+ it also writes an alias so the
   DKMS module wins over the built-in `rtl8xxxu`.
7. Loads the module and prints the result. Full log: `/var/log/rtl8188ftv-install.log`.

### Verify

```bash
lsmod | grep rtl8188fu                    # module loaded
ip -br link | grep '^wl'                  # interface present (new one, e.g. wlan1)
nmcli dev wifi list                       # networks visible
dkms status | grep 8188                   # survives kernel updates
```

Connect with `nmcli dev wifi connect "SSID" password "PASSWORD"`, or use the desktop's network applet.

### Troubleshooting

- **No `wlanX` after install:** read the log (`/var/log/rtl8188ftv-install.log`) and `dmesg | tail -40`.
- **Adapter on a hub:** USB hubs share power; a direct rear port is more reliable, especially with a
  webcam or Bluetooth stick on the same hub.
- **Wrong interface sleeps/drops:** the installer already disables power management; re-plug after
  install to be sure the option applies.
- **Soft-blocked:** `sudo apt install rfkill && rfkill list` — if it shows a block, `rfkill unblock wifi`.
- **Kernel 6.2 or newer:** the in-kernel `rtl8xxxu` already supports the chip, so this driver is not
  required; the installer adds the alias so the DKMS copy takes precedence, and `uninstall.sh` hands
  the device back to the kernel driver.
- **Random MAC each boot:** optional, if your network rejects it —
  `echo -e "[device]\nwifi.scan-rand-mac-address=no" | sudo tee /etc/NetworkManager/conf.d/disable-random-mac.conf`

### Uninstall

```bash
sudo bash uninstall.sh
```

### Credits and license

- Driver source: [kelebek333/rtl8188fu](https://github.com/kelebek333/rtl8188fu) — **GPL-2.0**, the
  Realtek out-of-tree driver for these adapters. It is fetched at install time, not vendored here.
- `install.sh` / `uninstall.sh` / this README: **MIT** (see `LICENSE`).
- Written and used on MX Linux 23.6 fluxbox (Debian 12, kernel 6.1.0-52, SysVinit).

---

## Türkçe

### Sorun

Realtek **RTL8188FTV / RTL8188FU** çipli ucuz USB WiFi adaptörleri (USB kimliği `0bda:f179`)
çekirdek **6.2'den eski** sürümlerde cihaz olarak *görülür* ama **sürücüsüz** kalır: `lsusb` adaptörü
listeler, `lsusb -t` çıktısındaki `Driver=` alanı **boş** olur ve hiç `wlanX` arayüzü çıkmaz.

Bu çipin çekirdek desteği **6.2'de rtl8xxxu** ile geldi. MX Linux 23.x ve Debian 12 **6.1.x** çekirdek
kullanır; ayrıca depolarında `rtl8188fu` paketi **yoktur** (paketlenmiş olanlar: `rtl8812au`,
`rtl8814au`, `rtl8821au`, `rtl8821ce`, `rtl8821cu`). Yani sürücünün çekirdek dışında derlenmesi
gerekir — bu betik tam olarak onu yapar, **DKMS** ile, böylece çekirdek güncellemelerinden sonra da
çalışmaya devam eder.

### Kurulum (tek komut)

```bash
curl -fsSL https://raw.githubusercontent.com/tarcanm/rtl8188ftv-installer/main/install.sh | sudo bash
```

Betiği önce görmek isterseniz:

```bash
git clone https://github.com/tarcanm/rtl8188ftv-installer.git
cd rtl8188ftv-installer
sudo bash install.sh
```

Sadece rapor (hiçbir şey değiştirmez):

```bash
sudo bash install.sh --check
```

### Betik ne yapar

1. Adaptörü USB'de bulur (hub yerine doğrudan portu önerir; takılı değilse söyler).
2. Zaten çalışıyor mu diye bakar — arayüz varsa sisteme dokunmadan durur.
3. `build-essential`, `git`, `dkms` ve `linux-headers-$(uname -r)` paketlerini kurar.
4. Sürücü kaynağını (`kelebek333/rtl8188fu`) `/usr/src/rtl8188fu` altına klonlar.
5. DKMS ile derleyip kurar (`dkms install`; olmazsa `add`/`build`/`install` yedeği).
6. Firmware'i `/lib/firmware/rtlwifi/rtl8188fufw.bin` olarak kopyalar ve
   `/etc/modprobe.d/rtl8188fu.conf` yazar (`rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0` — kopmaları
   ve tak/çıkar sorunlarını önler). Çekirdek 6.2+ ise, DKMS modülünün yerleşik `rtl8xxxu`'ya karşı
   kazanması için alias da yazar.
7. Modülü yükler ve sonucu yazar. Tam kayıt: `/var/log/rtl8188ftv-install.log`.

### Doğrulama

```bash
lsmod | grep rtl8188fu                    # modül yüklü
ip -br link | grep '^wl'                  # arayüz var (yeni olan, örn. wlan1)
nmcli dev wifi list                       # ağlar görünüyor
dkms status | grep 8188                   # çekirdek güncellemesinden sonra da sürer
```

Bağlanmak için: `nmcli dev wifi connect "SSID" password "ŞİFRE"` veya masaüstü ağ uygulaması.

### Sorun giderme

- **Kurulumdan sonra `wlanX` yok:** `/var/log/rtl8188ftv-install.log` ve `dmesg | tail -40`.
- **Adaptör hub'da:** USB hub'lar gücü paylaşır; özellikle webcam/Bluetooth aynı hub'daysa doğrudan
  arka port daha kararlıdır.
- **Kopmalar:** betik güç yönetimini zaten kapatır; seçeneğin uygulanması için kurulumdan sonra
  adaptörü bir kez çıkarıp takmak iyi olur.
- **Soft-block:** `sudo apt install rfkill && rfkill list` — blok görünüyorsa `rfkill unblock wifi`.
- **Çekirdek 6.2 ve üstü:** yerleşik `rtl8xxxu` bu çipi zaten destekler, sürücü gerekmez; betik alias
  yazarak DKMS kopyasını öne alır, `uninstall.sh` ise cihazı çekirdek sürücüsüne geri verir.
- **Her açılışta MAC değişiyorsa:** ağ kabul etmiyorsa —
  `echo -e "[device]\nwifi.scan-rand-mac-address=no" | sudo tee /etc/NetworkManager/conf.d/disable-random-mac.conf`

### Kaldırma

```bash
sudo bash uninstall.sh
```

### Emeği geçenler ve lisans

- Sürücü kaynağı: [kelebek333/rtl8188fu](https://github.com/kelebek333/rtl8188fu) — **GPL-2.0**,
  Realtek'in bu adaptörler için çekirdek dışı sürücüsü. Kurulum anında indirilir, burada kopyası
  tutulmaz.
- `install.sh` / `uninstall.sh` / bu README: **MIT** (bkz. `LICENSE`).
- MX Linux 23.6 fluxbox (Debian 12, çekirdek 6.1.0-52, SysVinit) üzerinde yazıldı ve kullanıldı.
