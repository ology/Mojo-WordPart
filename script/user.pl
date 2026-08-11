#!/usr/bin/env perl

use v5.36;
use experimental 'signatures';

use FindBin       qw($Bin);
use Mojo::File     qw(path);
use lib path($Bin)->dirname->child('lib')->to_string;

use Crypt::Passphrase ();
use Term::ReadKey     qw(ReadMode ReadLine);
use Word::Partition::Schema ();

# --- locate & load the same config the Mojolicious app uses ------------
my $app_home    = path($Bin)->dirname;
my $config_file = $ENV{WORD_PARTITION_CONFIG} // $app_home->child('word_partition.conf');
my $config      = do "$config_file"
  or die "Can't load config '$config_file': ", ($@ || $! || 'unknown error'), "\n";

my ($action, $username, $pass) = @ARGV;

my %dispatch = (
    add  => \&add_user,
    pass => \&change_password,
    del  => \&delete_user,
);

die usage() unless $username && $action && $dispatch{$action};

my $schema = Word::Partition::Schema->connect(
    @{ $config->{database} }{qw(dsn username password)},
    { RaiseError => 1, quote_names => 1 },
);

my $users = $schema->resultset('User');
my $user  = $users->find({ username => $username });

$dispatch{$action}->($users, $user, $username, $pass);

sub add_user ($rs, $existing, $user_name, $password) {
    return say "User '$user_name' is already known." if $existing;

    $password //= prompt_password($user_name);
    my $hash = passphrase()->hash_password($password);
    $rs->create({ username => $user_name, password => $hash });
    say "User '$user_name' successfully created.";
}

sub change_password ($rs, $existing, $user_name, $password) {
    return say "Can't change password for unknown user '$user_name'." unless $existing;

    $password //= prompt_password($user_name);
    my $hash = passphrase()->hash_password($password);
    $existing->update({ password => $hash });
    say "Password for '$user_name' successfully changed.";
}

sub delete_user ($rs, $existing, $user_name, $password) {
    return say "Can't delete unknown user '$user_name'." unless $existing;

    $existing->delete;
    say "User '$user_name' successfully deleted.";
}

sub passphrase () {
    state $authenticator = Crypt::Passphrase->new(encoder => 'Argon2');
    return $authenticator;
}

sub prompt_password ($user_name) {
    ReadMode('noecho');
    print "Password for user '$user_name': ";
    my $input = ReadLine(0);
    chomp $input;
    print "\n";
    ReadMode('restore');
    return $input;
}

sub usage () {
    return <<~"USAGE";
        Usage: $0 add|pass|del username [password]

          add   username [password]   create a new user
          pass  username [password]   set/reset a user's password
          del   username               delete a user

        If [password] is omitted you'll be prompted for it (hidden input).
        USAGE
}
