use strict;
use warnings;

use Test::Some qw/ test_me /, qr/^foo/, ':tag1', ':/uu'; 
use Test::More tests => 6;


sub _passing { plan tests => 1; pass }
sub _failing { plan tests => 1; fail }

subtest 'test_me'     => \&_passing;
subtest 'skip_me'     => \&_failing;
subtest 'test_me_too' => \&_passing, 'tag1';
subtest 'test_me 3'   => \&_passing, 'tag2', 'tag1';
subtest 'foobar'      => \&_passing;
subtest 'regexed tag' => \&_passing, 'quux';


