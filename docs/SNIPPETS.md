# Snippet referansı

Kaynak: [`vscode/latex.code-snippets`](../vscode/latex.code-snippets) (tek
doğru kaynak). Kurulum yeri:
`~/.config/Code/User/snippets/latex.code-snippets`. Tüm projelerde ve
yalnızca `latex` dil kipinde geçerlidir.

**Kullanım:** öneki yazın → öneri listesinde seçip `Enter` (veya `Tab`) →
`Tab` / `Shift+Tab` ile alanlar arasında gezinin → seçimli alanlarda
(`cite`, `ref`, `lst`, `mat`) açılan listeden seçin. `$0`, son imleç
konumudur.

| Önek | Üretir | Gereken paket |
|---|---|---|
| `eq` | `\begin{equation} … \label{eq:…} \end{equation}` | — |
| `eqs` | `\begin{equation*} … \end{equation*}` | amsmath |
| `align` | `align`, iki satır, ilki `\label{eq:…}`, ikincisi `\nonumber` | amsmath |
| `aligns` | `align*` | amsmath |
| `fig` | `figure[htbp]` + `\centering` + `\includegraphics[width=0.8\textwidth]` + `\caption` + `\label{fig:…}` | graphicx |
| `subfig` | iki `subfigure` (0.48\textwidth), ortak etiket kökü `fig:ad`, `fig:ad-a`, `fig:ad-b` | graphicx, subcaption |
| `tbl` | `table[htbp]` + üstte başlık + `tabular` + `\toprule/\midrule/\bottomrule` | booktabs |
| `chap` | `\chapter{…}` + `\label{chap:…}` | report/book sınıfı |
| `sec` | `\section{…}` + `\label{sec:…}` | — |
| `ssec` | `\subsection{…}` + `\label{sec:…}` | — |
| `sssec` | `\subsubsection{…}` + `\label{sec:…}` | — |
| `cite` | `\cite` · `\parencite` · `\textcite` · `\autocite` · `\citeauthor` · `\citeyear` | `\cite` dışındakiler: biblatex |
| `ref` | `\ref` · `\eqref` · `\pageref` · `\autoref` · `\cref` · `\Cref` | eqref: amsmath, autoref: hyperref, cref: cleveref |
| `item` | `itemize`, iki madde | — |
| `enum` | `enumerate`, iki madde | — |
| `desc` | `description` | — |
| `algo` | `algorithm` + `algorithmic[1]` (`\Require`, `\Ensure`, `\State`, `\For`, `\Return`) | algorithm, algpseudocode |
| `lst` | `lstlisting[language=…, caption=…, label=lst:…]` | listings |
| `thm` | `\begin{theorem}[Ad] \label{thm:…}` | önsözde `\newtheorem{theorem}{Theorem}` (amsthm önerilir) |
| `lem` | `\begin{lemma}[Ad] \label{lem:…}` | önsözde `\newtheorem{lemma}{Lemma}` |
| `proof` | `\begin{proof} … \end{proof}` | amsthm |
| `mat` | `pmatrix` · `bmatrix` · `vmatrix` · `matrix` (matematik kipinde) | amsmath |
| `cases` | parçalı tanım (matematik kipinde) | amsmath |
| `beg` | genel `\begin{ad} … \end{ad}` (ad iki yerde birden değişir) | — |

## Etiket kuralları

`eq:`, `fig:`, `tab:`, `sec:`, `chap:`, `alg:`, `lst:`, `thm:`, `lem:`.
LaTeX Workshop'un çapraz referans tamamlaması bu önekleri gruplar.

## Doğrulama

`tests/snippet_check.py` (`doctor.sh` ve `tests/run-tests.sh` tarafından
çağrılır):

- katı JSON, yinelenen ad/önek yok, `scope: latex`, açıklama mevcut
- VS Code snippet dilbilgisi: `${1:…}`, `${1|a,b|}`, `$1` yansıtma, `\$`, `\}`,
  `\\` kaçışları; sekme durakları boşluksuz (1…n), `$0` mevcut
- genişletilmiş metinde süslü parantez ve `\begin`/`\end` dengesi
- `--render` ile **tüm snippet'ler varsayılan değerleriyle genişletilip** tek
  bir belgeye yazılır ve pdfLaTeX + XeLaTeX ile **derlenir**

JSON içinde kaçış: LaTeX'teki `\` → JSON'da `\\`. Snippet'te gerçek `\\`
(satır sonu) → JSON'da `\\\\\\\\`. Snippet içinde gerçek `$` → JSON'da `\\$`.
Bir yer tutucunun içindeki `}` → JSON'da `\\}`.

## Yeni snippet ekleme

1. `vscode/latex.code-snippets` dosyasına ekleyin.
2. `python3 tests/snippet_check.py vscode/latex.code-snippets`
3. `./tests/run-tests.sh` (derleme testi dahil)
4. `./scripts/configure-vscode.sh`

Snippet önekleri LaTeX Workshop'un yerleşik tamamlamalarıyla birlikte
listelenir. `editor.snippetSuggestions: top` LaTeX için snippet'leri üste
alır.
