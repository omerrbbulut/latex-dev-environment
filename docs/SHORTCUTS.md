# Klavye kısayolları — kopya kâğıdı

Kaynak: [`vscode/keybindings.json`](../vscode/keybindings.json). Her komut
kimliği kurulu **LaTeX Workshop 10.20.0** sürümünün `package.json`
dosyasındaki `contributes.commands` listesine karşı doğrulandı. `doctor.sh`
bunu her çalıştırmada yeniden kontrol eder; ölü kısayol kalmaz.

## Derleme ve önizleme

| Kısayol | İşlem | Komut | Bağlam |
|---|---|---|---|
| `Ctrl+Alt+B` | Derle | `latex-workshop.build` | LaTeX, BibTeX, PDF sekmesi |
| `Ctrl+S` | Kaydet → otomatik derle | `workbench.action.files.save` | VS Code varsayılanı + `autoBuild.run: onSave` |
| `Ctrl+Alt+M` | Tarif seç (XeLaTeX/PDFLaTeX/LuaLaTeX/.latexmkrc) | `latex-workshop.recipes` | LaTeX, BibTeX, PDF sekmesi |
| `Ctrl+Alt+K` | Çalışan derlemeyi durdur | `latex-workshop.kill` | LaTeX, BibTeX, PDF sekmesi |
| `Ctrl+Alt+C` | Yardımcı dosyaları temizle (`latexmk -c`) | `latex-workshop.clean` | LaTeX, BibTeX, PDF sekmesi |
| `Ctrl+Alt+L` | Derleyici günlüğü (LaTeX log) | `latex-workshop.compilerlog` | LaTeX, BibTeX, PDF sekmesi |
| `Ctrl+Alt+V` | PDF önizleme (sağ grupta sekme) | `latex-workshop.view` | LaTeX editörü |
| `Ctrl+Alt+R` | PDF görüntüleyiciyi yenile | `latex-workshop.refresh-viewer` | LaTeX editörü, PDF sekmesi |

## SyncTeX

| Kısayol | İşlem | Komut / ayar |
|---|---|---|
| `Ctrl+Alt+J` | İleri arama: imlecin olduğu satırı PDF'te göster | `latex-workshop.synctex` (editör odaklıyken) |
| `Ctrl+Click` (PDF içinde) | Ters arama: tıklanan yerin kaynağına git | `latex-workshop.view.pdf.internal.synctex.keybinding: ctrl-click` |

## Düzenleme

| Kısayol | İşlem | Komut | Bağlam |
|---|---|---|---|
| `Ctrl+Alt+F` | Belgeyi biçimlendir (latexindent) | `editor.action.formatDocument` | LaTeX, BibTeX editörü |
| `Ctrl+Space` | IntelliSense önerileri | `editor.action.triggerSuggest` | VS Code varsayılanı |
| `Ctrl+Alt+W` | Kelime sayısı (texcount) | `latex-workshop.wordcount` | LaTeX editörü |
| `Ctrl+Alt+P` | Matematik önizleme paneli | `latex-workshop.toggleMathPreviewPanel` | LaTeX editörü |
| `Ctrl+Shift+M` | Sorunlar paneli (derleme hataları + ChkTeX) | `workbench.actions.view.problems` | VS Code varsayılanı |

LaTeX Workshop'un kendi kısayolları da çalışmaya devam eder, örneğin
`Ctrl+L Ctrl+B` → `\textbf`, `Ctrl+L Ctrl+I` → `\textit`, `Ctrl+L Ctrl+E` →
`\emph`, `Ctrl+M Ctrl+B` → `\mathbf`, `Ctrl+L Ctrl+W` → seçimi sar,
`Ctrl+Alt+[` / `Ctrl+Alt+]` → bölüm seviyesini yükselt/düşür,
`Ctrl+Alt+X` → LaTeX Workshop kenar çubuğu.

## Bağlam (`when`) ifadeleri

```text
LaTeX editörü : editorLangId =~ /^latex$|^latex-expl3$|^doctex$/
+ BibTeX      : ... |^bibtex$/
PDF sekmesi   : activeWebviewPanelId == 'latex-workshop-pdf'
```

