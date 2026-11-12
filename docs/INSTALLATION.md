# Kurulum

## Temiz bir Ubuntu sisteminde

```bash
sudo apt-get update && sudo apt-get install -y git gh
gh auth login                                   # depo özel olduğu için gerekli
gh repo clone omerrbbulut/latex-dev-environment ~/Projects/latex-dev-environment
cd ~/Projects/latex-dev-environment
./scripts/install-ubuntu.sh --install-vscode    # VS Code yoksa resmi depodan kurar
```

VS Code zaten kuruluysa `--install-vscode` gerekmez.

## `install-ubuntu.sh` ne yapar?

| Adım | Ayrıntı |
|---|---|
| 1. Sistem algılama | `/etc/os-release` (Ubuntu 26.04 test edildi, 24.04/25.10 beklenir), `dpkg --print-architecture` (amd64/arm64) |
| 2. Paketler | Aşağıdaki listeden yalnızca **kurulu olmayanları** `sudo apt-get install --no-install-recommends` ile kurar. Kurmadan önce onay ister (`--yes` hariç). |
| 3. VS Code | `code` yoksa uyarır. `--install-vscode` verilmişse Microsoft'un imza anahtarını indirir, parmak izini (`BC528686B50D79E339D3721CEB3E94ADBE1229CF`) **doğrular**, `/etc/apt/sources.list.d/vscode.sources` ekler ve `code` paketini kurar. |
| 4. Eklentiler | `vscode/extensions.txt` içindekilerden eksik olanları kurar. Diğer eklentilere dokunmaz. |
| 5. Yapılandırma | `configure-vscode.sh` (aşağıda) |
| 6. Doğrulama | `doctor.sh` |

### Kurulan Ubuntu paketleri

| Paket | Neden |
|---|---|
| `texlive-base`, `texlive-latex-base`, `texlive-latex-recommended`, `texlive-latex-extra` | TeX Live çekirdeği, pdflatex, yaygın paketler (cleveref, acronym, algorithm, mwe…) |
| `texlive-xetex`, `texlive-luatex` | xelatex / lualatex, fontspec, polyglossia |
| `texlive-bibtex-extra`, `biber` | biblatex + biber |
| `texlive-lang-european` | Türkçe heceleme ve dil desteği |
| `texlive-pictures`, `texlive-science` | TikZ, siunitx, algorithmicx |
| `texlive-fonts-recommended`, `fonts-lmodern`, `fonts-texgyre`, `fonts-dejavu-core` | Latin Modern Math, TeX Gyre Heros (Aptos yedeği), DejaVu Sans Mono |
| `texlive-extra-utils` | latexindent, texcount |
| `latexmk`, `chktex` | derleme sürücüsü, lint |
| `fontconfig`, `poppler-utils`, `python3` | font keşfi, `pdfinfo`, JSONC birleştirme |

`texlive-full` (~6 GB) **kurulmaz**. Eksik bir paket gerekirse:
`kpsewhich paket.sty` boş dönüyorsa `apt-file search paket.sty` ile hangi
Ubuntu paketinde olduğunu bulun.

## Seçenekler

```text
-y, --yes          onay sorma
-n, --dry-run      yalnızca ne yapılacağını göster
--skip-packages    apt adımını atla
--skip-vscode      VS Code / eklenti / yapılandırma adımlarını atla
--install-vscode   VS Code yoksa Microsoft deposundan kur
--no-doctor        sondaki doğrulamayı atla
```

## Yalnızca yapılandırma

Paketler ve eklentiler hazırsa:

```bash
./scripts/configure-vscode.sh --dry-run
./scripts/configure-vscode.sh
```

Değiştirilen her dosya önce
`~/.local/state/latex-dev-environment/backups/<YYYYmmdd-HHMMSS>/` altına,
`$HOME` içindeki yolu korunarak kopyalanır. Değişmeyen dosyalar için yedek
alınmaz ve dosyaya yazılmaz.

## Aptos fontu

Aptos, Microsoft'un lisanslı fontudur ve depoya **eklenmez**. Elinizde yasal
bir kopya varsa:

