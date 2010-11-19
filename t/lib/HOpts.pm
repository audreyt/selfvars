use strict;

package HOpts;
use selfvars -self => 'this', -args => 'vars', -opts => 'vars', -hopts => 'args';

sub new {
    my $class = shift;
    return bless { v => 0 }, $class;
}

sub hopts {
	return join ' ', $this->{v}, $args{'param'};
}

1;
