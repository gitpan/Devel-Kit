use Test::More;

use Devel::Kit;
use File::Temp  ();
use File::Slurp ();

use MIME::Base64 ();

diag("Testing Devel::Kit $Devel::Kit::VERSION");

my @data_formats = (
    [ 'yd', "--- \na: 1",                                        ": 1",             'YAML::Syck' ],
    [ 'jd', '{ "a" : "1" }',                                     ": 1",             'JSON::Syck' ],
    [ 'xd', q{<foo bar="baz"></foo>},                            "<foo>bar<foo>",   'XML::Parser' ],
    [ 'sd', MIME::Base64::decode_base64('BQcDAAAAAQiBAAAAAWE='), 'not storable',    'Storable' ],
    [ 'id', qq{a = 1\n\n[s2]\nb = 2\n\n[s3]\na = 1\n},           "not ini",         'Config::INI::Reader' ],
    [ 'md', MIME::Base64::decode_base64('gaFhAQ=='),             'not messagepack', 'Data::MessagePack' ],
    [ 'pd', '{ a => 1 }',                                        'not Data::Dump',  undef() ],
    [
        'pd', q($VAR1 = {
              'a' => 1
            };), 'not Data::Dumper', undef()
    ],
);

my $tmp_dir = File::Temp->newdir()->dirname();
mkdir $tmp_dir || die "Could not make directory “$tmp_dir”: $!";
my $tmp_file = File::Temp->new( 'DIR' => $tmp_dir )->filename();
File::Slurp::write_file( $tmp_file, "howdy" ) || die "Could not write “$tmp_file”: $!";
my $tmp_none = File::Temp->new( 'DIR' => $tmp_dir )->filename();

my $tmp_symfile = File::Temp->new( 'DIR' => $tmp_dir )->filename();
my $tmp_symdir  = File::Temp->new( 'DIR' => $tmp_dir )->filename();
my $tmp_broken  = File::Temp->new( 'DIR' => $tmp_dir )->filename();

my $symlinks_supported = eval { symlink( '', '' ); 1 };
if ($symlinks_supported) {
    symlink( $tmp_file, $tmp_symfile ) || die "Could not create symlink “$tmp_symfile” ($tmp_file): $!";
    symlink( $tmp_dir,  $tmp_symdir )  || die "Could not create symlink “$tmp_symdir” ($tmp_dir): $!";
    symlink( $tmp_none, $tmp_broken )  || die "Could not create symlink “$tmp_broken” ($tmp_none): $!";
}

