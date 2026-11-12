# latex-dev-environment — latexmk helper (Perl, read with `latexmk -r FILE`).
#
# Problem: with -outdir/-auxdir, \include{chapters/intro} makes the engine
# write build/chapters/intro.aux. If build/chapters/ does not exist the run
# aborts with "I can't write on file". latexmk can normally recover
# ($allow_subdir_creation), but it only recognises the plain "! I can't
# write" form, not the -file-line-error form used by LaTeX Workshop.
#
# Fix: before compiling, mirror every source subdirectory that contains .tex
# files into the aux/out directory. Pass this file AFTER -outdir/-auxdir on
# the command line so their values are already known:
#   latexmk -xelatex -outdir=build -auxdir=build -r include-subdirs.pl main.tex
# Safe to run repeatedly; only creates directories, never deletes anything.

use strict;
use warnings;
use File::Find ();
use File::Path ();
use File::Spec ();
use Cwd ();

{
    no strict 'vars';
    my @targets = grep { defined && $_ ne '' } ($aux_dir, $out_dir);
    my %seen;
    my $cwd = Cwd::getcwd();
    for my $target (grep { !$seen{$_}++ } @targets) {
        my $abs_target = File::Spec->rel2abs($target, $cwd);
        next if $abs_target eq $cwd;    # building in place: nothing to do
        my %dirs;
        File::Find::find(
            {
                no_chdir   => 1,
                preprocess => sub {
                    # never descend into hidden dirs or the build dir itself
                    grep {
                        my $p = File::Spec->rel2abs(File::Spec->catfile($File::Find::dir, $_), $cwd);
                        !/^\./ && $p ne $abs_target && index($p, "$abs_target/") != 0
                    } @_;
                },
                wanted => sub {
                    return unless /\.tex$/ && -f $_;
                    my $rel = File::Spec->abs2rel($File::Find::dir, $cwd);
                    $dirs{$rel} = 1 if $rel ne '.' && $rel !~ m{^\.\.};
                },
            },
            '.'
        );
        for my $d (sort keys %dirs) {
            my $path = File::Spec->catdir($abs_target, $d);
            File::Path::make_path($path) unless -d $path;
        }
    }
}

1;
