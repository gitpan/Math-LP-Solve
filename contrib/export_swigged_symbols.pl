#!/freeware/bin/perl -w
use strict;
require 5.005;
use vars qw($VERSION $swig_docfile $pm_file $verbose);
use Getopt::Long;
use IO::File;
use Data::Dumper;
use Pod::Usage;
$VERSION = sprintf('%d.%02d', q{ $Revision: 1.5 $ } =~ /(\d+)\.(\d+)/);

# command line processing
Getopt::Long::Configure('no_ignore_case'); # so -v and -V are distinct, valid options
GetOptions(
   'swig-docfile=s' => \$swig_docfile, # ASCII file generated by SWIG
   'pm-file=s'      => \$pm_file,      # .pm file in which the Export behaviour will be altered
   'verbose'        => \$verbose,
   'Version'        => sub { print $VERSION, "\n"; exit 0; },
   'help|?'         => sub { pod2usage(exitval => 0, verbose => 1) }, # SYNOPSIS, OPTIONS and ARGUMENTS
   'man'            => sub { pod2usage(exitval => 0, verbose => 2) }, # whole manpage
) or pod2usage(verbose => 2);
defined($swig_docfile) or pod2usage(msg => "ERROR: no SWIG generated documentation file specified");
defined($pm_file)      or pod2usage(msg => "ERROR: no SWIG generated perl module specified");

# parse the ASCII documentation generated with SWIG
my %symbols = ();
my $re_arglist = qr/\([a-z0-9_,\* ]*\)/; # matches bracket delimited list of args
my $fh_doc = new IO::File;
$fh_doc->open($swig_docfile) or die "Cannot read file `$swig_docfile': $!\n";
while(<$fh_doc>) {
    if(/^(\$\w+)/) {
	push @{$symbols{scalars}}, $1;
	warn "S $1\n" if $verbose;
    }
    elsif(/^(ptr[a-z]+)$re_arglist/) {
	push @{$symbols{ptrlib}}, $1;
	warn "P $1()\n" if $verbose;
    }
    elsif(/^(\w+_[gs]et)$re_arglist/) {
	push @{$symbols{accessors}}, $1;
	warn "A $1()\n" if $verbose;
    }
    elsif(/^(\w+)$re_arglist/) {
	push @{$symbols{functions}}, $1;
	warn "F $1()\n" if $verbose;
    }
}
$fh_doc->close();

# add a category of ALL symbols
$symbols{ALL} = [map { @{$symbols{$_}} } sort keys %symbols];

# make a copy of the pm-file to a temporary file, adapting the Exporter related info
my $fh_pm = new IO::File;
$fh_pm->open($pm_file) or die "Cannot read file `$pm_file': $!\n";
my $new_pm_file = $pm_file . ".$$.tmp";
my $fh_new_pm = new IO::File;
$fh_new_pm->open(">$new_pm_file") or die "Cannot create file `$new_pm_file': $!\n";
{
    local *STDOUT = $fh_new_pm;
    while(<$fh_pm>) {
	if(/^1;/) { # at end of module, add Export info
	    print Data::Dumper->Dump([\%symbols],[qw(*EXPORT_TAGS)]);
	    print Data::Dumper->Dump([$symbols{ALL}],[qw(*EXPORT_OK)]);
	}
	print $_;
    }
}
$fh_new_pm->close();
$fh_pm->close();

# move the temporary file to the original file
unlink($pm_file) or die "Failed to remove file `$pm_file'\n";
rename($new_pm_file,$pm_file) or die "Failed to move `$new_pm_file' to `$pm_file'\n";

__END__

=head1 NAME

export_swigged_symbols.pl - utility to extract package symbols from a SWIG generated
output file and prepare them for exporting from the SWIG generated Perl module

=head1 SYNOPSIS

  export_swigged_symbols.pl --swig-docfile=<file> --pm-file=<file>
       [--help] [-?] [--man] [--verbose] [--Version]

Parses the ASCII documentation file generated by SWIG for package symbols.
The symbols are separated in scalar variables, data field accessors (get/set)
and general functions. This info is written into the given perl module
(also generated by SWIG) in the EXPORT_TAGS hash under the keys scalars,
accessors and functions respectively. In addition, all symbols are made
available under the ALL key, and made available for exporting through the
EXPORT_OK list.

The contents of the pm-file are thus altered.

=head1 OPTIONS

Following options and unique abbreviations of them are accepted:

=over 4

=item B<--swig-docfile>

name of the ASCII documentation file generated with SWIG

=item B<--pm-file>

name of the perl module generated with SWIG

=item B<--help> or B<-?>

prints a brief help message and exits

=item B<--man>

prints an extended help message and exits

=item B<--verbose>

enables printing of info on the exported symbols to stderr

=item B<--Version>

prints the version number and exits

=back

=head1 ARGUMENTS

No arguments are accepted. All needed parameters are passed as options.

=head1 REMARKS

The current version of export_swigged_symbols.pl is designed for 
handling output of SWIG 1.1 (Build 883). It is not tested for other releases,
but I assume it will work with SWIG 1.1p5 too.

More info on SWIG is available at http://www.swig.org/

=head1 RELEASE

$Id: export_swigged_symbols.pl,v 1.5 2000/09/11 13:39:44 verhaege Exp $

=head1 AUTHOR

Wim Verhaegen E<lt>wim.verhaegen@ieee.orgE<gt>

=cut
