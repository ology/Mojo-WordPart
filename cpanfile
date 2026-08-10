requires 'perl', '5.036';

requires 'Mojolicious';
requires 'DBIx::Class';
requires 'DBD::SQLite';
requires 'Crypt::Passphrase';
requires 'Crypt::Passphrase::Argon2';
requires 'Crypt::Passphrase::Bcrypt';
requires 'Lingua::Word::Parser';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Mojo';
};
