package selfvars;
use 5.005;
use strict;
use vars qw( $VERSION $self @args %opts );

BEGIN {
    $VERSION = '0.11';
}

sub import {
    my $class = shift; # Oooh, the irony!
    my %vars  = (-self => undef, -args => undef, -opts => undef) unless @_;

    while (@_) {
        my $key = shift;
        if (@_ and $_[0] !~ /^-/) {
            $vars{$key} = shift;
        }
        else {
            $vars{$key} = undef;
        }
    }

    my $pkg = caller;

    no strict 'refs';
    if (exists $vars{'-self'}) {
        $vars{'-self'} = 'self' unless defined $vars{'-self'};
        *{"$pkg\::$vars{'-self'}"} = \$self;
    }
    if (exists $vars{'-args'}) {
        $vars{'-args'} = 'args' unless defined $vars{'-args'};
        *{"$pkg\::$vars{'-args'}"} = \@args;
    }
    if (exists $vars{'-opts'}) {
        $vars{'-opts'} = 'opts' unless defined $vars{'-opts'};
        *{"$pkg\::$vars{'-opts'}"} = \%opts;
    }
}

package selfvars::self;

sub TIESCALAR {
    my $x;
    bless \$x => $_[0];
}

sub FETCH {
    my $level = 1;
    my @c     = ();
    while ( !defined( $c[3] ) || $c[3] eq '(eval)' ) {
        @c = do {
            package DB;
            @DB::args = ();
            caller($level);
        };
        $level++;
    }
    $DB::args[0];
}

sub STORE {
    require Carp;
    Carp::croak('Modification of a read-only $self attempted');
}

package selfvars::args;
use Tie::Array ();
use vars qw(@ISA);
BEGIN { @ISA = 'Tie::Array' }

sub _args {
    my $level = 2;
    my @c;
    while ( !defined( $c[3] ) || $c[3] eq '(eval)' ) {
        @c = do {
            package DB;
            @DB::args = ();
            caller($level);
        };
        $level++;
    }
    \@DB::args;
}

sub TIEARRAY  { my $x; bless \$x => $_[0] }
sub FETCHSIZE { scalar $#{ _args() } }
sub STORESIZE {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # $#{ _args() } = $_[1] + 1;
}
sub STORE     { _args()->[ $_[1] + 1 ] = $_[2] }
sub FETCH     { _args()->[ $_[1] + 1 ] }
sub CLEAR     {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # $#{ _args() } = 0;
}
sub POP       {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $o = _args(); (@$o > 1) ? pop(@$o) : undef
}
sub PUSH      {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $o = _args(); push( @$o, @_ )
}
sub SHIFT     {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $o = _args(); splice( @$o, 1, 1 )
}
sub UNSHIFT   {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $o = _args(); unshift( @$o, @_ )
}

BEGIN {
    local $@;
    eval q{
        sub EXISTS    {
            my $o = _args(); exists $o->[ $_[1] + 1 ]
        }
    } if $] >= 5.006;
}

sub DELETE    {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $o = _args(); delete $o->[ $_[1] + 1 ]
}

sub SPLICE {
    require Carp;
    Carp::croak('Modification of a read-only @args attempted');
    # my $ob  = shift;
    # my $sz  = $ob->FETCHSIZE;
    # my $off = @_ ? shift : 0;
    # $off += $sz if $off < 0;
    # my $len = @_ ? shift : $sz - $off;
    # splice( @$ob, $off + 1, $len, @_ );
}

package selfvars::opts;

sub _opts {
    my $level = 2;
    my @c;
    while ( !defined( $c[3] ) || $c[3] eq '(eval)' ) {
        @c = do {
            package DB;
            @DB::args = ();
            caller($level);
        };
        $level++;
    }
    $DB::args[1];
}

sub TIEHASH  { my $x; bless \$x => $_[0] }
sub FETCH    { _opts()->{ $_[1] } }
sub STORE    { _opts()->{ $_[1] } = $_[2] }
sub FIRSTKEY { my $o = _opts(); my $a = scalar keys %$o; each %$o }
sub NEXTKEY  { my $o = _opts(); each %$o }
sub EXISTS   { my $o = _opts(); exists $o->{$_[1]} }
sub DELETE   { my $o = _opts(); delete $o->{$_[1]} }
sub CLEAR    { my $o = _opts(); %$o = () }
sub SCALAR   { my $o = _opts(); scalar %$o }

package selfvars;

BEGIN {
    tie $self => __PACKAGE__ . '::self';
    tie @args => __PACKAGE__ . '::args';
    tie %opts => __PACKAGE__ . '::opts';
}

1;

__END__

=head1 NAME

selfvars - Provide $self, @args and %opts variables for OO programs

=head1 SYNOPSIS

    package MyClass;

    ### Import $self, @args and %opts into your package:
    use selfvars;

    ### Or name the variables explicitly:
    # use selfvars -self => 'self', -args => 'args', -opts => 'opts';

    ### Write the constructor as usual:
    sub new {
        return bless({}, shift);
    }

    ### Use $self in place of $_[0]:
    sub foo {
        $self->{foo};
    }

    ### Use @args in place of @_[1..$#_]:
    sub bar {
        my ($foo, $bar) = @args;
        $self->{foo} = $foo;
        $self->{bar} = $bar;
    }

    ### Use %opts in place of %{$_[1]}:
    sub baz {
        $self->{x} = $opts{x};
        $self->{y} = $opts{y};
    }

=head1 DESCRIPTION

This moudles exports three special variables: C<$self>, C<@args> and C<%opts>.

They are really just handy helpers to get rid of:

    my $self = shift;

Behind the scenes, C<$self> is simply tied to C<$_[0]>, C<@args> to
C<@_[1..$#_]>, and C<%opts> to C<%{$_[1]}>.

Currently, both C<$self> and C<@args> are read-only; this means you cannot
mutate them:

    $self = 'foo';              # error
    my $foo = shift @args;      # error

This restriction may be lifted at a later version of this module, or turned
into a configurable option instead.

However, C<%opts> is not read-only, and can be mutated freely:

    $opts{x} = 'y';             # okay
    delete $opts{x};            # also okay

=head1 INTERFACE

=over 4

=item $self

Returns the current object.

=item @args

Returns the argument list.

=item %opts

Returns the first argument, which must be a hash reference, as a hash.

=back

=head2 Choosing non-default names 

You can choose alternative variable names with explicit import arguments:

    # Use $this and @vars instead of $self and @args, leaving %opts alone:
    use selfvars -self => 'this', -args => 'vars', -opts;

    # Use $this but leave @args and %opts alone:
    use selfvars -self => 'this', -args, -opts;

    # Use @vars but leave $self and %opts alone:
    use selfvars -args => 'vars', -self, -opts;

You may also omit a variable name from the explicit import arguments:

    # Import $self but not @args nor %opts:
    use selfvars -self => 'self';

    # Same as the above:
    use selfvars -self;

    # Import $self and %opts but not @args:
    use selfvars -self, -opts;

=head1 DEPENDENCIES

None.

=head1 ACKNOWLEDGEMENTS 

This module was inspired and based on Kang-min Liu (gugod)'s C<self.pm>.

As seen on #perl:

    <gugod> audreyt: selfvars.pm looks exactly like what I want self.pm to be in the beginning
    <gugod> audreyt: but I can't sort out the last BEGIN{} block like you did.
    <gugod> audreyt: that's a great job :D

=head1 SEE ALSO

L<self>

=head1 AUTHORS

唐鳳 E<lt>cpan@audreyt.orgE<gt>

=head1 CC0 1.0 Universal

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to selfvars.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=cut
