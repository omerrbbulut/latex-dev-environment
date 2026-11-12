# latexmk configuration for command-line builds: `latexmk` in this folder.
# VS Code passes its own engine/outdir flags, which take precedence.
$pdf_mode = 5;            # 5 = xelatex -> xdvipdfmx
$out_dir  = 'build';
$aux_dir  = 'build';
@default_files = ('main.tex');
set_tex_cmds('-synctex=1 -interaction=nonstopmode -file-line-error %O %S');
