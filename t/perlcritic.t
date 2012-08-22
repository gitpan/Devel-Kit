#!perl -T

use Test::More;
eval 'use Test::Perl::Critic';
plan skip_all => 'Test::Perl::Critic required for testing PBP compliance' if $@;
plan skip_all => 'Critic tests are only run in RELEASE_TESTING mode.' unless $ENV{'RELEASE_TESTING'};
Test::Perl::Critic::all_critic_ok();
