use v5.36;
package Word::Partition::Schema::Result::User;

=head1 NAME

Word::Partition::Schema::Result::User

NOTE: the original app used Dancer::Plugin::Auth::Extensible, which reads
its own user/role tables that weren't among the uploaded files. This is a
minimal replacement table sufficient for the plain username/password login
in Controller::Main. Adjust columns/roles to taste, or point this at
whatever "users" table Auth::Extensible was already using.

=cut

use base 'DBIx::Class::Core';

__PACKAGE__->table("user");

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        extra             => { unsigned => 1 },
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    "username",
    { data_type => "varchar", is_nullable => 0, size => 50 },
    "password",
    { data_type => "varchar", is_nullable => 0, size => 255 },    # Argon2 hash via Crypt::Passphrase
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( [qw(username)] );

1;
