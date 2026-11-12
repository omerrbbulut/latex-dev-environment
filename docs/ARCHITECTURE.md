# Mimari

## Dizin yapısı

```text
latex-dev-environment/
├── README.md, LICENSE, .gitignore
├── scripts/
│   ├── install-ubuntu.sh      # giriş noktası: sistem → paketler → VS Code → yapılandırma → doctor
│   ├── install-vscode.sh      # VS Code (isteğe bağlı, resmi Microsoft deposu) + eksik eklentiler
│   ├── configure-vscode.sh    # kullanıcı dizinine yapılandırmayı uygular (idempotent, yedekli)
│   ├── doctor.sh              # PASS/WARN/FAIL doğrulama raporu
│   ├── uninstall.sh           # yalnızca eklediklerimizi kaldırır
│   ├── new-project.sh         # şablondan yeni proje
│   └── lib/
│       ├── common.sh          # yollar (XDG), çıktı, yedekleme, kurulum yardımcıları
│       └── vscode_merge.py    # JSONC ayrıştırıcı + yönetilen blok birleştirme/kontrol/kaldırma
├── vscode/
│   ├── settings.json          # LaTeX ayar parçası (JSONC, yorumlu)
│   ├── keybindings.json       # kısayol parçası
│   ├── extensions.txt         # gerekli eklentiler
│   └── latex.code-snippets    # snippet'ler (tek doğru kaynak)
├── config/
│   ├── latexindent.yaml
│   ├── chktexrc
│   └── latexmk/include-subdirs.pl
├── templates/
│   ├── article/               # main.tex, references.bib, .latexmkrc, figures/
│   ├── thesis/                # main.tex + frontmatter/ chapters/ appendices/
│   ├── technical-report/      # main.tex + sections/
│   └── project.gitignore      # new-project.sh tarafından kopyalanır
├── tests/
│   ├── run-tests.sh           # depo test paketi
│   ├── container-test.sh      # temiz Ubuntu konteynerinde sıfırdan kurulum testi
│   ├── smoke-test.tex         # motordan bağımsız test belgesi (pdf/xe/lua)
│   ├── references.bib
│   ├── snippet_check.py       # snippet dilbilgisi + genişletip derleme
│   └── test_vscode_merge.py   # birleştirme aracı birim testleri
└── docs/
```

## Tasarım ilkeleri

1. **Birleştir, üzerine yazma.** Kullanıcı dosyalarına yalnızca işaretli bir
   blok eklenir. Blok dışı **bayt bayt** korunur (yalnızca son satıra bir
   virgül eklenebilir). Kullanıcı anahtarı her zaman kazanır.
2. **Önce doğrula, sonra yaz.** `vscode_merge.py` sonucu ayrıştırır, mevcut
   tüm anahtarların değerinin aynı kaldığını ve yinelenen anahtar
   olmadığını kontrol eder. Ardından geçici dosya + `rename` ile atomik
   yazar.
3. **İdempotans.** İçeriği değişmeyen dosyaya yazılmaz ve yedek alınmaz.
   İkinci çalıştırma hiçbir dosyayı değiştirmez (`run-tests.sh` bunu
   kontrol eder).
4. **Yedek.** Değişen her dosya `~/.local/state/latex-dev-environment/backups/<zaman>/`
   altına, `$HOME` göreli yolu korunarak kopyalanır.
5. **Ayrıcalık en aza.** `sudo` yalnızca eksik apt paketi veya VS Code
   deposu için ve onayla kullanılır. Diğer her şey `$HOME` içindedir. Sistem
   kısayollarına, global git yapılandırmasına ve diğer dil ortamlarına
   dokunulmaz.
6. **Test edilebilirlik.** Tüm hedef yollar `HOME`/`XDG_*` değişkenlerinden
   türetilir. `run-tests.sh` gerçek ayar dosyanızın bir **kopyasıyla** geçici
   bir HOME içinde kurulum → tekrar kurulum → kaldırma döngüsünü test eder.
7. **Tek doğruluk kaynağı.** `doctor.sh`, derleme testinde komut
   satırını `vscode/settings.json` içindeki araç tanımından üretir
   (`vscode_merge.py tool-args`). Böylece test edilen komut, VS Code'un
   çalıştırdığı komutun aynısıdır.

## Derleme hattı

```text
Ctrl+S / Ctrl+Alt+B
   └─ LaTeX Workshop: kök dosyayı bul (% !TEX root / \documentclass)
       └─ tarif: % !LW recipe = …  ya da  ilk tarif (XeLaTeX)
           └─ latexmk -xelatex -synctex=1 -interaction=nonstopmode -file-line-error
                      -outdir=<kök>/build -auxdir=<kök>/build
                      -r ~/.config/latex-dev-environment/latexmk/include-subdirs.pl  <kök>/main
               ├─ include-subdirs.pl: build/<alt dizin> oluştur
               ├─ xelatex (→ .xdv) ⇄ biber (.bcf değiştiyse) ⇄ xelatex …
               └─ xdvipdfmx → build/main.pdf + build/main.synctex.gz
   └─ PDF sekmesi yenilenir · log ayrıştırılır → Problems
   └─ ChkTeX (-l chktexrc) → Problems · texcount → durum çubuğu
```

## Doğrulama katmanları

| Katman | Araç | Ne kanıtlar |
|---|---|---|
| Statik | `run-tests.sh` §1–2 | betik sözdizimi, ShellCheck (kuruluysa), JSON/JSONC |
| Snippet | `snippet_check.py` | dilbilgisi + tüm genişlemeler pdfLaTeX/XeLaTeX ile derlenir |
| Birleştirme | `test_vscode_merge.py` | yorum koruma, idempotans, kullanıcı önceliği, geri dönüş |
| Kurulum | `run-tests.sh` §5 | sanal HOME'da kur/kur/kaldır; ayarlar bayt bayt geri döner |
| Şablonlar | `run-tests.sh` §6 | XeLaTeX + LuaLaTeX, 0 uyarı, SyncTeX, ChkTeX temiz, latexindent kararlı |
| Ortam | `doctor.sh` | gerçek sistemde araçlar, eklenti, komut kimlikleri, ayar anahtarları, derleme, biber, SyncTeX ileri/ters |
| Temiz sistem | `container-test.sh` | apt dahil sıfırdan kurulum, tekrar kurulum, doctor, test paketi |
| Arayüz | elle | kısayolların basınca çalışması, PDF sekmesi, Ctrl+Click, snippet listesi |

## Bilinçli olarak yapılmayanlar

- `texlive-full` kurulmaz (boyut). Gerekli alt küme yeterlidir.
- LTeX/LanguageTool kurulmaz (Java, ağır). Yazım denetimi hafif ve yereldir.
- Kayıtta biçimlendirme LaTeX için kapalıdır (kullanıcı tercihi: önce elle).
- Derleme yardımcı dosyaları otomatik silinmez.
- Mevcut projelerin `.vscode/settings.json` dosyalarına dokunulmaz. Yalnızca
  `doctor.sh --project` ile raporlanır.
