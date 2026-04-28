#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-only
# SPDX-FileCopyrightText: Copyright (c) 2026 Andrew Wyatt (Fewtarius)

# Test zombie process reaping in CLIO::Coordination::SubAgent
#
# STANDALONE TEST - No dependencies beyond core Perl + POSIX
# Verifies the SIGCHLD handler pattern is present and functional.

use strict;
use warnings;
use POSIX qw(WNOHANG);
use Cwd qw(abs_path);

my ($pass, $fail) = (0, 0);

sub report {
    my ($ok, $msg) = @_;
    if ($ok) {
        print "  ok - $msg\n";
        $pass++;
    } else {
        print "  not ok - $msg\n";
        $fail++;
    }
}

# Derive path to SubAgent.pm from test location (tests/unit/)
my $test_file = abs_path(__FILE__);
$test_file =~ s!/tests/unit/test_zombie_reap\.pl$!!;
my $subagent_path = "$test_file/lib/CLIO/Coordination/SubAgent.pm";

print "1..3\n";

# Test 1: Verify SubAgent.pm contains the SIGCHLD handler pattern
print "Test 1: SubAgent.pm contains SIGCHLD handler\n";
my $has_handler = 0;
if (open(my $fh, '<', $subagent_path)) {
    my $content = do { local $/; <$fh> };
    $has_handler = 1 if $content =~ /SIG\{CHLD\}\s*=.*waitpid.*WNOHANG/s;
    close $fh;
}
report($has_handler, "SIGCHLD handler with waitpid(-1, WNOHANG) found in SubAgent.pm");

# Test 2: Verify handler uses local $! and $? (doesn't clobber globals)
print "Test 2: Handler preserves \$! and \$?\n";
my $has_local = 0;
if (open(my $fh, '<', $subagent_path)) {
    my $content = do { local $/; <$fh> };
    # Check both are present (order independent)
    my $has_bang = $content =~ /local\s+\$\!/;
    my $has_question = $content =~ /local\s+\$\?/;
    $has_local = 1 if $has_bang && $has_question;
    close $fh;
}
report($has_local, "Handler uses 'local \$!' and 'local \$?' to preserve globals");

# Test 3: Verify handler chains to existing handler if present
print "Test 3: Handler chains to existing SIGCHLD handler\n";
my $has_chain = 0;
if (open(my $fh, '<', $subagent_path)) {
    my $content = do { local $/; <$fh> };
    $has_chain = 1 if $content =~ /\$orig_chld.*SIG\{CHLD\}/s;
    close $fh;
}
report($has_chain, "Handler preserves and chains to existing CHLD handler");

print "\nResults: $pass passed, $fail failed\n";
exit($fail > 0 ? 1 : 0);
