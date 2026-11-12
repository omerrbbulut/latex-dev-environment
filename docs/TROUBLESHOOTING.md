# Sorun giderme

İlk adım her zaman:

```bash
./scripts/doctor.sh            # tam rapor (derleme testleri ~1 dk)
./scripts/doctor.sh --quick    # yalnızca araç + yapılandırma
./scripts/doctor.sh --project <proje-dizini>
./scripts/doctor.sh --keep     # geçici derleme dizinini incelemek için saklar
```

## Derleme

**`I can't write on file 'chapters/giris.aux'`.**
`\include` kullanan bir projede `build/chapters/` yok demektir. Normalde
`include-subdirs.pl` bunu önler. Kontrol edin:
`./scripts/doctor.sh --quick` → `installed: ~/.config/latex-dev-environment/latexmk/include-subdirs.pl`.
Projenin `.vscode/settings.json` dosyası kendi `latex-workshop.latex.tools`
tanımını içeriyorsa global araçlar kullanılmaz. O araçlara `-r` satırını
ekleyin ya da proje ayarını kaldırın.

**Global tarifler (LuaLaTeX vb.) görünmüyor.**
Proje `.vscode/settings.json` içinde `latex-workshop.latex.recipes`
tanımlıdır ve globali gizler. `doctor.sh --project DIR` bunu `WARN` olarak
gösterir.

**`fontspec error: "font-not-found"` / Aptos bulunamadı.**
`fc-list | grep -i aptos`. Font kurulu değilse şablonlar otomatik olarak TeX
Gyre Heros kullanır. Kendi belgenizde `\setmainfont{Aptos}` varsa fontu
kurun (bkz. [INSTALLATION.md](INSTALLATION.md#aptos-fontu)) veya
`\IfFontExistsTF` kullanın. Kurulumdan sonra `fc-cache -f` çalıştırın.

**Türkçe metinde `listings` hatası: `Couldn't load requested language`.**
Türkçe kurallarında `\lowercase{I}` noktasız `ı` verir. Bu yüzden
`language=C` (iç ad `[ANSI]C`) belge içinde bulunamaz. Önsözde dilleri
önceden yükleyin: `\lstloadlanguages{[ANSI]C,Python,bash}` (teknik rapor
şablonunda var).

**cleveref + polyglossia Türkçe: `Undefined control sequence ... \extras...`.**
cleveref Türkçe bilmez ve polyglossia dillerini yanlış algılar. Çözüm
(şablonlarda uygulandı):
`\usepackage[english,nameinlink,noabbrev]{cleveref}` ve ardından
`\crefname{figure}{Şekil}{Şekiller}` vb.

**`Package csquotes Warning: No style for language 'turkish'`.**
`\DeclareQuoteStyle{turkish}{\textquotedblleft}{\textquotedblright}{\textquoteleft}{\textquoteright}`

**Kaynakça boş / `Citation ... undefined`.**
`build/main.blg` dosyasına bakın. `.bib` sözdizimi hatası, yanlış
`\addbibresource` yolu veya `backend=biber` eksikliği olabilir. Bir kez
`Ctrl+Alt+C` (temizle) ve ardından `Ctrl+Alt+B`.

**Derleme takıldı.** `Ctrl+Alt+K`. `nonstopmode` etkileşim beklemez, ama
sonsuz döngüdeki bir makro yine de takılabilir.

## PDF ve SyncTeX

**PDF açılmıyor veya eski kalıyor.** `Ctrl+Alt+R` (yenile). PDF
`build/main.pdf` konumunda olmalıdır. `outDir` başka bir yeri gösteriyorsa
proje ayarlarını kontrol edin.

**Ters SyncTeX çalışmıyor.** PDF sekmesinde **Ctrl** basılıyken tıklayın.
`build/main.synctex.gz` dosyası olmalıdır. SyncTeX yakın bir satıra
gidebilir (paragraf/ortam sınırları). Bu normaldir.

**PDF sekmesindeyken kısayollar çalışmıyor.**
`latex-workshop.view.pdf.internal.keyboardEvent` `auto` olmalıdır. Bazı
tuşları PDF.js kendisi kullanır; editöre tıklayıp tekrar deneyin.

## Kısayollar

**Bir kısayol hiçbir şey yapmıyor.** Command Palette → *Preferences: Open
Keyboard Shortcuts* → tuşa basarak arayın. Başka bir kayıt (özellikle
bloğun dışındaki kendi kayıtlarınız) daha sonra tanımlandığı için önde
olabilir. `Developer: Toggle Keyboard Shortcuts Troubleshooting` hangi
komutun tetiklendiğini gösterir.

**Kısayolu GNOME yakalıyor.** `gsettings list-recursively org.gnome.desktop.wm.keybindings | grep -i "<Control><Alt>"`.
Kurulumda seçilen tuşlarla çakışma yoktu (bkz. [SHORTCUTS.md](SHORTCUTS.md#çakışma-analizi)).
Sonradan bir GNOME kısayolu eklediyseniz VS Code tarafını değiştirin.

## Lint, biçimlendirme, yazım

**ChkTeX uyarısı yok.** Eski `latex-workshop.chktex.enabled` anahtarı
LaTeX Workshop 10.x'te geçersizdir. `latex-workshop.linting.chktex.enabled`
kullanılır (`doctor.sh --project` eski anahtarları bildirir). Lint yalnızca
**kayıtta** çalışır.

**Çok fazla ChkTeX uyarısı.** Belirli bir satırı susturmak için satır sonuna
`% chktex 1` (uyarı numarası) yazın. Projeye özel kural için
[CONFIGURATION.md](CONFIGURATION.md#chktex).

**Format Document hiçbir şey yapmıyor / hata veriyor.**
`latexindent --version`. Perl modülleri eksikse `sudo apt install texlive-extra-utils`.
`~/.cache/latexindent/indent.log` dosyasına bakın. Birden fazla biçimlendirici
varsa: Command Palette → *Format Document With…* → *LaTeX Workshop*.

**Türkçe kelimeler yanlış işaretleniyor.** Bkz.
[CONFIGURATION.md](CONFIGURATION.md#yazım-denetimi-ingilizce--türkçe):
kelime üzerinde `Ctrl+.` → *Add to user dictionary*. Türkçe sözlük yalnızca
LaTeX/BibTeX dosyalarında etkindir.

## Yapılandırma

**`do not run install-ubuntu.sh with sudo`.** Betikleri kendi kullanıcınızla
çalıştırın: `./scripts/install-ubuntu.sh`. Gerekirse apt için `sudo`
parolasını betik kendisi ister. `sudo` ile çalıştırmak root'un ev dizinini
yapılandırır ve root'a ait dosyalar bırakır. Bu yüzden engellenir.

**`WARN '...' is already set outside the managed block`.** O anahtarı siz
tanımlamışsınız ve sizin değeriniz kullanılıyor. Depo değerini kullanmak
için kendi satırınızı silip `configure-vscode.sh` çalıştırın.

**Yedeğe geri dönmek.**

```bash
ls ~/.local/state/latex-dev-environment/backups/
cp ~/.local/state/latex-dev-environment/backups/<zaman>/.config/Code/User/settings.json.<zaman>.bak \
   ~/.config/Code/User/settings.json
```