Bu kısayollar C/C++, Python, QML vb. dosyalarda **etkin değildir**. Oradaki
davranış değişmez.

## Çakışma analizi

Kontrol edilenler:

1. **Mevcut kullanıcı kısayolları:** `~/.config/Code/User/keybindings.json`
   kurulumdan önce yoktu, çakışma yok.
2. **Kurulu tüm eklentiler** (`~/.vscode/extensions/*/package.json`): seçilen
   tuşları kullanan başka eklenti yok.
3. **LaTeX Workshop varsayılanları:** `Ctrl+Alt+B/V/J/C` zaten aynı
   komutlara bağlı (tutarlı). `Ctrl+Alt+M` varsayılan olarak matematik
   önizleme panelini açıyordu. İstenen "tarif seç" işlevi için yeniden
   atandı. Matematik önizleme **`Ctrl+Alt+P`** tuşuna taşındı ve eski bağ
   `-latex-workshop.toggleMathPreviewPanel` ile açıkça kaldırıldı.
4. **GNOME (Ubuntu 26.04, `gsettings`):** `Ctrl+Alt` ile tanımlı sistem
   kısayolları `Ctrl+Alt+T` (özel: kitty), `Ctrl+Alt+D` (masaüstünü göster),
   `Ctrl+Alt+Delete`, `Ctrl+Alt+Tab/Esc`, `Ctrl+Alt+←/→/↑/↓` (çalışma alanı)
   ve `Ctrl+Alt+F1…F12` (oturum). Seçilen harflerle (B V J R C K M P F L W)
   **çakışma yok**. IBus giriş yöntemi `Super+Space` kullandığından
   `Ctrl+Space` serbesttir.
5. **VS Code yerleşik kısayolları:** kullanıcı kısayolları varsayılanların
   önüne geçer ve buradakiler yalnızca LaTeX bağlamında etkindir.
   `Ctrl+Alt+R` terminalde (*Run Recent Command*) aynen çalışmaya devam eder,
   çünkü bağlamı `terminalFocus`'tur.

Sistem kısayollarında hiçbir değişiklik yapılmadı.

## Doğrulama durumu

| Öğe | Otomatik | Elle |
|---|---|---|
| Komut kimlikleri mevcut | ✔ `doctor.sh` | |
| JSONC geçerli, blok güncel | ✔ `doctor.sh` | |
| Tuşa basınca komutun çalışması | | ✔ VS Code içinde denenmeli |
| PDF sekmesi odaklıyken kısayollar (`keyboardEvent: auto`) | | ✔ elle denenmeli |
| Ctrl+Click ters SyncTeX | ✔ `synctex edit` ile motor düzeyinde | ✔ arayüzde elle |

Elle test: bir şablonu açın, `Ctrl+Alt+B` → `Ctrl+Alt+V` → bir satırda
`Ctrl+Alt+J` → PDF'te `Ctrl+Click` → `Ctrl+Alt+M` → `Ctrl+Alt+W` →
`Ctrl+Alt+F` → `Ctrl+Alt+L`.

## Kısayolları özelleştirme

**Depo kopyasını değiştirin** (kalıcı ve tüm makinelerde aynı):

1. `vscode/keybindings.json` dosyasında `"key"` değerini değiştirin.
2. `./scripts/configure-vscode.sh` → yönetilen blok güncellenir.
3. Bağlantı sorunsuz mu: `./scripts/doctor.sh --quick`

**Yalnızca bu makinede:** `Ctrl+K Ctrl+S` (Keyboard Shortcuts) arayüzünden
değiştirin. VS Code yeni kaydı dosyanın **sonuna**, yani yönetilen bloğun
**dışına** ekler. Bir kısayolu devre dışı bırakmak için:

```jsonc
{ "key": "ctrl+alt+w", "command": "-latex-workshop.wordcount" }
```

Bir komutun gerçek kimliğini bulmak için: Keyboard Shortcuts ekranında
komuta sağ tıklayın → *Copy Command ID*.
