# Yapılandırma

Kaynak dosyalar depodadır. `configure-vscode.sh` bunları kullanıcı
dizinine uygular.

| Depo | Kurulum hedefi | Yöntem |
|---|---|---|
| `vscode/settings.json` | `~/.config/Code/User/settings.json` | yönetilen blok (birleştirme) |
| `vscode/keybindings.json` | `~/.config/Code/User/keybindings.json` | yönetilen blok |
| `vscode/latex.code-snippets` | `~/.config/Code/User/snippets/latex.code-snippets` | kopya |
| `config/latexindent.yaml` | `~/.config/latexindent/latexindent.yaml` (+ `indentconfig.yaml`) | kopya |
| `config/chktexrc` | `~/.config/chktex/chktexrc` | kopya |
| `config/latexmk/include-subdirs.pl` | `~/.config/latex-dev-environment/latexmk/include-subdirs.pl` | kopya |

## Yönetilen blok nasıl çalışır?

```jsonc
{
    "workbench.colorTheme": "Catppuccin Mocha",   // sizin ayarlarınız: aynen kalır
    ...
    "idf.hasWalkthroughBeenShown": true,
    // >>> latex-dev-environment (managed block, do not edit by hand) >>>
    "latex-workshop.latex.recipes": [ ... ],
    ...
    // <<< latex-dev-environment <<<
}
```

- `scripts/lib/vscode_merge.py` JSONC'yi (yorumlar, sondaki virgüller,
  string içindeki `//`) doğru ayrıştırır. Dosyayı yeniden yazmaz. Yalnızca
  bloğu ekler veya yeniler; gerekirse önceki son satıra tek bir virgül ekler.
- Yazmadan önce sonucu doğrular: kullanıcı anahtarlarının **hiçbirinin**
  değeri değişmemeli, yinelenen anahtar oluşmamalıdır. Aksi hâlde dosyaya
  dokunmaz.
- Bloktaki bir anahtarı siz bloğun dışında zaten tanımladıysanız **sizin
  değeriniz kalır**. Betik `WARN` ile bildirir, `doctor.sh` de raporlar.
- `${HOME}` yer tutucusu kurulumda gerçek ev dizininizle değiştirilir.
  LaTeX Workshop `~` karakterini açmadığı için gereklidir.
- Kaldırma (`uninstall.sh`) bloğu ve eklenen virgülü siler. Dosya kurulum
  öncesi hâline bayt bayt döner.

## Ayar referansı

### Derleme

| Anahtar | Değer | Açıklama |
|---|---|---|
| `latex-workshop.latex.recipes` | XeLaTeX, PDFLaTeX, LuaLaTeX, .latexmkrc | ilk tarif varsayılandır |
| `latex-workshop.latex.tools` | `lde-*` araçları | latexmk + `-synctex=1 -interaction=nonstopmode -file-line-error -outdir -auxdir -r include-subdirs.pl` |
| `latex-workshop.latex.recipe.default` | `first` | XeLaTeX; `% !LW recipe = ...` sihirli yorumu önceliklidir |
| `latex-workshop.latex.outDir` | `%DIR%/build` | kök dosyanın yanındaki `build/` |
| `latex-workshop.latex.auxDir` | `%OUTDIR%` | yardımcı dosyalar da `build/` içinde |
| `latex-workshop.latex.autoBuild.run` | `onSave` | Ctrl+S derler |
| `latex-workshop.latex.autoClean.run` | `never` | log/SyncTeX asla otomatik silinmez |
| `latex-workshop.latex.clean.*` | `latexmk -c` | Ctrl+Alt+C: ara dosyaları siler, PDF kalır |

Araç adlarının `lde-` önekli olması, LaTeX Workshop'un yerleşik
`latexmk`/`xelatexmk` araçlarıyla ve projelerin kendi araç tanımlarıyla
karışmamaları içindir.

### PDF ve SyncTeX

