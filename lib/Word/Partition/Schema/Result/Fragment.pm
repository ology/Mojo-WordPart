use v5.36;
package Word::Partition::Schema::Result::Fragment;

=head1 NAME

Word::Partition::Schema::Result::Fragment

=cut

use base 'DBIx::Class::Core';

__PACKAGE__->table("fragment");

__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        extra             => { unsigned => 1 },
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    "affix",
    { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
    "definition",
    { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
    "etymology",
    { data_type => "varchar", is_nullable => 1, size => 50 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint( [qw(affix etymology)] );    # fragment_affix_etymology

1;
