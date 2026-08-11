package Word::Partition;
use Mojo::Base 'Mojolicious', -signatures;

use Word::Partition::Schema;
use Mojo::Log ();

our $VERSION = '0.2';

=head1 NAME

Word::Partition - Interact with word-parts (Mojolicious edition)

=cut

sub startup ($self) {
    my $config = $self->plugin('Config' => { file => 'word_partition.conf' });

    my $log = Mojo::Log->new(
        path  => $config->{log_path},
        level => $config->{log_level},
    );
    $self->log($log);

    $self->secrets( $config->{secrets} // ['please-change-this-secret'] );

    # Session cookie lifetime (2 hours, matches the old Dancer default-ish)
    $self->sessions->default_expiration(7200);

    # --- Database ---------------------------------------------------
    $self->helper(schema => sub {
        state $schema = Word::Partition::Schema->connect(
            @{ $config->{database} }{qw(dsn username password)},
            { RaiseError => 1, quote_names => 1 },
        );
        return $schema;
    });

    # --- Auth helpers -------------------------------------------------
    $self->helper(logged_in_user => sub ($c) {
        return $c->session->{username};
    });

    # --- Routes ---------------------------------------------------------
    my $r = $self->routes;

    $r->get('/')->to('main#index');

    # Bridge: anything under here requires a logged-in user, otherwise
    # bounce to /login (preserving the original destination URL).
    my $auth = $r->under('/' => sub ($c) {
        return 1 if $c->logged_in_user;
        $c->flash(error => 'Please log in to continue');
        $c->redirect_to( $c->url_for('/login')->query(return_url => $c->req->url) );
        return undef;
    });

    $auth->get('/new')->to('main#new_entry')->name('new_entry');
    $auth->post('/add')->to('main#add')->name('add');
    $auth->get('/edit')->to('main#edit_entry')->name('edit_entry');
    $auth->post('/update')->to('main#update')->name('update');
    $auth->get('/delete')->to('main#delete_entry')->name('delete_entry');

    $r->get('/parse')->to('main#parse')->name('parse');
    $r->get('/build')->to('main#build')->name('build');
    $r->get('/search')->to('main#search')->name('search');

    $r->any(['GET', 'POST'] => '/login')->to('main#login');
    $r->get('/logout')->to('main#logout');
}

1;

__END__

=head1 AUTHOR

Gene Boggs <gene@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by Gene Boggs.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