| Anahtar | Değer |
|---|---|
| `latex-workshop.view.pdf.viewer` | `tab` (VS Code içi sekme) |
| `latex-workshop.view.pdf.tab.editorGroup` | `right` |
| `latex-workshop.view.pdf.internal.synctex.keybinding` | `ctrl-click` (ters SyncTeX) |
| `latex-workshop.view.pdf.internal.keyboardEvent` | `auto` (PDF sekmesindeyken kısayollar VS Code'a iletilir) |
| `latex-workshop.synctex.afterBuild.enabled` | `false` (her derlemede PDF'in zıplamaması için) |

Koyu temada PDF'i karartmak isterseniz:
`"latex-workshop.view.pdf.invertMode.enabled": "auto"` ekleyin.

### IntelliSense ve hover

`intellisense.package.enabled` (kullanılan paketlerin komut/ortamları),
`intellisense.unimathsymbols.enabled` (unicode-math sembolleri),
`intellisense.citation.backend: biblatex`, `hover.preview/ref/citation/command`.

- **Paket tamamlama:** `\usepackage{` yazınca
- **Ortam tamamlama:** `\begin{` yazınca
- **Atıf tamamlama:** `\cite{` yazınca (`.bib` dosyalarından)
- **Çapraz referans:** `\ref{`, `\cref{`, `\eqref{` yazınca (`\label`'lardan)
- **Matematik sembolleri:** `\` ile başlayan komut önerileri ve LaTeX Workshop
  kenar çubuğundaki *Snippet View* / *Math symbols* paneli
- **Hover:** denklem, `\ref` ve `\cite` üzerine gelince önizleme
- **Ana hat:** VS Code *Outline* görünümü ve LaTeX Workshop *Structure* paneli

### Tanılama {#chktex}

| Anahtar | Değer |
|---|---|
| `latex-workshop.linting.chktex.enabled` | `true` |
| `latex-workshop.linting.run` | `onSave` |
| `latex-workshop.linting.chktex.exec.args` | `-wall -n22 -n30 -e16 -q -l ~/.config/chktex/chktexrc` |
| `latex-workshop.linting.lacheck.enabled` | `false` (ChkTeX ile aynı uyarıları tekrarlamasın) |

> **Not:** Eski `latex-workshop.chktex.enabled` / `latex-workshop.chktex.run`
> anahtarları LaTeX Workshop 10.x'te **yoktur** ve yok sayılır. Doğrusu
> `latex-workshop.linting.*`. `doctor.sh --project DIR` bu tür eski
> anahtarları bulur.

Projeye özel ChkTeX kuralı (argümanlarda `-l` olduğundan LaTeX Workshop
projedeki `.chktexrc` dosyasını kendiliğinden eklemez):

```jsonc
// <proje>/.vscode/settings.json
{
    "latex-workshop.linting.chktex.exec.args": [
        "-wall", "-n22", "-n30", "-e16", "-q",
        "-l", "/home/KULLANICI/.config/chktex/chktexrc",
        "-l", ".chktexrc"
    ]
}
```

### Biçimlendirme

`formatting.latex: latexindent`,
`formatting.latexindent.args: -c ~/.cache/latexindent/ %TMPFILE% -y=defaultIndent: '%INDENT%'`.
Ayrıntılar `config/latexindent.yaml` içindeki yorumlarda.

### Kelime sayımı

`texcount.args: ["-utf8"]` (LaTeX Workshop `-merge` ekler, `\input` ve
`\include` dosyalarını sayar), `texcount.autorun: onSave` (durum çubuğunda).

### Yazım denetimi (İngilizce + Türkçe)

- **Code Spell Checker** (yerel, çevrimdışı, açık kaynak) + resmi
  **Türkçe sözlük** eklentisi (`tr-tr`, Hunspell kaynaklı).
- `cSpell.languageSettings` ile Türkçe sözlük **yalnızca `latex` ve `bibtex`
  dosyalarına** eklenir. C++/Python dosyalarınız eskisi gibi yalnızca
  İngilizce denetlenir.
- LaTeX komutları, ortam adları ve matematik, Code Spell Checker'ın yerleşik
  LaTeX desteğiyle denetim dışı kalır.

**Sınırlama:** Türkçe eklemeli bir dildir. Sözlük tabanlı denetim tüm ek
kombinasyonlarını bilemez (ör. *-lerinden*, *-leştirilmesi*). Bu yüzden
doğru kelimeler de işaretlenebilir. Çözüm: kelimenin üzerinde *Quick Fix*
(Ctrl+.) → *Add to user/workspace dictionary*. Dilbilgisi denetimi
(LanguageTool/LTeX+) Java tabanlı ve ağır olduğu için kurulmaz. İsterseniz
`ltex-plus.vscode-ltex-plus` eklentisini kendiniz ekleyebilirsiniz.

### Editör (yalnızca `[latex]` / `[bibtex]`)

`editor.defaultFormatter: James-Yu.latex-workshop`, `formatOnSave: false`,
`wordWrap: on`, `tabSize: 2`, `insertSpaces: true`, `quickSuggestions`
(yorumlar hariç), `snippetsPreventQuickSuggestions: false`,
`snippetSuggestions: top`.

## latexmk ve `\include` alt dizinleri

`\include{chapters/giris}` ve `-outdir=build` birlikte kullanılınca TeX
`build/chapters/giris.aux` dosyasını yazmak ister. Dizin yoksa derleme
`I can't write on file` hatasıyla durur. latexmk'in kendi kurtarma mekanizması
(`$allow_subdir_creation`) yalnızca `! I can't write on file` biçimini tanır;
LaTeX Workshop'un kullandığı `-file-line-error` biçimini
(`./main.tex:116: I can't write on file`) tanımaz. Bu davranış latexmk
4.87'nin kaynak kodunda doğrulandı.

Çözüm `config/latexmk/include-subdirs.pl`: latexmk'e `-r` ile verilir ve
derlemeden önce `.tex` içeren her kaynak alt dizinini `build/` altına
yansıtır. Yalnızca dizin oluşturur, hiçbir şey silmez. Şablonların
`.latexmkrc` dosyaları komut satırı için aynısını yapar.

## Mevcut projeler

Proje dizininde `.vscode/settings.json` varsa oradaki `latex-workshop.*`
anahtarları global ayarları **gizler**. Örneğin projede tanımlı `recipes`
varsa global tarifler orada görünmez. Kontrol:

```bash
./scripts/doctor.sh --quick --project ~/Documents/latex-projects/test
```

Global yapılandırmayı kullanmak için projedeki `latex-workshop.*`
anahtarlarını silin (önce yedek alın). Projeye özgü bir motor gerekiyorsa
yalnızca kök dosyaya `% !LW recipe = PDFLaTeX (latexmk)` yazın.
