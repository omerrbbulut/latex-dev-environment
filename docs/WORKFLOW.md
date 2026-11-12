# Günlük iş akışı

## Yeni proje

```bash
cd ~/Projects/latex-dev-environment
./scripts/new-project.sh article ~/Documents/latex-projects/makale-2026 --git --open
```

- Şablon kopyalanır (`build/` hariç), `.gitignore` eklenir. `--git` yerel
  bir depo başlatır (uzak depo eklenmez).
- Hedef dizin doluysa hiçbir şey yapılmaz.
- `main.tex` dosyasının başındaki `% !LW recipe = XeLaTeX (latexmk)` satırı
  hangi tarifin kullanılacağını belirtir.

Elle kopyalamak isterseniz:
`cp -r templates/thesis ~/Documents/latex-projects/tezim && rm -rf ~/Documents/latex-projects/tezim/build`

## Yazma döngüsü

1. `main.tex` (veya bir bölüm dosyası) açın. `Ctrl+Alt+V` ile PDF sağ
   tarafta açılır.
2. Yazın; `Ctrl+S` → otomatik derleme. Durum çubuğunda ilerleme görünür.
3. Hatalar/uyarılar: `Ctrl+Shift+M` (Problems). Ham log için `Ctrl+Alt+L`.
4. İmleçteki yeri PDF'te görmek için `Ctrl+Alt+J`. PDF'ten kaynağa dönmek
   için `Ctrl+Click`.
5. Yapıyı gezmek için *Outline* görünümü veya LaTeX Workshop *Structure*
   paneli (`Ctrl+Alt+X`).
6. Biçimlendirmek için `Ctrl+Alt+F`. Kelime sayısı için `Ctrl+Alt+W` (durum
   çubuğunda her kayıtta da güncellenir).

## Çok dosyalı projeler

- Kök: `main.tex`. Alt dosyaların ilk satırına `% !TEX root = ../main.tex`
  yazın. Böylece bir bölüm dosyasında `Ctrl+S` yapınca kök derlenir.
- `\include{chapters/01-giris}` bölüm başına sayfa açar ve `\includeonly{…}`
  ile hızlı kısmi derlemeyi sağlar. `\input{…}` sayfa açmaz.
- Çıktı her zaman kökün yanındaki `build/` dizinindedir. Alt dizinler
  (`build/chapters/`) otomatik oluşturulur.

## Motor seçimi

| Durum | Ne yapmalı |
|---|---|
| Yeni proje, sistem fontları (Aptos) | Varsayılan XeLaTeX, bir şey yapmanız gerekmez |
| Eski proje, `inputenc`/`fontenc`, pdfLaTeX'e özgü paketler | Kök dosyanın en üstüne `% !LW recipe = PDFLaTeX (latexmk)` |
| `luacode`, LuaLaTeX'e özgü paketler | `% !LW recipe = LuaLaTeX (latexmk)` |
| Projenin kendi `.latexmkrc` dosyası var | `% !LW recipe = latexmk (.latexmkrc decides engine)` |
| Geçici olarak farklı motor | `Ctrl+Alt+M` ile seçin (o oturum için) |

Sihirli yorum, dosyanın **ilk yorum bloğunda** olmalıdır (ilk boş olmayan,
yorum olmayan satırdan önce). Ad, tarif adıyla birebir aynı olmalıdır.

## Kaynakça

```latex
\usepackage{csquotes}
\usepackage[backend=biber,style=numeric-comp]{biblatex}  % ya da authoryear, ieee, apa…
\addbibresource{references.bib}
...
\textcite{knuth1984texbook} gösterdi ki … \parencite{lamport1994latex}.
...
\printbibliography[heading=bibintoc]
```

- `references.bib` kaydedildiğinde de derleme tetiklenir. latexmk `.bcf`
  değiştiyse biber'i çalıştırır, ardından gerektiği kadar LaTeX geçişi yapar.
- Atıf tamamlama `\cite{` yazınca açılır. Anahtar, yazar veya başlıkla arama
  yapılabilir.
- `.bib` dosyasını düzenlemek için *LaTeX Workshop: Align/Sort bibliography*
  komutları (Command Palette).
- Türkçe metinde polyglossia + biblatex `turkish.lbx` ile "ve", "vd." gibi
  ifadeler Türkçe yazılır.

## Komut satırı

```bash
cd ~/Documents/latex-projects/tezim
latexmk                 # şablonun .latexmkrc'si: XeLaTeX, build/, SyncTeX
latexmk -pvc            # sürekli izleme modu
latexmk -c              # ara dosyaları sil (PDF kalır)
latexmk -C              # PDF dahil sil
```

## Git ile LaTeX

- `build/` ve ara dosyalar `.gitignore` ile dışlanır.
- Cümle başına bir satır yazmak diff'leri okunur kılar. latexindent satırları
  **değiştirmez**, bunu siz uygularsınız.
- Biçimlendirmeyi ayrı bir commit olarak yapın (`Ctrl+Alt+F` sonrası
  `git commit -m "format"`).
