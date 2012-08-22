use Test::More;

my @exported = qw(d yd jd xd sd md id pd fd dd ld ud gd bd vd ms ss be bu ue uu he hu pe pu se su qe qu);
plan tests => ( scalar(@exported) * 1 ) + 2;

# do these no()'s to ensure they are off before testing Devel::Kit’s behavior regarding them
no strict;      ## no critic
no warnings;    ## no critic
use Devel::Kit;

diag("Testing Devel::Kit $Devel::Kit::VERSION");

eval 'print $x;';
like( $@, qr/Global symbol "\$x" requires explicit package name/, 'strict enabled' );

{
    my $warn = '';
    local $SIG{__WARN__} = sub {
        $warn = join( '', @_ );
    };
    eval 'print @X[0]';
    like( $warn, qr/Scalar value \@x\[0\] better written as \$x\[0\]/i, 'warnings enabled' );
}

for my $f (@exported) {
    ok( defined &{$f}, "$f imported" );
}