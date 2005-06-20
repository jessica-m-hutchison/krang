package Krang::Script;
use Krang::ClassFactory qw(pkg);
use strict;
use warnings;

=head1 NAME

Krang::Script - loader for the Krang scripts

=head1 SYNOPSIS
 
  use Krang::ClassLoader 'Script';

=head1 DESCRIPTION

This module exists to load and configure the Krang system for
command-line scripts.

The first thing the module does is attempt to become the configured
KrangUser and KrangGroup.  If you're not already KrangUser then you'll
need to be root in order to change into KrangUser.

Next the module sets REMOTE_USER to the user ID of the special hidden
'system' user.  This user has global admin access to all Krang
instances.

This module will exit with an error if your F<krang.conf> has multiple
instances but you didn't set the KRANG_INSTANCE environment variable.

If you set KRANG_PROFILE to 1 then L<Krang::Profiler> will be used.

=head1 INTERFACE

None.

=cut

# activate profiling if requested
BEGIN {
    eval "require " . pkg('Profiler') if $ENV{KRANG_PROFILE};
}

use Krang::ClassLoader 'lib';
use Krang::ClassLoader 'ErrorHandler';
use Krang::ClassLoader Conf => qw(KrangUser KrangGroup KrangRoot);
use Krang::ClassLoader Log => qw(debug critical);
# use Krang::Session qw(%session);
use Carp qw(croak);
use Krang::ClassLoader 'User';
use Krang::ClassLoader 'AddOn';

# trigger init handler now
BEGIN { pkg('AddOn')->call_handler('InitHandler') }

BEGIN {
    # make sure we are KrangUser/KrangGroup

    # get current uid/gid
    my $uid = $>;
    my %gid = map { ($_ => 1) } split( ' ', $) );

    # extract desired uid/gid
    my @uid_data = getpwnam(KrangUser);
    warn("Unable to find user for KrangUser '" . KrangUser . "'."), exit(1)
      unless @uid_data;
    my $krang_uid = $uid_data[2];
    my @gid_data = getgrnam(KrangGroup);
    warn("Unable to find user for KrangGroup '" . KrangGroup . "'."), exit(1)
      unless @gid_data;
    my $krang_gid = $gid_data[2];

    # become KrangUser/KrangGroup if necessary
    if ($gid{$krang_gid}) {
        eval { $) = $krang_gid; };
        warn("Unable to become KrangGroup '" . KrangGroup . "' : $@\n" . 
            "Maybe you need to start this process as root.\n") and exit(1)
          if $@;
        warn("Failed to become KrangGroup '" . KrangGroup . "' : $!.\n" .
            "Maybe you need to start this process as root.\n") and exit(1)
          unless $) == $krang_gid;
    }

    if ($uid != $krang_uid) {
        eval { $> = $krang_uid; };
        warn("Unable to become KrangUser '" . KrangUser . "' : $@\n" .
            "Maybe you need to start this process as root.\n") and exit(1)
          if $@;
        warn("Failed to become KrangUser '" . KrangUser . "' : $!\n" .
             "Maybe you need to start this process as root.\n") and exit(1)
          unless $> == $krang_uid;
    }
}

BEGIN {
    # Set Krang instance if not running under mod_perl
    my $instance = $ENV{KRANG_INSTANCE};
    if (not defined $instance) {
        my @instances = pkg('Conf')->instances();
        if (@instances > 1) {
            warn "\nYour Krang configuration contains multiple instances, please set the\nKRANG_INSTANCE environment variable.\n\nAvailable instances are: " . 
              join(', ', @instances[0 .. $#instances - 1]) . 
                " and $instances[-1].\n\n";
            exit(1);
        } else {
            $instance = $instances[0];
        }
    }
    debug("Krang.pm:  Setting instance to '$instance'");    
    pkg('Conf')->instance($instance);
  
    # set REMOTE_USER to the user_id for the 'system' user
    unless ($ENV{REMOTE_USER}) {
        my @user = (pkg('User')->find(ids_only => 1,
                                      login    => 'system'));
        if (@user) {
            $ENV{REMOTE_USER} = $user[0];
        } else {
            warn("Unable to find 'system' user.  All Krang instances must contain the special 'system' account.  Falling back to using special user_id 1.\n");
            $ENV{REMOTE_USER} = 1;
        }
    }
}

1;