```bash
mkdir -p ~/.local/share/fonts/Microsoft/Aptos
cp /yol/Aptos*.ttf ~/.local/share/fonts/Microsoft/Aptos/
fc-cache -f
fc-list | grep -i aptos
```

Şablonlar `\IfFontExistsTF{Aptos}` ile kontrol eder. Font yoksa *TeX Gyre
Heros* ile derlemeye devam eder (test edildi).

## İsteğe bağlı: ShellCheck

`tests/run-tests.sh`, kuruluysa betikleri ShellCheck ile de denetler:

```bash
sudo apt install shellcheck
```

## Temiz sistemde test

Ortam zaten kurulu bir makinede kurulumun "sıfırdan" çalıştığını görmek için
iki yöntem vardır. İkisi de gerçek ayarlarınıza dokunmaz.

### 1. Konteyner: paket kurulumu dahil (GUI yok)

```bash
sudo apt install docker.io && sudo usermod -aG docker $USER   # bir kez; sonra oturumu kapatıp açın
./tests/container-test.sh                       # ubuntu:26.04
./tests/container-test.sh --image ubuntu:24.04  # başka sürüm
./tests/container-test.sh --mode both           # normal kullanıcı + root
./tests/container-test.sh --shell               # sonunda konteynere kabuk aç
```

Kipler (`--mode`):

| Kip | Ne test eder |
|---|---|
| `user` (varsayılan) | Gerçek masaüstü gibi: sudo yetkili normal kullanıcı kurar, apt `sudo` ile çalışır. Ek kontroller: ev dizininde root'a ait dosya yok, yapılandırma dosyaları kullanıcıya ait, `sudo ./scripts/install-ubuntu.sh` reddediliyor ve `/root` altında hiçbir şey oluşmuyor. |
| `root` | Her şey root olarak (konteyner/CI senaryosu, `sudo` hiç kullanılmaz) |
| `both` | İkisi, her biri ayrı temiz konteynerde |

Testteki kullanıcının sudo'su parola sormaz (parolayı yazacak kimse yoktur).
Gerçek kurulumda `sudo` parolanızı bir kez ister.

Podman da desteklenir (`sudo apt install podman`, root gerekmez). Betik temiz
bir Ubuntu konteynerinde sırasıyla şunları çalıştırır:
`install-ubuntu.sh --yes --skip-vscode` (tüm apt paketleri), aynı komutu
tekrar (kurulacak bir şey kalmamalı), `configure-vscode.sh` iki kez (ikincisi
değişiklik yapmamalı), `doctor.sh --no-vscode` (0 FAIL) ve `tests/run-tests.sh`.
Depo konteynere salt okunur bağlanır ve kopyalanır. Ana sistem değişmez.
Betikleri `sudo` ile çalıştırmayın (`sudo ./scripts/install-ubuntu.sh` reddedilir; aksi hâlde root'un VS Code'u yapılandırılırdı). Betik `sudo`'yu yalnızca apt için kendisi ister. Gerçek root (konteyner) olarak çalışırken `sudo` kullanılmaz.

### 2. Boş HOME: VS Code arayüzü dahil (paketler hariç)

```bash
mkdir ~/lde-fresh-home
env -u XDG_CONFIG_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u XDG_DATA_HOME \
    HOME=~/lde-fresh-home ./scripts/install-ubuntu.sh --skip-packages
HOME=~/lde-fresh-home ./scripts/new-project.sh thesis ~/lde-fresh-home/tez-test
env -u XDG_CONFIG_HOME -u XDG_DATA_HOME HOME=~/lde-fresh-home code ~/lde-fresh-home/tez-test
```

Ayrı, hiç yapılandırılmamış bir VS Code penceresi açılır (varsayılan tema,
eklentiler Marketplace'ten yeni indirilmiş, Aptos görünmez). Kısayolları,
PDF sekmesini, SyncTeX'i ve snippet'leri burada elle deneyin
([SHORTCUTS.md](SHORTCUTS.md#doğrulama-durumu)). Bitince pencereyi kapatıp
`rm -rf ~/lde-fresh-home`.

Tam gerçekçi test (paketler + arayüz) için GNOME Boxes ile bir Ubuntu 26.04
sanal makinesi kullanın (`sudo apt install gnome-boxes`).
