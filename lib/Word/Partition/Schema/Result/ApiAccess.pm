use v5.36;
package Word::Partition::Schema::Result::ApiAccess;

=head1 NAME

Word::Partition::Schema::Result::ApiAccess

=cut

use base 'DBIx::Class::Core';

__PACKAGE__->table("api_access");

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        extra             => { unsigned => 1 },
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    "token",
    { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
    "username",
    { data_type => "varchar", default_value => "", is_nullable => 0, size => 20 },
    "created",
    {
        data_type                  => "datetime",
        datetime_undef_if_invalid  => 1,
        is_nullable                => 0,
    },
    "active",
    { data_type => "tinyint", default_value => 1, is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

1;