my @filesys = (
    [
        'fd',
        qr{\'File “\Q$tmp_file\E”:\' \=\> \{.* 0\. dev.*\n.* 1\. ino.*\n.* 2\. mode.*\n.* 3\. nlink.*\n.* 4\. uid.*\n.* 5\. gid.*\n.* 6\. rdev.*\n.* 7\. size.*\n.* 8\. atime.*\n.* 9\. mtime.*\n.*10\. ctime.*\n.*11\. blksize.*\n.*12\. blocks.*\n.*13\. contents}s,    # -e file
        qr/debug\(\): “\Q$tmp_dir\E” is not a file\./,                                                                                                                                                                                                                    # -e dir
        qr/debug\(\): “\Q$tmp_none\E” does not exist\./,                                                                                                                                                                                                                  # !-e file|dir
        qr/debug\(\): “\Q$tmp_symfile\E” is not a file\./,                                                                                                                                                                                                                # -l target exists file
        qr/debug\(\): “\Q$tmp_symdir\E” is not a file\./,                                                                                                                                                                                                                 # -l target exists dir
        qr/debug\(\): “\Q$tmp_broken\E” is not a file\./,                                                                                                                                                                                                                 # -l target !exists
    ],
    [
        'dd',
        qr/debug\(\): “\Q$tmp_file\E” is not a directory\./,                                                                                                                                                                                                                  # -e file
        qr{\'Directory “\Q$tmp_dir\E”:\' \=\> \{.* 0\. dev.*\n.* 1\. ino.*\n.* 2\. mode.*\n.* 3\. nlink.*\n.* 4\. uid.*\n.* 5\. gid.*\n.* 6\. rdev.*\n.* 7\. size.*\n.* 8\. atime.*\n.* 9\. mtime.*\n.*10\. ctime.*\n.*11\. blksize.*\n.*12\. blocks.*\n.*13\. contents}s,    # -e dir
        qr/debug\(\): “\Q$tmp_none\E” does not exist\./,                                                                                                                                                                                                                      # !-e file|dir
        qr/debug\(\): “\Q$tmp_symfile\E” is not a directory\./,                                                                                                                                                                                                               # -l target exists file
        qr/debug\(\): “\Q$tmp_symdir\E” is not a directory\./,                                                                                                                                                                                                                # -l target exists dir
        qr/debug\(\): “\Q$tmp_broken\E” is not a directory\./,                                                                                                                                                                                                                # -l target !exists
    ],
    [
        'ld',
        qr/debug\(\): “\Q$tmp_file\E” is not a symlink\./,                                                                                                                                                                                                                                               # -e file
        qr/debug\(\): “\Q$tmp_dir\E” is not a symlink\./,                                                                                                                                                                                                                                                # -e dir
        qr/debug\(\): “\Q$tmp_none\E” does not exist\./,                                                                                                                                                                                                                                                 # !-e file|dir
        qr{\'Symlink “\Q$tmp_symfile\E”:\' \=\> \{.* 0\. dev.*\n.* 1\. ino.*\n.* 2\. mode.*\n.* 3\. nlink.*\n.* 4\. uid.*\n.* 5\. gid.*\n.* 6\. rdev.*\n.* 7\. size.*\n.* 8\. atime.*\n.* 9\. mtime.*\n.*10\. ctime.*\n.*11\. blksize.*\n.*12\. blocks.*\n.*13\. target.*\n.*14\. broken.*\=\>\s*0}s,    # -l target exists file
        qr{\'Symlink “\Q$tmp_symdir\E”:\' \=\> \{.* 0\. dev.*\n.* 1\. ino.*\n.* 2\. mode.*\n.* 3\. nlink.*\n.* 4\. uid.*\n.* 5\. gid.*\n.* 6\. rdev.*\n.* 7\. size.*\n.* 8\. atime.*\n.* 9\. mtime.*\n.*10\. ctime.*\n.*11\. blksize.*\n.*12\. blocks.*\n.*13\. target.*\n.*14\. broken.*\=\>\s*0}s,     # -l target exists dir
        qr{\'Symlink “\Q$tmp_broken\E”:\' \=\> \{.* 0\. dev.*\n.* 1\. ino.*\n.* 2\. mode.*\n.* 3\. nlink.*\n.* 4\. uid.*\n.* 5\. gid.*\n.* 6\. rdev.*\n.* 7\. size.*\n.* 8\. atime.*\n.* 9\. mtime.*\n.*10\. ctime.*\n.*11\. blksize.*\n.*12\. blocks.*\n.*13\. target.*\n.*14\. broken.*\=\>\s*1}s,     # -l target !exists
    ]
);

my @strings = (
    [ 'ud', 'debug(): Unicode: I \x{2665} perl' . "\n" ],
    [ 'gd', 'debug(): Bytes grapheme: I \xe2\x99\xa5 perl' . "\n" ],
    [ 'bd', 'debug(): Bytes: I ♥ perl' . "\n" ],
    [
        'vd', qr{^debug\(\): I ♥ perl\n\s*Original string type: Byte\n}s,
        qr{^debug\(\): I ♥ perl\n\s*Original string type: Unicode\n}s
    ],
);

my @sum_hash = (
    [ 'ms', 'I ♥ perl', "debug(): MD5 Sum: 040ab5366f264eb28f4e310a994fde15\n" ],
    [ 'ss', 'I ♥ perl', "debug(): SHA1 Hash: d95af59dffb410853e85b28d6025d2825b257c42\n" ],
);

my @encode_unencode_escape_unescape = (
    [ 'be', "be",                                      "debug(): Base 64: YmU=\n" ],
    [ 'bu', "YmU=",                                    "debug(): From Base 64: be\n" ],
    [ 'ue', "I ♥ perl",                              "debug(): URI: I%20%E2%99%A5%20perl\n" ],
    [ 'uu', "I%20%E2%99%A5%20perl",                    "debug(): From URI: I ♥ perl\n" ],
    [ 'he', qq{<I ♥ perl's " & >},                   "debug(): HTML Safe: &lt;I ♥ perl&#39;s &quot; &amp; &gt;\n" ],
    [ 'hu', "&lt;I ♥ perl&apos;s &quot; &amp; &gt;", qq{debug(): From HTML Safe: <I ♥ perl's " & >\n} ],
    [ 'qe', "I ♥ perl",                              "debug(): Quoted-Printable: I =E2=99=A5 perl=\n" ],
    [ 'qu', "I =E2=99=A5 perl=",                       "debug(): From Quoted-Printable: I ♥ perl=\n" ],
    [ 'pe', "I ♥ perl",                              "debug(): Punycode: xn--i  perl-pm7d\n" ],
    [ 'pu', "xn--i  perl-pm7d",                        "debug(): From Punycode: i ♥ perl\n" ],
    [ 'se', "TODO STRING ESCAPE!",                     "debug(): TODO STRING ESCAPE!\n" ],
    [ 'su', "TODO From STRING UNESCAPE!",              "debug(): TODO From STRING UNESCAPE!\n" ],
);

plan tests => 16 + ( 3 * @data_formats ) + @sum_hash + ( 6 * @strings ) + ( 6 * @filesys ) + @encode_unencode_escape_unescape;

my $out;
{
    open( my $fh, '>', \$out ) || die "Could not created handle to variable: $!";
    local $Devel::Kit::fh = $fh;

    sub _call_o {
        seek( $fh, 0, 0 );
        $out = '';
        goto &Devel::Kit::o;
    }

    # Internal:
    #  Devel::Kit::o()
    _call_o("test");
    is( $out, "test\n", "o() newline added" );

    _call_o("howdy\n\n\n\n");
    is( $out, "howdy\n", "o() multiple newlines chomped" );

    close $fh;

    no warnings 'redefine';
    *Devel::Kit::o = sub {
        my ($str) = @_;
        $str =~ s{[\n\r]+$}{};
        $out .= "$str\n";
    };
}

#  Devel::Kit::p()
is( Devel::Kit::p('nonref'),  'non-ref passed to p(): nonref', 'p() non ref' );
is( Devel::Kit::p(),          'no args passed to p()',         'p() non ref - no args' );
is( Devel::Kit::p( undef() ), 'undef() passed to p()',         'p() non ref - undef' );
is( Devel::Kit::p(''),        'empty string passed to p()',    'p() non ref - empty' );

is( Devel::Kit::p( \"foo bar" ), qq{\t\\'foo bar'\n}, 'p() scalar ref' );
is( Devel::Kit::p( { a => 1 } ), "\t{\n\t  'a' => 1\n\t}\n", 'p() hash ref' );
is( Devel::Kit::p( [ 1, 2, 3 ] ), "\t[\n\t  1,\n\t  2,\n\t  3\n\t]\n", 'p() array ref' );

like( Devel::Kit::p(qr/foo bar/i), qr/\s*Regexp:\s*\/\(?\S+:foo bar\)\//, 'p() regex ref' );
is( Devel::Kit::p( sub { "test test" } ), "\tsub { \"DUMMY\" }\n", 'p() code ref' );

# Main:
#  d()
$out = '';
d();
like( $out, qr{debug\(\) w/ no args at}, 'd() no args' );

$out = '';
d( undef() );
like( $out, qr{debug\(\) undef at}, 'd() undef' );

$out = '';
d('');
like( $out, qr{debug\(\) empty at}, 'd() empty string' );

$out = '';
d('string');
is( $out, "debug(): string\n", 'd() simple' );

$out = '';
d( 'string a', 'string b' );
is( $out, "debug(0): string a\ndebug(1): string b\n", 'd() simple multiple' );

no strict 'refs';

for my $f (@data_formats) {
    $out = '';
    $f->[0]( $f->[1] );
    like( $out, qr/^debug\(\) ref\((?:[^)]+)\([^)]+\)\) at .* line [0-9]+\:\n/, "$f->[0]() arg is valid syntax" );

    $out = '';
    $f->[0]( $f->[2] );
    like( $out, qr/^debug\(\)\: Error\: Invalid .* \(/, "$f->[0]() arg is invalid syntax" );

    if ( $f->[3] ) {
        no warnings 'redefine';
        local *Module::Want::have_mod = sub { $@ = "Mock INC error here"; return; };
        $out = '';
        $f->[0]( $f->[1] );
        like( $out, qr/^debug\(\): Error: “$f->[3]” could not be loaded\:\n\tMock INC error here\n/, "$f->[0]() required module missing" );
    }
    else {
        ok( 1, "$f->[0]() no required module" );
    }
}

for my $fs (@filesys) {
    $out = '';
    $fs->[0]($tmp_file);
    like( $out, $fs->[1], "$fs->[0]() file exists" );

    $out = '';
    $fs->[0]($tmp_dir);
    like( $out, $fs->[2], "$fs->[0]() dir exists" );

    $out = '';
    $fs->[0]($tmp_none);
    like( $out, $fs->[3], "$fs->[0]() does not exist" );

  SKIP: {
        skip "", 3 unless $symlinks_supported;
        $out = '';
        $fs->[0]($tmp_symfile);
        like( $out, $fs->[4], "$fs->[0]() symlink w/ existing file target" );

        $out = '';
        $fs->[0]($tmp_symdir);
        like( $out, $fs->[5], "$fs->[0]() symlink w/ existing dir target" );

        $out = '';
        $fs->[0]($tmp_broken);
        like( $out, $fs->[6], "$fs->[0]() symlink w/ broken target" );
    }
}

for my $r (@strings) {

    my $func = 'is';
    my $uidx = 1;
    if ( ref( $r->[1] ) eq 'Regexp' ) {
        $func = 'like';
        $uidx = 2;
    }

    my $bytes = "I ♥ perl";
    $out = '';
    $r->[0]($bytes);
    $func->( $out, $r->[1], "$r->[0](bytes string) as expected" );
    ok( !utf8::is_utf8($bytes), "$r->[0]() has no observer effect on string type (bytes)" );

    my $unicode = $bytes;
    utf8::decode($unicode);

    $out = '';
    $r->[0]($unicode);
    $func->( $out, $r->[$uidx], "$r->[0](explicit unicode string) as expected" );
    ok( utf8::is_utf8($unicode), "$r->[0]() has no observer effect on string type (explicit unicode)" );

    {
        use utf8;
        my $unicode = "I ♥ perl";
        $out = '';
        $r->[0]($unicode);
        $func->( $out, $r->[$uidx], "$r->[0](implicit unicode string) as expected" );
        ok( utf8::is_utf8($unicode), "$r->[0]() has no observer effect on string type (implicit unicode)" );
    }
}

for my $s (@sum_hash) {
    $out = '';
    $s->[0]( $s->[1] );
    is( $out, $s->[2], "$s->[0]() sums OK" );
}

for my $u (@encode_unencode_escape_unescape) {
    $out = '';
    $u->[0]( $u->[1] );

    if ( $out =~ m/Can\'t locate \S*\.pm in \@INC/ ) {
        like( $out, qr/Can\'t locate \S*\.pm in \@INC/, "$u->[0]() is correct when module is missing" );
    }
    else {
        is( $out, $u->[2], "$u->[0]() is correct" );
    }
}
