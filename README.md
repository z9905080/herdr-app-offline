# herdr-app-offline

[Herdr](https://github.com/herdrdev/herdr-app) 桌面 App 官方預編譯 Linux binary 的離線安裝包，**同時附上 herdr-core (`hc`)**。給封閉內網用：clone（或複製）這個 repo 進去，執行 `install.sh` 就能用，**整個安裝過程不連網路**。適用 Ubuntu 24.04 和 22.04（x86_64 / arm64），不需要 root。**22.04 需要多裝一組較新的 Mesa，見 [Ubuntu 22.04](#ubuntu-2204)。**

## 一行安裝

```bash
git clone https://github.com/z9905080/herdr-app-offline.git && cd herdr-app-offline && ./install.sh
```

內網機器不能連 GitHub 的話，在外網 clone 好之後，把整個資料夾（或 `git bundle create herdr.bundle --all` 產生的檔案）帶進內網，再執行 `./install.sh`。

`install.sh` 做的事跟官方安裝程式（`https://releases.herdr.dev/app/install.sh`）一樣，只是把下載那一步換成用 repo 裡的檔案：

1. 用 `uname -m` 判斷架構（`x86_64`，或 `aarch64`/`arm64`）。
2. 在 `~/.local/bin/herdr-app` 建立 symlink，指向 repo 裡的 binary。
3. 把圖示複製到 `~/.local/share/icons/hicolor/scalable/apps/herdr-app.svg`，並建立 `~/.local/share/applications/herdr-app.desktop`（內容跟官方一樣），應用程式選單裡就會出現 Herdr。
4. **安裝 herdr-core**（官方安裝程式會另外上網下載，這裡直接用 repo 裡的）：
   - 還沒有 → 複製到 `~/.local/bin/herdr-core`，沒有 `hc` 指令的話再建 `~/.local/bin/hc` → `herdr-core` 的 symlink。
   - `~/.local/bin/herdr-core` 已存在但版本比較舊 → 用官方的 `herdr-core update --from` 平滑升級（正在跑的終端機不會中斷）。
   - 已存在且版本一樣或比較新，或是在其他路徑（套件管理器裝的） → 不動。
5. 如果 `~/.local/bin` 不在 PATH 裡，會提示你把它加進去。

可以重複執行，結果一樣。

### 選項

- `./install.sh --copy`：先把 App 複製到 `~/.local/share/herdr-app`（官方安裝位置）再建 symlink，之後刪掉這個 repo 也能用。
- `./install.sh --no-core`：不安裝／升級 herdr-core。
- 預設（不加參數）：symlink 直接指向 repo，**不要移動或刪除這個 repo 資料夾**。（herdr-core 一律是複製到 `~/.local/bin`，跟官方一樣。）

### 確認安裝

```bash
herdr-app --version   # herdr-app 0.1.12
hc --version          # hc 0.1.17
herdr-app             # 開啟視窗（需要圖形環境＋Vulkan，見下方）
```

### 移除

```bash
./uninstall.sh
```

只會刪除 install.sh 建立的 symlink、desktop 檔、圖示、（用過 `--copy` 時）`~/.local/share/herdr-app`，以及**由 install.sh 安裝的** herdr-core / `hc`。原本就存在的 herdr-core 和你的設定 `~/.config/herdr-app` 都不會動。

## 執行環境需求（Ubuntu 24.04）

`herdr-app` 是 GPU 繪圖的桌面程式（GPUI），需要：

| 用途 | 函式庫 | Ubuntu 24.04 套件 |
|---|---|---|
| 繪圖（必要） | `libvulkan.so.1` + Vulkan 驅動 | `libvulkan1`、`mesa-vulkan-drivers` |
| 鍵盤（必要，直接連結） | `libxkbcommon.so.0`、`libxkbcommon-x11.so.0` | `libxkbcommon0`、`libxkbcommon-x11-0` |
| X11（必要，直接連結） | `libxcb.so.1`、`libxcb-xkb.so.1` | `libxcb1`、`libxcb-xkb1`（會帶入 `libxau6`、`libxdmcp6`） |
| Wayland 桌面 | `libwayland-client.so.0`、`libwayland-egl.so.1`、`libEGL.so.1` | `libwayland-client0`、`libwayland-egl1`、`libegl1` |
| 字型（arm64 版直接連結） | `libfontconfig.so.1` | `libfontconfig1` |
| 基本 | glibc ≥ 2.35、`libgcc_s` | `libc6`、`libgcc-s1`（24.04 內建） |
| 選用：提示音 | `paplay` / `mpv` / `ffplay` / `mpg123` 任一 | `pulseaudio-utils` |
| 選用：檢查 Vulkan | `vulkaninfo` | `vulkan-tools` |

`herdr-core` 是靜態連結的 binary，沒有任何系統依賴。

Ubuntu 24.04 桌面版（GNOME）通常已經有以上全部套件。伺服器版 / 精簡安裝 / 沒有 GPU 的 VM 最常缺的是 `mesa-vulkan-drivers`（裡面的 lavapipe 是軟體 Vulkan，沒有 GPU 也能跑）。檢查方法：

```bash
ldd ~/.local/bin/herdr-app | grep 'not found'   # 沒輸出才正常
vulkaninfo --summary                            # 需要 vulkan-tools
```

### 在外網預先下載 apt 套件（離線用）

在一台能上網、有 Docker 的機器上，用乾淨的 Ubuntu 24.04 容器把套件和所有相依套件一起下載下來（容器是乾淨的，所以抓到的依賴最完整）：

```bash
PKGS="libvulkan1 mesa-vulkan-drivers libxkbcommon0 libxkbcommon-x11-0 libxcb1 libxcb-xkb1 \
      libwayland-client0 libwayland-egl1 libegl1 libfontconfig1 pulseaudio-utils vulkan-tools"

# x86_64
mkdir -p debs-amd64
docker run --rm --platform linux/amd64 -v "$PWD/debs-amd64:/debs" ubuntu:24.04 bash -c \
  "apt-get update && apt-get install -y --download-only -o Dir::Cache::archives=/debs $PKGS"

# arm64（需要 docker 支援 arm64 模擬，或直接在 arm64 機器上跑）
mkdir -p debs-arm64
docker run --rm --platform linux/arm64 -v "$PWD/debs-arm64:/debs" ubuntu:24.04 bash -c \
  "apt-get update && apt-get install -y --download-only -o Dir::Cache::archives=/debs $PKGS"
```

沒有 Docker 的話，在一台**同架構**的 Ubuntu 24.04 上：

```bash
mkdir -p debs && cd debs
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
  --no-conflicts --no-breaks --no-replaces --no-enhances $PKGS | grep '^\w' | sort -u)
```

把 `debs-*` 資料夾帶進內網，在目標機器上：

```bash
sudo apt-get install ./debs-amd64/*.deb    # arm64 機器改用 debs-arm64
```

（apt 會略過已經裝好的、版本相同的套件。內網機器如果更新過，版本可能比容器裡的新，那些套件會被略過，不影響使用。）

## Ubuntu 22.04

**可以用**，但 22.04 內建的 Mesa（23.2.1）太舊，要另外裝一組較新的 Mesa。

- **glibc**：兩個架構的 herdr-app 最高只要求 `GLIBC_2.35`，剛好是 22.04 的版本；沒有用到 `GLIBCXX`（不需要新的 libstdc++）。herdr-core 是靜態連結，沒有依賴。
- **函式庫**：需要的套件在 22.04 全部都有，**名稱跟 24.04 一樣**（上面那張表的套件 22.04 都適用）。
- **Mesa 太舊**：在 22.04 用內建的 Mesa 23.2.1，視窗會開出來但**整片黑色**，什麼都沒畫（用軟體 Vulkan lavapipe 測試；24.04 的 Mesa 同樣情況畫面正常）。換成 [kisak/turtle PPA](https://launchpad.net/~kisak/+archive/ubuntu/turtle) 的 Mesa 25.0.7（給 22.04 用的新版 Mesa）後就正常顯示。
  - 用 Intel / AMD 顯示卡、或 VM（沒有 GPU）的機器：**請裝新版 Mesa**（下面的步驟）。
  - 用 NVIDIA 官方驅動的機器：Vulkan 由 NVIDIA 驅動提供，不經過 Mesa，理論上不受影響，但**沒測過**；如果視窗是黑的，一樣照下面的步驟裝新版 Mesa。

### 22.04 要裝的套件

```bash
PKGS="libvulkan1 mesa-vulkan-drivers libegl-mesa0 libgl1-mesa-dri libglx-mesa0 libgbm1 mesa-libgallium \
      libxkbcommon0 libxkbcommon-x11-0 libxcb1 libxcb-xkb1 \
      libwayland-client0 libwayland-egl1 libegl1 libfontconfig1 pulseaudio-utils vulkan-tools"
```

（`libegl-mesa0`、`libgl1-mesa-dri`、`libglx-mesa0`、`libgbm1`、`mesa-libgallium` 要跟 `mesa-vulkan-drivers` 一起升到同一版，否則 apt 會有版本衝突。）

### 在外網預先下載 22.04 套件（離線用）

在一台能上網、有 Docker 的機器上，用乾淨的 `ubuntu:22.04` 容器加上 kisak/turtle PPA，把套件和所有相依套件下載下來：

```bash
# PPA 的簽章金鑰（Launchpad PPA for kisak，指紋 EB8B81E14DA65431D7504EA8F63F0F2B90935439）
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xEB8B81E14DA65431D7504EA8F63F0F2B90935439" -o kisak-turtle.asc

for ARCH in amd64 arm64; do      # 只需要一種就只留那一個
  mkdir -p debs-jammy-$ARCH
  docker run --rm --platform linux/$ARCH -e PKGS="$PKGS" \
    -v "$PWD/debs-jammy-$ARCH:/debs" -v "$PWD/kisak-turtle.asc:/k.asc:ro" ubuntu:22.04 bash -c '
      apt-get update && apt-get install -y ca-certificates &&
      cp /k.asc /etc/apt/trusted.gpg.d/kisak-turtle.asc &&
      echo "deb https://ppa.launchpadcontent.net/kisak/turtle/ubuntu jammy main" > /etc/apt/sources.list.d/kisak-turtle.list &&
      apt-get update && apt-get install -y --download-only -o Dir::Cache::archives=/debs $PKGS'
done
```

（`PKGS` 用上一節的 22.04 清單。arm64 需要 Docker 支援 arm64 模擬，或直接在 arm64 機器上跑。x86_64 大約 70 個 .deb、68 MB。）

把 `debs-jammy-*` 資料夾帶進內網，在 22.04 目標機器上：

```bash
sudo apt-get install ./debs-jammy-amd64/*.deb    # arm64 機器改用 debs-jammy-arm64
./install.sh
```

裝完後確認：

```bash
dpkg-query -W mesa-vulkan-drivers   # 要看到 25.0.7~kisak...，不是 23.2.1
ldd ~/.local/bin/herdr-app | grep 'not found'   # 沒輸出才正常
herdr-app
```

注意：

- 這會把整台機器的 Mesa（OpenGL / Vulkan 驅動）升級到 25.0.7，影響所有圖形程式。kisak 是 Ubuntu 社群常用的 Mesa PPA，但不是 Ubuntu 官方套件。
- 內網機器上已經裝的其他 Mesa 套件（例如 `mesa-va-drivers`、`libglapi-mesa`）會維持 23.2.1，跟新版並存，apt 不會報錯（已測試）。
- 要退回原本的 Mesa：在外網用同樣的容器、**不加 PPA**，下載 `mesa-vulkan-drivers libegl-mesa0 libgl1-mesa-dri libglx-mesa0 libgbm1` 的 23.2.1 版，帶進內網後用 `sudo apt-get install --allow-downgrades ./*.deb` 裝回去（這個步驟沒測過）。

## 離線使用注意事項

- Herdr 會定期檢查更新（`releases.herdr.dev`），內網連不到只會失敗，不影響使用；可以在設定（Settings → Updates）裡關掉。
- 意見回饋功能會連 `telemetry.herdr.dev`，內網無法使用。
- 要升級：在外網更新這個 repo（或等新版），`git pull` 後帶進內網再跑一次 `./install.sh`。herdr-core 會用 `update --from` 平滑升級。
- 此版本 App 要求 herdr-core ≥ 0.1.11（`core_min`），附的是 0.1.17。

## 目錄結構

```
x86_64/herdr-app/    herdr-app-linux-x86_64.tar.gz 解壓後的內容（herdr-app、herdr-app.svg、LICENSE、THIRD-PARTY-NOTICES）
x86_64/herdr-core/   herdr-core-linux-x86_64.tar.gz 解壓後的內容（herdr-core、LICENSE、THIRD-PARTY-NOTICES）
arm64/herdr-app/     herdr-app-linux-aarch64.tar.gz 解壓後的內容
arm64/herdr-core/    herdr-core-linux-aarch64.tar.gz 解壓後的內容
install.sh / uninstall.sh
SHA256SUMS           原始 tarball 的 SHA256
```

## 來源與驗證

- 版本：**herdr-app 0.1.12**、**herdr-core 0.1.17**（2026-11-03 時 `releases.herdr.dev` 上的最新版）
- 來源：官方 release manifest
  - <https://releases.herdr.dev/app/latest.json>（→ `app/0.1.12/herdr-app-linux-{x86_64,aarch64}.tar.gz`）
  - <https://releases.herdr.dev/core/latest.json>（→ `core/0.1.17/herdr-core-linux-{x86_64,aarch64}.tar.gz`）
- 檔案為官方原檔，未修改，只是解壓。官方沒有提供 GPG/minisign 簽章，只在 manifest 裡提供 SHA256（官方安裝程式也只驗這個）；下載後已逐一比對，全部吻合：

```
a265e6c925c487458406741ffa09d2fa0d3d4bd401a34ed8c01c336108e57c1f  herdr-app-linux-x86_64.tar.gz
749f31d30e3f4d7e24e2748f74d9cb4a9bdda4c968027abaffb6fb239ffeb694  herdr-app-linux-aarch64.tar.gz
82ec44043f6894bfdb716b979b87cda43fd7fa46b0104e7b7bd93e64d1a9b877  herdr-core-linux-x86_64.tar.gz
3a37a454ec63494cf4306db26481fe9db96673d888723701d24f8a992ae8ab8c  herdr-core-linux-aarch64.tar.gz
```

## 原始 tarball（Release）

原本的 4 個 `.tar.gz` 和 `SHA256SUMS` 放在 [Release v0.1.12](https://github.com/z9905080/herdr-app-offline/releases/tag/v0.1.12)，可以直接下載：

```bash
curl -LO https://github.com/z9905080/herdr-app-offline/releases/download/v0.1.12/herdr-app-linux-x86_64.tar.gz
```

## 授權

Herdr（herdr-app、herdr-core）由 herdrdev 開發，以 **Apache-2.0** 授權。授權全文與第三方授權聲明在各目錄的 `LICENSE`、`THIRD-PARTY-NOTICES`。原始碼：<https://github.com/herdrdev/herdr-app>
