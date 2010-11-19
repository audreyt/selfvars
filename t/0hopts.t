
use lib 't/lib';
use HOpts;
use Test::More tests => 1;

{
    my $o = HOpts->new;
    is($o->hopts( param => 2 ), '0 2');
}

