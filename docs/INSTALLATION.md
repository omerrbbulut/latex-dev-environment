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
