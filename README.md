# latex-dev-environment

Ubuntu üzerinde **VS Code + LaTeX Workshop + TeX Live** ile tekrarlanabilir,
test edilmiş bir LaTeX geliştirme ortamı. Tek komutla kurulur. Mevcut VS
Code ayarlarınıza (tema, font, C/C++, Python, Qt, gömülü sistem
yapılandırmaları) dokunmaz. Her değişiklikten önce yedek alır.

```bash
git clone https://github.com/omerrbbulut/latex-dev-environment.git ~/Projects/latex-dev-environment
cd ~/Projects/latex-dev-environment
./scripts/install-ubuntu.sh        # eksik paketler + eklentiler + yapılandırma + doğrulama
./scripts/doctor.sh                # istediğiniz zaman: PASS / WARN / FAIL raporu
```

---

## İçindekiler

1. [Projenin amacı](#1-projenin-amacı)
2. [Desteklenen Ubuntu sürümleri](#2-desteklenen-ubuntu-sürümleri)
3. [Ön koşullar](#3-ön-koşullar)
4. [Kurulum](#4-kurulum)
5. [VS Code yapılandırması](#5-vs-code-yapılandırması)
6. [Derleme tarifleri (recipes)](#6-derleme-tarifleri-recipes)
7. [Klavye kısayolları](#7-klavye-kısayolları)
8. [Snippet referansı](#8-snippet-referansı)
9. [Proje şablonları](#9-proje-şablonları)
10. [Kaynakça iş akışı](#10-kaynakça-iş-akışı)
11. [Biçimlendirme (latexindent)](#11-biçimlendirme-latexindent)
12. [Lint (ChkTeX)](#12-lint-chktex)
13. [Sorun giderme](#13-sorun-giderme)
14. [Güncelleme](#14-güncelleme)
15. [Kaldırma](#15-kaldırma)
16. [GitHub kullanımı](#16-github-kullanımı)

Ayrıntılı belgeler: [`docs/`](docs/) —
[Kurulum](docs/INSTALLATION.md) ·
[Yapılandırma](docs/CONFIGURATION.md) ·
[Kısayollar](docs/SHORTCUTS.md) ·
[Snippet'ler](docs/SNIPPETS.md) ·
[İş akışı](docs/WORKFLOW.md) ·
[Sorun giderme](docs/TROUBLESHOOTING.md) ·
[Mimari](docs/ARCHITECTURE.md)

---

## 1. Projenin amacı

- **Tek kaynak:** VS Code ayarları, kısayollar, snippet'ler, latexindent ve
  ChkTeX yapılandırması bu depoda tutulur. Kurulum betiği bunları kullanıcı
  dizinine **birleştirir** (üzerine yazmaz).
- **Tekrarlanabilirlik:** Temiz bir Ubuntu kurulumunda aynı ortam tek komutla
  yeniden oluşturulur. Betikler idempotenttir; tekrar çalıştırmak hiçbir şeyi
  değiştirmez.
- **Doğrulanabilirlik:** `doctor.sh` araçları, yapılandırmayı, derlemeyi,
  SyncTeX'i, kaynakçayı ve üç şablonu otomatik olarak test eder.
  `tests/run-tests.sh` depo düzeyindeki testleri çalıştırır.

Özellikler: XeLaTeX (varsayılan) / pdfLaTeX / LuaLaTeX derleme (latexmk),
kayıtta otomatik derleme, dahili PDF önizleme, iki yönlü SyncTeX, ChkTeX
tanılama, latexindent biçimlendirme, IntelliSense (paket, ortam, atıf,
çapraz referans, matematik sembolü), hover önizleme, belge ana hattı, 24
snippet, İngilizce + Türkçe yazım denetimi, kelime sayımı ve üç şablon
(makale, tez, teknik rapor).

## 2. Desteklenen Ubuntu sürümleri

| Sürüm | Durum |
|---|---|
| **Ubuntu 26.04 LTS** (amd64) | Test edildi (TeX Live 2025, latexmk 4.87, LaTeX Workshop 10.20.0, VS Code 1.146) |
| Ubuntu 25.10 / 24.04 LTS | Desteklenmesi beklenir (aynı paket adları); otomatik test edilmedi |
| Ubuntu tabanlı dağıtımlar | Uyarı verilerek devam edilir |
| arm64 | Paketler mevcut; test edilmedi |

## 3. Ön koşullar

- `sudo` yetkisi (yalnızca eksik paket varsa istenir)
- İnternet bağlantısı (apt ve VS Code Marketplace)
- VS Code (Microsoft'un resmi APT paketi). Kurulu değilse
  `./scripts/install-ubuntu.sh --install-vscode` Microsoft'un resmi deposunu
  imza parmak izini doğrulayarak ekler.
- İsteğe bağlı: **Aptos** fontu (Microsoft'a ait, depoya **eklenmez**).
  Kurulu değilse şablonlar otomatik olarak *TeX Gyre Heros* kullanır.

## 4. Kurulum

```bash
cd ~/Projects/latex-dev-environment
./scripts/install-ubuntu.sh --dry-run   # önce ne yapılacağını görün
./scripts/install-ubuntu.sh             # uygulayın
```

Betik sırasıyla: Ubuntu sürümünü ve mimariyi algılar → yalnızca **eksik**
paketleri kurar (`--no-install-recommends`, texlive-full **değil**) → VS Code
ve eksik eklentileri kontrol eder → yapılandırmayı birleştirir → `doctor.sh`
çalıştırır. Seçenekler: `--yes`, `--skip-packages`, `--skip-vscode`,
`--install-vscode`, `--no-doctor`. Ayrıntılar: [docs/INSTALLATION.md](docs/INSTALLATION.md).

Yedekler: `~/.local/state/latex-dev-environment/backups/<zaman damgası>/`

## 5. VS Code yapılandırması

| Dosya | Ne yapılır |
|---|---|
| `~/.config/Code/User/settings.json` | Sonuna işaretli bir **yönetilen blok** eklenir (JSONC uyumlu, yorumlar korunur). Sizin zaten tanımladığınız bir anahtar **sizde kalır** ve raporlanır. |
| `~/.config/Code/User/keybindings.json` | Aynı şekilde yönetilen blok |
| `~/.config/Code/User/snippets/latex.code-snippets` | Depodaki kopya kurulur (eskisi yedeklenir) |
| `~/.config/latexindent/` | `latexindent.yaml` + `indentconfig.yaml` |
| `~/.config/chktex/chktexrc` | ChkTeX yerel ayarları |
| `~/.config/latex-dev-environment/latexmk/include-subdirs.pl` | `\include{chapters/...}` için derleme alt dizinleri |

Gerekli eklentiler (`vscode/extensions.txt`): **LaTeX Workshop**, **Code Spell
Checker** ve onun resmi **Türkçe sözlüğü**. Tema (Catppuccin Mocha), ikonlar
(Material Icon Theme) ve font (JetBrains Mono Nerd Font) korunur. LaTeX
Workshop'un yerleşik yetenekleriyle çakışan ek eklenti kurulmaz.

Yalnızca LaTeX/BibTeX dosyaları için: 2 boşluk girinti, satır kaydırma açık,
**kayıtta biçimlendirme kapalı** (genel `editor.formatOnSave: true` ayarınız
diğer diller için aynen kalır). Tüm anahtarların açıklaması:
[docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## 6. Derleme tarifleri (recipes)

| # | Tarif | Komut |
|---|---|---|
| 1 | **XeLaTeX (latexmk)** — varsayılan | `latexmk -xelatex -synctex=1 -interaction=nonstopmode -file-line-error -outdir=build ...` |
| 2 | PDFLaTeX (latexmk) | `latexmk -pdf ...` |
| 3 | LuaLaTeX (latexmk) | `latexmk -lualatex ...` |
| 4 | latexmk (.latexmkrc decides engine) | motoru projenin `.latexmkrc` dosyası seçer |

- Çıktı **kök dosyanın yanındaki `build/`** dizinine gider (`%DIR%/build`).
  Çok dosyalı projelerde alt dosyalar kökü `% !TEX root = ../main.tex` ile
  bulur.
- Kaynakça gerekiyorsa biber'i latexmk otomatik çalıştırır.
- Kayıtta (Ctrl+S) otomatik derleme açıktır. Derleme ara dosyaları
  **asla otomatik silinmez** (log ve SyncTeX tanılama için gerekir).
- **Mevcut projelerde XeLaTeX zorlanmaz.** Kök `.tex` dosyasının en üstündeki
  yorum bloğuna şunu yazın:
  ```latex
  % !LW recipe = PDFLaTeX (latexmk)
  ```
  Ya da tarifi Ctrl+Alt+M ile seçin. Projede `.latexmkrc` varsa 4. tarifi
  kullanın.

## 7. Klavye kısayolları

Tümü yalnızca LaTeX bağlamında (LaTeX editörü, gerektiğinde `.bib` dosyası ve
LaTeX Workshop PDF sekmesi) etkindir. Tam liste, çakışma analizi ve
özelleştirme: [docs/SHORTCUTS.md](docs/SHORTCUTS.md).

| Kısayol | İşlem | VS Code komutu |
|---|---|---|
| `Ctrl+Alt+B` | Projeyi derle | `latex-workshop.build` |
| `Ctrl+Alt+V` | PDF önizlemeyi aç | `latex-workshop.view` |
| `Ctrl+Alt+J` | İleri SyncTeX (kaynak → PDF) | `latex-workshop.synctex` |
| `Ctrl+Click` (PDF'de) | Ters SyncTeX (PDF → kaynak) | `view.pdf.internal.synctex.keybinding` |
| `Ctrl+Alt+R` | PDF görüntüleyiciyi yenile | `latex-workshop.refresh-viewer` |
| `Ctrl+Alt+C` | Yardımcı dosyaları temizle | `latex-workshop.clean` |
| `Ctrl+Alt+K` | Derlemeyi durdur | `latex-workshop.kill` |
| `Ctrl+Alt+M` | Derleme tarifi seç | `latex-workshop.recipes` |
| `Ctrl+Alt+P` | Matematik önizleme paneli *(LW varsayılanı Ctrl+Alt+M'den taşındı)* | `latex-workshop.toggleMathPreviewPanel` |
| `Ctrl+Alt+F` | Belgeyi biçimlendir (latexindent) | `editor.action.formatDocument` |
| `Ctrl+Alt+L` | Derleyici günlüğü (LaTeX log) | `latex-workshop.compilerlog` |
| `Ctrl+Alt+W` | Kelime sayısı | `latex-workshop.wordcount` |
| `Ctrl+Space` | IntelliSense | `editor.action.triggerSuggest` *(VS Code varsayılanı)* |
| `Ctrl+Shift+M` | Sorunlar paneli | `workbench.actions.view.problems` *(varsayılan)* |
| `Ctrl+S` | Kaydet + otomatik derleme | `workbench.action.files.save` + `autoBuild.run: onSave` |

## 8. Snippet referansı

Önek yazıp `Tab` (veya öneri listesinden `Enter`) ile genişletin. `Tab` ile
alanlar arasında ilerleyin. Ayrıntılar ve gereken paketler:
[docs/SNIPPETS.md](docs/SNIPPETS.md).

| Önek | Sonuç | Önek | Sonuç |
|---|---|---|---|
| `eq` | numaralı `equation` + `\label{eq:}` | `cite` | `\cite` / `\parencite` / `\textcite` … seçimi |
| `eqs` | `equation*` | `ref` | `\ref` / `\eqref` / `\cref` … seçimi |
| `align` | `align` (ilk satır etiketli) | `item` | `itemize` |
| `aligns` | `align*` | `enum` | `enumerate` |
| `fig` | `figure` + `\includegraphics` | `desc` | `description` |
| `subfig` | iki `subfigure` | `algo` | `algorithm` + `algorithmic` |
| `tbl` | booktabs `table` | `lst` | `lstlisting` (dil seçimi) |
| `chap` | `\chapter` + etiket | `thm` / `lem` | `theorem` / `lemma` |
| `sec` | `\section` + etiket | `proof` | `proof` |
| `ssec` | `\subsection` + etiket | `mat` | `pmatrix` / `bmatrix` … |
| `sssec` | `\subsubsection` + etiket | `cases` | `cases` |
| | | `beg` | genel `\begin{…}…\end{…}` |

Snippet'ler hiçbir paketi otomatik yüklemez. Gereken paket her snippet'in
açıklamasında yazar. Tümü otomatik testte genişletilip pdfLaTeX ve XeLaTeX
ile derlenir.

## 9. Proje şablonları

| Şablon | İçerik |
|---|---|
| `article` | A4, özet, giriş/yöntem/bulgular/sonuç, şekil, tablo (siunitx), matematik, teorem, biblatex/biber, cleveref |
| `thesis` | Çok dosyalı (`frontmatter/`, `chapters/`, `appendices/`), Özet + Abstract, içindekiler, şekil/tablo listeleri, kısaltmalar (`acronym`), ekler, Türkçe cleveref adları |
| `technical-report` | Kapak (doküman no/sürüm/durum), revizyon geçmişi, gereksinimler (longtable), TikZ mimari diyagramı, tasarım, kod listesi, test izlenebilirliği, sonuçlar, ekler |

Tümü XeLaTeX ile (LuaLaTeX ile de) **0 uyarıyla** derlenir, ChkTeX
temizdir ve latexindent ile biçimlendirilmiştir. Türkçe ve İngilizce metni
doğru heceleme kurallarıyla destekler.

> Tez şablonu geneldir; **herhangi bir üniversitenin tez yazım kılavuzuna
> uygunluğu iddia edilmez.** Kenar boşlukları, satır aralığı ve kapak
> sayfasını kendi enstitünüzün kurallarına göre uyarlayın.

Yeni proje oluşturma:

```bash
./scripts/new-project.sh article ~/Documents/latex-projects/makalem --open
./scripts/new-project.sh thesis  ~/Documents/latex-projects/tezim --git
./scripts/new-project.sh technical-report ~/Documents/latex-projects/rapor
```

Hedef dizin boş değilse betik hiçbir şeyi değiştirmez. Komut satırından
derleme için şablonun içinde `latexmk` çalıştırmanız yeterli (`.latexmkrc`
dahil).

## 10. Kaynakça iş akışı

1. Kaynakları `references.bib` dosyasına ekleyin (Zotero/Better BibTeX dışa
   aktarımı da olur).
2. Önsözde: `\usepackage[backend=biber,style=...]{biblatex}` +
   `\addbibresource{references.bib}`.
3. Metinde `cite` snippet'i veya `\cite{` yazınca açılan **atıf tamamlama**
   (anahtar, yazar, başlık ile arama; üzerine gelince hover önizleme).
4. `\printbibliography`. Kaydedince latexmk biber'i gerektiğinde kendisi
   çalıştırır.

Ayrıntı: [docs/WORKFLOW.md](docs/WORKFLOW.md#kaynakça).

## 11. Biçimlendirme (latexindent)

- **Ctrl+Alt+F** veya *Format Document* komutu. Kayıtta biçimlendirme LaTeX
  için **kapalıdır** (bilinçli tercih). Açmak için kullanıcı ayarlarına
  `"[latex]": { "editor.formatOnSave": true }` ekleyin.
- Yalnızca girinti ve hizalama değişir. Satır kaydırma, cümle bölme, boş satır
  ekleme/silme yoktur. Verbatim/lstlisting/minted içeriğine dokunulmaz.
  `equation`, `gather` ve `multline` yeniden hizalanmaz.
- Girinti genişliği `editor.tabSize` değerinden gelir (LaTeX için 2).
- Biçimlendirme geçici bir kopya üzerinde yapılır ve sonucu geri alınabilir
  (Ctrl+Z) bir düzenleme olarak uygulanır. `indent.log` proje dizinine değil
  `~/.cache/latexindent/` dizinine yazılır.
- Komut satırı: `latexindent dosya.tex` (aynı ayarlar). Yerinde yazmak için
  `-w`, ama önce git commit yapmanız önerilir.

## 12. Lint (ChkTeX)

- Her kayıtta çalışır. Uyarılar *Problems* paneline (Ctrl+Shift+M) ve satır
  içine düşer.
- `-wall` ile tüm uyarılar açıktır. Yalnızca gerekçeli olarak kapatılanlar:
  **21** (`\left\| x \right\|` normlarında yanlış alarm), **24**
  (`\section{}` sonrası ayrı satırdaki `\label{}`), **46** (`$…$` yerine
  `\(…\)` stil tercihi), ayrıca LW varsayılanı olarak **22** ve **30**.
  Gerekçeler: [`config/chktexrc`](config/chktexrc).
- Komut satırı: `chktex -wall -n22 -n30 -e16 -q -l ~/.config/chktex/chktexrc main.tex`
- Projeye özel kural: argümanlarda zaten `-l` olduğu için LaTeX Workshop
  projedeki `.chktexrc` dosyasını **kendiliğinden eklemez**. Proje
  dizinindeki `.vscode/settings.json` içinde ikinci bir `-l` verin (ChkTeX
  ikisini de okur). Örnek: [docs/CONFIGURATION.md](docs/CONFIGURATION.md#chktex).

## 13. Sorun giderme

```bash
./scripts/doctor.sh                       # tam kontrol (derleme testleri dahil)
./scripts/doctor.sh --quick               # yalnızca araçlar ve yapılandırma
./scripts/doctor.sh --project ~/Documents/latex-projects/test   # proje ayarı çakışmaları
```

Kurulumun temiz bir sistemde çalıştığını test etmek için:
`./tests/container-test.sh` (Docker/Podman, paketler dahil) veya boş bir HOME
ile ayrı bir VS Code penceresi
([docs/INSTALLATION.md](docs/INSTALLATION.md#temiz-sistemde-test)).

Sık karşılaşılanlar (Aptos bulunamadı, `I can't write on file
chapters/x.aux`, workspace ayarlarının global tarifleri gizlemesi, kısayolun
çalışmaması, Türkçe yazım uyarıları…): [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 14. Güncelleme

```bash
cd ~/Projects/latex-dev-environment
git pull
./scripts/configure-vscode.sh     # değişen dosyaları yedekleyip günceller
./scripts/doctor.sh
```

Yapılandırmayı **depoda** değiştirin (`vscode/`, `config/`) ve
`configure-vscode.sh` çalıştırın. Yönetilen bloğu elle düzenlemeyin; bir
sonraki çalıştırmada depo içeriğiyle değiştirilir. Kendi tercihinizi bloğun
**dışına** yazarsanız o değer kazanır.

## 15. Kaldırma

```bash
./scripts/uninstall.sh
```

Yönetilen blokları ve kurulan yapılandırma dosyalarını kaldırır (yalnızca
depodaki kopyayla birebir aynıysa). Önce yedek alır. `settings.json`
kurulum öncesi hâline **bayt bayt** döner (testle doğrulanır). TeX Live
paketleri, VS Code ve eklentiler kaldırılmaz. Gerekirse kullanılacak komutlar
betik sonunda yazdırılır.

## 16. GitHub kullanımı

Depo **herkese açıktır (public)**: `omerrbbulut/latex-dev-environment`.
Sürümler: [Releases](https://github.com/omerrbbulut/latex-dev-environment/releases).

`main` dalı bir kural setiyle (*main: pull requests only*) korunur. Kimse için,
depo sahibi dahil, istisna yoktur:

| Kural | Etkisi |
|---|---|
| Pull request zorunlu | `main` dalına doğrudan push reddedilir (`GH013: Changes must be made through a pull request`) |
| Force push yasak | `main` geçmişi yeniden yazılamaz |
| Silme yasak | `main` dalı silinemez |

Gerekli onay sayısı 0'dır: GitHub kendi PR'ınızı onaylamanıza izin vermez. Tek
geliştirici olarak onay şartı sizi kilitlerdi.

```bash
git clone https://github.com/omerrbbulut/latex-dev-environment.git ~/Projects/latex-dev-environment
git switch -c ozellik/yeni-snippet                # her değişiklik için dal
./tests/run-tests.sh                              # commit öncesi testler
git commit -m "snippets: add minipage snippet"
git push -u origin ozellik/yeni-snippet
gh pr create --fill                               # PR aç
gh pr merge --squash --delete-branch              # birleştir, dalı sil
git switch main && git pull                       # yerel main'i güncelle
```

Commit'ler GitHub'ın no-reply adresiyle (`41139691+omerrbbulut@users.noreply.github.com`)
yazılır. Bu adres yalnızca bu depo için yerel olarak ayarlıdır
(`git config user.email`); kişisel e-posta adresi geçmişte görünmez.

Commit öncesi `tests/run-tests.sh` şunları kontrol eder: `bash -n` ve (kuruluysa)
ShellCheck, JSON/JSONC geçerliliği, snippet sözdizimi ve derlenmesi, birleştirme
aracı birim testleri, sanal HOME'da kurulum/kaldırma, şablon derlemeleri,
ChkTeX, latexindent, `git diff --check`, ikili dosya, font ve gizli anahtar taraması.

Depoya **asla** eklenmeyenler: fontlar (`*.ttf`, `*.otf` — Aptos lisanslıdır),
derleme çıktıları, PDF'ler, kimlik bilgileri.

---

Lisans: [MIT](LICENSE)
