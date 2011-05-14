#!/usr/bin/perl -w

use strict;
use constant PORT   => 21376;
use IO::Socket;

my $lockFile = "/tmp/.osarunner.pid";
my $arg = shift;
if (defined($arg) && ($arg eq '-v')) {
    removeLockFile($lockFile);
    runDaemon();
    exit;
}

if (processRunning($lockFile)) {
    # already running
    exit;
} else {
    # not running, start daemon
    my $pid = fork();
    if ($pid == 0) {
        # child
        runDaemon();
        removeLockFile($lockFile);
    } else {
        # parent
        createLockFile($lockFile, $pid);
    }
}

exit;

sub runDaemon {
    my $socket = new IO::Socket::INET(
        'LocalPort'     => PORT,
        'Proto'         => 'tcp',
        'Listen'        => 1,
        'Reuse'         => 1,
    );
    die "Unable to create socket: $!\n" if (! $socket);
    while (my $connSock = $socket->accept()) {
        my @data = <$connSock>;
        my $script = join('', @data);
        # try to compile for syntax check
        local *PIPE;
        unlink("/tmp/a.scpt");
        open(PIPE, "| osacompile -o /tmp/a.scpt");
        print PIPE $script;
        close(PIPE);
        if (-e "/tmp/a.scpt") {
            # compiled okay, let's run it
            unlink("/tmp/a.scpt");
            open(PIPE, "| osascript");
            print PIPE $script;
            close(PIPE);
        } else {
            # script could not be compiled, ignore
        }
        close($connSock);
    }
    close($socket);
}

sub removeLockFile {
    my $lockFile = shift;
    unlink($lockFile);
}

sub createLockFile {
    my $lockFile = shift;
    my $pid = shift;
    local *OUT;
    open(OUT, ">$lockFile");
    print OUT $pid, "\n";
    close(OUT);
}

sub processRunning {
    my $lockFile = shift;
    local *IN;
    if (-f $lockFile) {
        open(IN, "<$lockFile");
        my $pid = <IN>;
        chomp($pid);
        close(IN);
        open(IN, "ps -p $pid |");
        my @lines = <IN>;
        close(IN);
        my $psData = join('', @lines);
        return ($psData =~ /\b${pid}\b/);
    } else {
        return 0;
    }
}
