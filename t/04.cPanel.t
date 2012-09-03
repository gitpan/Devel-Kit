use Test::More;

use vars qw($orig_o);
use Devel::Kit;
BEGIN { $orig_o = \&Devel::Kit::o; };
BEGIN { eval "require Cpanel::Logger;";plan skip_all => "tests irrelevant on non-cPanel environment" if $@; };
use Devel::Kit::cPanel;

plan tests => 1;
isnt(\&Devel::Kit::o, $orig_o, 'Devel::Kit::o() is replaced');