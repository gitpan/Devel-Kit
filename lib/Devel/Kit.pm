package Devel::Kit;

use strict;
use warnings;

use Module::Want ();

$Devel::Kit::VERSION = '0.1';
$Devel::Kit::fh      = \*STDOUT;

sub import {
    my $caller = caller();

    my $pre = '';
    for (@_) {
        if ( $_ =~ m/(_+)/ ) {
            $pre = $1;
            last;
        }
    }

    no strict 'refs';    ## no critic
    for my $l (qw(d yd jd xd sd md id pd fd dd ld ud gd bd vd ms ss be bu ue uu he hu pe pu se su qe qu)) {
        *{ $caller . '::' . $pre . $l } = \&{$l};
    }

    unless ( grep( m/ni/, @_ ) ) {
        require Import::Into;    # die here since we don't need it otherwise, so we know right off there's a problem, and so caller does not have to check status unless they want to
        strict->import::into($caller);
        warnings->import::into($caller);
    }
}

# output something w/ one trailing newline gauranteed
sub o {
    my ($str) = @_;
    $str =~ s{[\n\r]+$}{};
    print {$Devel::Kit::fh} "$str\n";
}

# dump a perl ref()
sub p {
    my $ref = ref( $_[0] );

    if ( !$ref ) {
        if ( !@_ ) {
            return "no args passed to p()";
        }
        elsif ( !defined $_[0] ) {
            return "undef() passed to p()";
        }
        elsif ( $_[0] eq '' ) {
            return "empty string passed to p()";
        }
        else {
            return "non-ref passed to p(): $_[0]";
        }
    }

    if ( $ref eq 'Regexp' ) {
        return "\tRegexp: /$_[0]/";
    }
    elsif ( Module::Want::have_mod('Data::Dumper') ) {

        # blatantly stolen from Test::Builder::explain() then wantonly added Pad()
        my $dumper = Data::Dumper->new( [ $_[0] ] );
        $dumper->Indent(1)->Terse(1)->Pad("\t");
        $dumper->Sortkeys(1) if $dumper->can("Sortkeys");
        return $dumper->Dump;
    }
    else {
        return "Error: “Data::Dumper” could not be loaded:\n\t$@\n";
    }
}

sub d {
    my @caller = caller();

    if ( !@_ ) {
        o("debug() w/ no args at $caller[1] line $caller[2].");
        return;
    }

    my $arg_index = @_ > 1 ? -1 : undef();
    my $i;    # buffer
    for $i (@_) {    ## no critic
        $arg_index++ if defined $arg_index;
        my $arg_note = defined $arg_index ? $arg_index : '';

        if ( ref($i) ) {
            o( "debug($arg_note) ref($i) at $caller[1] line $caller[2]:\n" . p($i) );
        }
        elsif ( !defined $i ) {
            o("debug($arg_note) undef at $caller[1] line $caller[2].");
        }
        elsif ( $i eq '' ) {
            o("debug($arg_note) empty at $caller[1] line $caller[2].");
        }
        elsif ( $i =~ m/\A-?[1-9][0-9]*(?:\.[0-9]+)?\z/ ) {    # we're not that worried about matching every possible numeric looking thing so no need to spend on looks_like_number()
            o("debug($arg_note) number: $i");
        }
        else {
            o("debug($arg_note): $i");
        }
    }

    return;
}

