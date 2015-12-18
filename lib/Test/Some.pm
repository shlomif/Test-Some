package Test::Some;
# ABSTRACT: test a subset of tests

=head1 SYNOPSIS

    use Test::More;

    use Test::Some 'foo';

    plant tests => 3;

    subtest foo => sub { pass };

    # will be skipped
    subtest bar => sub { fail };

=head1 DESCRIPTION

This module allows to run a subset of the 'subtest' tests given in a test file.

The module declaration takes a whitelist of the subtests we want to run. 
Any subtest that doesn't match any of the whitelist
items will be skipped (or potentially bypassed).

The test files don't even need to be modified, as t
he module can also be invoked from the command-line. E.g.,

    perl -MTest::Some=foo t/tests.t

=head2 Whitelist items

=head3 '~'

Tells Test::Some to bypass the non-whitelisted tests instead of skipping them. That makes for a smaller output, but
the test file would now fail if it has a C<plan tests => $n> line (as we'll only report on C<$n - bypassed> tests). 

=head3 Subtest name

At its most simple, the names of the subtests we want to run can be passed.

    # run subtests 'foo' and 'bar'
    use Test::Some 'foo', 'bar';

=head3 Negation

An item prefixed with a bang (!) is negated.

    use Test::Some '!foo';  # run all tests but 'foo'

Note that a subtest is run if it matches any item in the whitelist, so

    use Test::Some '!foo', '!bar';

will run all tests as `foo` is not `bar` and vice versa.

=head3 Regular expression

A string beginning with a slash (/), or a regular expression object 
will be considered to be a regular expression to be compared against the
subtest name

    use Test::Some '/foo';  # only tests with 'foo' in their name

    # equivalent to 
    use Test::Some qr/foo/;

=head3 Tags

Strings prefixed with a colon (:) are considered to be tags. 

    # run all tests with the 'basic' tag
    use Test::Some ':basic';

Tags can be assigned to a subtest by putting them
after the coderef. E.g.,

    subtest foo, sub { 
        ...     
    }, 'tag1', 'tag2';

Test::More's subtest ignore those trailing arguments, so they be put there without
breaking backward compatibility.


=head3 Code

A coderef can be passed. It'll have the subtest name and its tags passed in as 
`$_` and `%_`, respectively.

    # run tests with tags 'important' *and* 'auth'
    use Test::Some sub { 
        $_{important} and $_{auth} 
    };

=cut

use 5.10.0;

use strict;
use warnings;

use Test::More;

use List::MoreUtils qw/ none any /;

our %filters;

our $BYPASS = 0;

sub import {
    my $caller = caller;
    my(undef,@filters) = @_;

    _groom_filter($caller,$_) for @filters;

    eval <<"END_EVAL";
        package $caller; 
        use Test::More;
        use Class::Method::Modifiers;

        # needs to be after Test::More put
        # its own 'subtest' in there,
        # hence the INIT
        INIT {
            around subtest => sub {
                Test::Some::_subtest(\@_);
            }
        }
END_EVAL

    die $@ if $@;

}

sub _groom_filter { 
    my( $caller, $filter, $is_tag, $is_negated ) = @_;

    if( $filter eq '~' ) {
        $BYPASS = 1;
        return;
    }

    return _groom_filter( $caller, $filter, 1, $is_negated )
        if $filter =~ s/^://;

    return _groom_filter( $caller, $filter, $is_tag, 1 )
        if $filter =~ s/^!//;

    return _groom_filter( $caller, qr/$filter/, $is_tag, $is_negated )
        if $filter =~ s#^/##;

    my $sub = ref $filter eq 'CODE' ? $filter 
            : $is_tag               ? sub { 
                    if ( ref $filter ) {
                        for my $key ( keys %_ ) {
                            return 1 if $key =~ $filter;
                        }
                        return 0;
                    }

                    return $_{$filter};
                }
            :   sub { ref $filter ? /$filter/ : $_ eq $filter };

    if( $is_negated ) {
        my $prev_sub = $sub;
        $sub = sub { not $prev_sub->() };
    }

    push @{ $filters{$caller} }, $sub;
}

sub _should_be_skipped {
    my( $caller, $name, @tags ) = @_;

    for my $filter ( eval { @{ $filters{$caller}  } } ) {
        local $_ = $name;
        local %_ = map { $_ => 1 } @tags;
        return if $filter->();
    }

    return 1;
}

sub _subtest {
    my( $orig, $name, $code, @tags ) = @_;
    my $caller = caller 3;

    if( _should_be_skipped($caller,$name,@tags) ) {
        return if $BYPASS;
        $code = sub { 
            Test::More::plan( skip_all => 'Test::Some skipping' ); 
            $orig->($name, sub { } ) 
        }
    }

    $orig->( $name, $code );
}

1;

__END__

=head1 SEE ALSO

* L<http://techblog.babyl.ca/entry/test-some> - introduction blog entry