# YAML Dumper
sub yd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'YAML::Syck',
        sub {
            eval { YAML::Syck::Load( $_[0] ); } || "Error: Invalid YAML ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# JSON Dumper
sub jd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'JSON::Syck',
        sub {
            eval { JSON::Syck::Load( $_[0] ); } || "Error: Invalid JSON ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# XML Dumper
my $xml;

sub xd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'XML::Parser',
        sub {
            $xml ||= XML::Parser->new(
                'Style'            => 'Tree',
                'ProtocolEncoding' => 'UTF-8',
            );

            eval { $xml->parsestring( $_[0] ); } || "Error: Invalid XML ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# Storable Dumper
sub sd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Storable',
        sub {
            eval { Storable::thaw( $_[0] ); } || "Error: Invalid Storable ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# INI dump
sub id {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Config::INI::Reader',
        sub {
            eval { Config::INI::Reader->read_string( $_[0] ); } || "Error: Invalid INI ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# Message Pack dump
my $mp;

sub md {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Data::MessagePack',
        sub {
            $mp ||= Data::MessagePack->new();

            eval { $mp->unpack( $_[0] ); } || "Error: Invalid MessagePack ($@):\n$_[0]";
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# Perl Dumper (e.g. Data::Dumper, Data::Dump, etc.)
sub pd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    no strict;    ## no critic
    @_ = eval( $_[0] ) || "Error: Invalid perl ($@):\n$_[0]";    ## no critic

    return @_ if $ret;
    goto &d;
}

# File dump
sub fd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    if ( !-l $_[0] && -f _ ) {
        if ( Module::Want::have_mod('File::Slurp') ) {
            my $info   = _stat_struct( $_[0] );
            my $line_n = 0;
            $info->{"13. contents"} = [ map { ++$line_n; my $l = $_; chomp($l); "$line_n: $l" } File::Slurp::read_file( $_[0] ) ];

            @_ = (
                {
                    "File “$_[0]”:" => $info,
                }
            );
        }
        else {
            @_ = ("Error: “File::Slurp” could not be loaded:\n\t$@\n");
        }
    }
    elsif ( !-e _ ) {
        @_ = ("“$_[0]” does not exist.");
    }
    else {
        @_ = ("“$_[0]” is not a file.");
    }

    return @_ if $ret;
    goto &d;
}

# Directory dump
sub dd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    if ( !-l $_[0] && -d _ ) {

        if ( Module::Want::have_mod('File::Slurp') ) {
            my $info = _stat_struct( $_[0] );
            $info->{"13. contents"} = scalar( File::Slurp::read_dir( $_[0] ) );

            @_ = (
                {
                    "Directory “$_[0]”:" => $info,
                }
            );
        }
        else {
            @_ = ("Error: “File::Slurp” could not be loaded:\n\t$@\n");
        }
    }
    elsif ( !-e _ ) {
        @_ = ("“$_[0]” does not exist.");
    }
    else {
        @_ = ("“$_[0]” is not a directory.");
    }

    return @_ if $ret;
    goto &d;
}

# Symlink dump
sub ld {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    if ( -l $_[0] ) {
        my $info = _stat_struct( $_[0] );
        $info->{"13. target"} = readlink( $_[0] );
        $info->{"14. broken"} = -l $info->{"13. target"} || -e _ ? 0 : 1;

        @_ = (
            {
                "Symlink “$_[0]”:" => $info,
            }
        );
    }
    elsif ( !-e _ ) {
        @_ = ("“$_[0]” does not exist.");
    }
    else {
        @_ = ("“$_[0]” is not a symlink.");
    }

    return @_ if $ret;
    goto &d;
}

# Unicode string dumper
sub ud {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    my ($unicode_string) = @_;

    utf8::decode($unicode_string) if !utf8::is_utf8($unicode_string);
    $unicode_string = _escape_bytes_or_unicode($unicode_string);
    @_              = ("Unicode: $unicode_string");

    return @_ if $ret;
    goto &d;
}

# bytes grapheme dumper
sub gd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    my ($byte_string) = @_;

    utf8::encode($byte_string) if utf8::is_utf8($byte_string);
    $byte_string = _escape_bytes_or_unicode($byte_string);
    @_           = ("Bytes grapheme: $byte_string");

    return @_ if $ret;
    goto &d;
}

# bytes string viewer
sub bd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    my ($byte_string) = @_;
    utf8::encode($byte_string) if utf8::is_utf8($byte_string);
    @_ = ("Bytes: $byte_string");

    return @_ if $ret;
    goto &d;
}

# Verbose/Variation of a string dump
sub vd {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    my ($s) = @_;

    @_ = (

        # tidy off
        _trim_label( bd( $s, '_Devel::Kit_return' ) ) . "\n"    # "$s\n"
          . "\tOriginal string type: "
          . ( utf8::is_utf8($s) ? 'Unicode' : 'Byte' ) . "\n"
          . "\tSize of data (bytes): "
          . _bytes_size($s) . "\n"
          . "\tNumber of characters: "
          . _char_count($s) . "\n" . "\n"
          . "\tUnicode Notation Str: "
          . _trim_label( ud( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tBytes Grapheme Str  : "
          . _trim_label( gd( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tBytes String        : "
          . _trim_label( bd( $s, '_Devel::Kit_return' ) ) . "\n" . "\n"
          . "\tMD5 Sum  : "
          . _trim_label( ms( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tSHA1 Hash: "
          . _trim_label( ss( $s, '_Devel::Kit_return' ) ) . "\n" . "\n"
          . "\tBase 64    : "
          . _trim_label( be( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tURI        : "
          . _trim_label( ue( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tHTML       : "
          . _trim_label( he( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tQuot-Print : "
          . _trim_label( qe( $s, '_Devel::Kit_return' ) ) . "\n"
          . "\tPunycode   : "
          . _trim_label( pe( $s, '_Devel::Kit_return' ) ) . "\n"

          # . "\tString Lit : "
          # . _trim_label( se( $s, '_Devel::Kit_return' ) ) . "\n"

          # tidy on
    );

    return @_ if $ret;
    goto &d;
}

# Serialize, Sum, haSh,

sub ms {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Digest::MD5',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "MD5 Sum: " . Digest::MD5::md5_hex($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub ss {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Digest::SHA',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "SHA1 Hash: " . Digest::SHA::sha1_hex($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

# Encode/Unencode Escape/Unescape

sub be {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'MIME::Base64',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "Base 64: " . MIME::Base64::encode_base64( $s, '' );
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub bu {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'MIME::Base64',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "From Base 64: " . MIME::Base64::decode_base64($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub ue {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'URI::Escape',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "URI: " . URI::Escape::uri_escape($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub uu {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'URI::Escape',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "From URI: " . URI::Escape::uri_unescape($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub he {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'HTML::Entities',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "HTML Safe: " . HTML::Entities::encode( $s, q{<>&"'} );
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub hu {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'HTML::Entities',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "From HTML Safe: " . HTML::Entities::decode($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub qe {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'MIME::QuotedPrint',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "Quoted-Printable: " . MIME::QuotedPrint::encode($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub qu {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'MIME::QuotedPrint',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);
            return "From Quoted-Printable: " . MIME::QuotedPrint::decode($s);
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub pe {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Net::LibIDN',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);

            # See Locale::Maketext::Utils::output_encode_puny()
            if ( $s =~ m/\@/ ) {
                my ( $nam, $dom ) = split( /@/, $s, 2 );

                # TODO: ? multiple @ signs ...
                # my ($dom,$nam) = split(/\@/,reverse($s),2);
                # $dom = reverse($dom);
                # $nam = reverse($nam);
                return Net::LibIDN::idn_to_ascii( $nam, 'utf-8' ) . '@' . Net::LibIDN::idn_to_ascii( $dom, 'utf-8' );
            }

            # this will act funny if there are @ symbols:
            return "Punycode: " . Net::LibIDN::idn_to_ascii( $s, 'utf-8' );
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub pu {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;

    @_ = _at_setup(
        'Net::LibIDN',
        sub {
            my ($s) = $_[0];
            utf8::encode($s) if utf8::is_utf8($s);

            # See Locale::Maketext::Utils::output_decode_puny()
            if ( $s =~ m/\@/ ) {
                my ( $nam, $dom ) = split( /@/, $s, 2 );

                # TODO: ? multiple @ signs ...
                # my ($dom,$nam) = split(/\@/,reverse($s),2);
                # $dom = reverse($dom);
                # $nam = reverse($nam);
                return Net::LibIDN::idn_to_unicode( $nam, 'utf-8' ) . '@' . Net::LibIDN::idn_to_unicode( $dom, 'utf-8' );
            }

            # this will act funny if there are @ symbols:
            return "From Punycode: " . Net::LibIDN::idn_to_unicode( $s, 'utf-8' );
        },
        @_
    );

    return @_ if $ret;
    goto &d;
}

sub se {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;
    return "TODO STRING ESCAPE!" if $ret;
    goto &d;
}

sub su {
    my $ret = $_[-1] eq '_Devel::Kit_return' ? 1 : 0;
    return "TODO From STRING UNESCAPE!" if $ret;
    goto &d;
}

sub _at_setup {
    return if @_ == 2;    # 'no args' instead of 'undef'

    if ( !defined $_[2] || $_[2] eq '' || ref $_[2] ) {
        @_ = $_[2];
    }
    elsif ( Module::Want::have_mod( $_[0] ) ) {
        @_ = $_[1]->( $_[2] );
    }
    else {
        @_ = "Error: “$_[0]” could not be loaded:\n\t$@\n";
    }

    return @_;
}

sub _trim_label {
    my ($s) = @_;
    $s =~ s/^[^:]+:\s*//;
    return $s;
}

sub _stat_struct {
    my @s = -l $_[0] ? lstat( $_[0] ) : stat( $_[0] );

    return {
        ' 0. dev'     => $s[0],
        ' 1. ino'     => $s[1],
        ' 2. mode'    => $s[2],
        ' 3. nlink'   => $s[3],
        ' 4. uid'     => $s[4],
        ' 5. gid'     => $s[5],
        ' 6. rdev'    => $s[6],
        ' 7. size'    => $s[7],
        ' 8. atime'   => $s[8],
        ' 9. mtime'   => $s[9],
        '10. ctime'   => $s[10],
        '11. blksize' => $s[11],
        '12. blocks'  => $s[12],
    };
}

# TODO: this will be done as aseperate module eventually, patches ... forthcoming

my %esc = ( "\n" => '\n', "\t" => '\t', "\r" => '\r', "\\" => '\\\\', "\a" => '\a', "\b" => '\b', "\f" => '\f' );

sub _escape_bytes_or_unicode {
    my ( $s, $no_quotemeta ) = @_;

    my $is_uni = utf8::is_utf8($s);    # otherwise you'll get \xae\x{301} instead of \x{ae}\x{301}

    $s =~ s{([^!#&()*+,\-.\/0123456789:;<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\]\^_`abcdefghijklmnopqrstuvwxyz{|}~ ])}
        {
            my $chr = "$1";
            my $n   = ord($chr);
            if ( exists $esc{$chr} ) { # more universal way ???
                $esc{$chr};
            }
            elsif ( $n < 32 || $n > 126 ) {
                sprintf( ( !$is_uni && $n < 255 ? '\x%02x' : '\x{%x}' ), $n );
            }
            elsif ($no_quotemeta) {
                $chr;
            }
            else {
                quotemeta($chr);
            }

        }ge;

    return $s;
}

sub _bytes_size {
    my ($string) = @_;
    utf8::encode($string) if utf8::is_utf8($string);    # is_utf8() is confusing, it really means “is this a Unicode string”, not “is this a utf-8 string)
    return CORE::length($string);
}

sub _char_count {
    my ($string) = @_;
    utf8::decode($string) if !utf8::is_utf8($string);    # is_utf8() is confusing, it really means “is this a Unicode string”, not “is this a utf-8 string)
    return CORE::length($string);
}

1;

__END__

=encoding utf-8

=head1 NAME

Devel::Kit - Handy toolbox of things to ease development/debugging.

=head1 VERSION

This document describes Devel::Kit version 0.1

=head1 SYNOPSIS

    use Devel::Kit; # strict and warnings are now enabled
    
    d($something); # d() and some other useful debug/dump functions are now availble!
    
    perl -e 'print @ARGV[0];' # no warning
    perl -e 'print $x;' # no strict error

    perl -MDevel::Kit -e 'print @ARGV[0];'# issues warnings: Scalar value @ARGV[0] better written as $ARGV[0] … 
    perl -MDevel::Kit -e 'print $x;' # Global symbol "$x" requires explicit package name …

    perl -MDevel::Kit -e 'd();d(undef);d("");d(1);d("i got here");d({a=>1},[1,2,3],"yo",\"howdy");ud("I \x{2665} perl");bd("I \xe2\x99\xa5 perl");gd("I ♥ perl");'

See where you are or are not getting to in a program and why, for example via thie pseudo patch:

    + d(1);
    + d($foo);
    
    bar();
    
    if ($foo) {
    +    d(2);
        …
    }
    else {
    +    d(3);
        …
    }
    + d(4);

If it outputs 1, $foo’s true value, 3,4 you know to also dump $foo after bar() since it acts like bar() is modifying $foo (action at a distance). If $foo is false after the call to bar() then you can add debug statements to bar() to see where specifically $foo is fiddled with.
     
Visually see if a string is a byte string or a Unicode string:

    perl -MDevel::Kit -e 'd(\$string);'

If it is a Unicode string the \x{} codepoint notation will be present, if it is a byte string it will not be present:

    [dmuey@multivac ~]$ perl -MDevel::Kit -e 'd(\"I \x{2665} perl");'
    debug() ref(SCALAR(0x100804fc0)) at -e line 1:
        \"I \x{2665} perl"
    [dmuey@multivac ~]$ perl -MDevel::Kit -e 'd(\"I ♥ perl");'
    debug() ref(SCALAR(0x100804fc0)) at -e line 1:
        \'I ♥ perl'
    [dmuey@multivac ~]$ perl -MDevel::Kit -e 'd(\"I \xe2\x99\xa5 perl");'
    debug() ref(SCALAR(0x100804fc0)) at -e line 1:
        \'I ♥ perl'
    [dmuey@multivac Devel-Kit]$ perl -Mutf8 -MDevel::Kit -e 'd(\"I ♥ perl");'
    debug() ref(SCALAR(0x100804ff0)) at -e line 1:
    	\"I \x{2665} perl"
    [dmuey@multivac Devel-Kit]$ 

=head1 DESCRIPTION

From one line data dumping sanity checks to debug print statements in a large body of code I often found myself reinventing these basic solutions.

Hence this module was born to help give a host of functions/functionality with a minimum of typing/effort required.

Any modules required for any functions are loaded if needed so no need to manage use statements!

=head1 (TERSE) INTERFACE

You'll probably note that every thing below is terse (i.e. not ideally named for maintenance).

That is on purpose since this module is meant for one-liners and development/debugging: NOT for production.

=head2 strict/warnings

import() enables strict and warnings in the caller unless you pass the string “ni” to import().

    use Devel::Kit; # as if you had use strict;use warnings; here
    use Devel::Kit qw(ni); # no strict/warnings

    perl -MDevel::Kit -e 'print @ARGV[0];print $x;' # triggers strict/warnings
    perl -MDevel::Kit=ni -e 'print @ARGV[0];print $x;' # no strict/warnings happen

=head2 imported functions

If you already have a function by these names you can pass "_" to import() whick will import them all w/ an underscore prepended. You can pass "__" to have it prepend 2, "---" to prepend 3, ad infinitum.

=head3 d() General debug/dump

Takes zero or more arguments to do debug info on.

The arguments can be a scalar or any perl reference you like.

It’s output is handled by L<Devel::Kit::o()> and references are stringified by L<Devel::Kit::p()>.

=head3 Data Format dumpers

If a function ends in “d” it is a dumper. Each takes one argument, the string in the format we’re dumping. 

Like d() it’s output is handled by L<Devel::Kit::o()> and references are stringified by L<Devel::Kit::p()>.

=head4 yd() YAML dumper

    perl -MDevel::Kit -e 'qd($your_yaml_here)' 

=head4 jd() JSON dumper

    perl -MDevel::Kit -e 'qd($your_json_here)' 

=head4 xd() XML dumper

    perl -MDevel::Kit -e 'qd($your_xml_here)' 

=head4 sd() Storable dumper

    perl -MDevel::Kit -e 'qd($your_storable_here)' 

=head4 id() INI dumper

    perl -MDevel::Kit -e 'qd($your_ini_here)' 

=head4 md() MessagePack dumper

    perl -MDevel::Kit -e 'qd($your_message_pack_here)' 

=head4 pd() Perl (stringified) dumper

    perl -MDevel::Kit -e 'qd($your_stringified_perl_structure_here)' 

=head3 File system

These dump information about the path given.

=head4 fd() File dumper

    perl -MDevel::Kit -e 'qd($your_file_here)' 

=head4 dd() Directory dumper

    perl -MDevel::Kit -e 'qd($your_fdirectory_here)' 

=head4 ld() Link dumper (i.e. symlinks)

    perl -MDevel::Kit -e 'qd($your_symlink_here)' 

=head3 String Representations

These can take a utf-8 or Unicode string and show the same string as the type being requested.

=head4 ud() Unicode string dumper

    perl -MDevel::Kit -e 'ud($your_string_here)' 

=head4 bd() Byte string utf-8 dumper

    perl -MDevel::Kit -e 'bd($your_string_here)' 

=head4 gd() Grapheme byte string utf-8 dumper

    perl -MDevel::Kit -e 'gd($your_string_here)' 

=head4 vd() Verbose Variations of string dumper

    perl -MDevel::Kit -e 'vd($your_string_here)' 

=head3 Serialize/Sum/haSh

Unicode strings are turned into utf-8 before summing (since you can’t sum a Unicode string)

=head4 ms() MD5

    perl -MDevel::Kit -e 'ms($your_string_here)' 

=head4 ss() SHA1

    perl -MDevel::Kit -e 'ss($your_string_here)' 

=head3 Escape/Unescape Encode/Unencode

Unicode strings are turned into utf-8 before for consistency and since some, if not all, need to operate on bytes.

=head4 be() bu() Base64

    perl -MDevel::Kit -e 'be($your_string_here)' 
    perl -MDevel::Kit -e 'bu($your_base64_here)' 

=head4 ue() uu() URI

    perl -MDevel::Kit -e 'be($your_string_here)' 
    perl -MDevel::Kit -e 'bu($your_uri_here)'

=head4 he() hu() HTML

    perl -MDevel::Kit -e 'he($your_string_here)' 
    perl -MDevel::Kit -e 'hu($your_html_here)'

=head4 pe() pu() Punycode string

    perl -MDevel::Kit -e 'pe($your_string_here)' 
    perl -MDevel::Kit -e 'pu($your_punycode_here)'

=head4 qe() qu() quoted-printable

    perl -MDevel::Kit -e 'pe($your_string_here)' 
    perl -MDevel::Kit -e 'pu($your_uoted_printable_here)'

=head4 se() su() String escaped for perl

This will be in v0.2 or so

=head2 non-imported functions

Feel free to override these with your own if you need different behavior.

=head3 Devel::Kit::o()

Outputs the first and only arg. 

Goes to STDOUT and gaurantees it ends in one newline.

=head3 Devel::Kit::p()

Returns a stringified version of any type of perl ref() contained in the first and only arg.

=head1 DIAGNOSTICS

Errors are output in the various dumps.

=head1 CONFIGURATION AND ENVIRONMENT

Devel::Kit requires no configuration files or environment variables.

=head1 DEPENDENCIES

L<Import::Into> for the strict/warnings.

L<Module::Want> to lazy load the various parsers and what not:

=head1 SUBCLASSES

It includes 2 sub classes that can be used as guides on how to create your own context specific subclass:

L<Devel::Kit::TAP> for testing context (function based).

L<Devel::Kit::cPanel> for cPanel context (method based).

=over 4

=item L<Data::Dumper>

=item L<File::Slurp>

=item L<YAML::Syck>

=item L<JSON::Syck>

=item L<XML::Parser>

=item L<Storable>

=item L<Data::MessagePack>

=item L<Digest::MD5>

=item L<Digest::SHA>

=item L<MIME::QuotedPrint>

=item L<HTML::Entities>

=item L<URI::Escape>

=item L<MIME::Base64>

=back

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-devel-kit@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 TODO

Namespace and variable dumpers via things like L<Class::Inspector>, L<Devel::Peek>, and L<Devel::Size>.

*d() functions could use corresponding d*() functions (e.g. dy() would dump as YAML …)

Stringified Data dumpers also take path or handle in addition to a string.

Use Regexp::Debugger (i.e. `rxrx` to be released @ 2012 OSCON) or some other Regexp dumper.

string parser/dumpers make apparent what it was (i.e. YAML, XML, etc)

Sub class tests (minor snafu on that and I wanted it out initially during YAPC::EU 2012) README has notes-to-self

=head1 AUTHOR

Daniel Muey  C<< <http://drmuey.com/cpan_contact.pl> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, Daniel Muey C<< <http://drmuey.com/cpan_contact.pl> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
