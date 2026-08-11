package Word::Partition::Controller::Main;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Lingua::Word::Parser;
use Crypt::Passphrase;

use constant PREFIX         => '(?=\w)';
use constant SUFFIX         => '(?<=\w)';
use constant MAX_QUERY_SIZE => 30;

my $PASSPHRASE = Crypt::Passphrase->new(
    encoder    => 'Argon2',
    validators => [ 'Bcrypt' ],    # falls back for older hashes, if any
);

=head1 NAME

Word::Partition::Controller::Main - routes for the word-partition app

=head1 ACTIONS

=head2 index

Go to the index page

=cut

sub index ($c) {
    my $count = $c->schema->resultset('Fragment')->search->count;
    $c->render(
        template       => 'index',
        entries        => $count,
        logged_in_user => $c->logged_in_user,
    );
}

=head2 new_entry

Show the form to create a new entry (GET /new)

=cut

sub new_entry ($c) {
    $c->render(
        template       => 'edit',
        method         => 'add',
        logged_in_user => $c->logged_in_user,
    );
}

=head2 add

Create a new entry in the database (POST /add)

=cut

sub add ($c) {
    my $affix      = $c->param('affix');
    my $definition = $c->param('definition');

    if ( $affix && $definition ) {
        my $full_affix = _prefix_suffix( $affix, scalar $c->param('prefix'), scalar $c->param('suffix') );

        $c->schema->resultset('Fragment')->create(
            {
                affix      => $full_affix,
                definition => $definition,
                etymology  => scalar $c->param('etymology'),
            }
        );
    }
    else {
        $c->flash(error => 'Neither affix nor definition can be NULL');
        return $c->redirect_to('/new');
    }

    $c->redirect_to('/new');
}

=head2 delete_entry

Delete an entry from the database (GET /delete)

=cut

sub delete_entry ($c) {
    my $id       = $c->param('id');
    my $fragment = $c->schema->resultset('Fragment')->find($id);

    if ($fragment) {
        $fragment->delete;
    }
    else {
        $c->flash(error => "No fragment can be found for id $id");
    }

    $c->redirect_to('/search');
}

=head2 update

Update an existing entry in the database (POST /update)

=cut

sub update ($c) {
    my $id       = $c->param('id');
    my $fragment = $c->schema->resultset('Fragment')->find($id);

    unless ($fragment) {
        $c->flash(error => "Can't find fragment for id: $id");
        return $c->redirect_to('/search');
    }

    my $affix      = $c->param('affix');
    my $definition = $c->param('definition');

    if ( $affix && $definition ) {
        $fragment->update(
            {
                affix      => $affix,
                definition => $definition,
                etymology  => scalar $c->param('etymology'),
            }
        );
        $c->redirect_to('/search');
    }
    else {
        $c->flash(error => 'Neither affix nor definition can be empty');
        $c->redirect_to("/edit?id=$id");
    }
}

=head2 edit_entry

Show the form to update an entry (GET /edit)

=cut

sub edit_entry ($c) {
    my $id = $c->param('id');
    unless ($id) {
        return $c->redirect_to('/new');
    }

    my $fragment = $c->schema->resultset('Fragment')->find($id);
    unless ($fragment) {
        $c->flash(error => "No fragment can be found for id $id");
        return $c->redirect_to('/search');
    }

    $c->render(
        template       => 'edit',
        id             => $fragment->id,
        affix          => $fragment->affix,
        definition     => $fragment->definition,
        etymology      => $fragment->etymology,
        method         => 'update',
        logged_in_user => $c->logged_in_user,
    );
}

=head2 parse

Show the parse form and results (GET /parse)

=cut

sub parse ($c) {
    my $query   = $c->param('query');
    my $results = _parse_word( $c, $query );

    $c->render(
        template       => 'parse',
        query          => $query,
        results        => $results,
        logged_in_user => $c->logged_in_user,
    );
}

=head2 build

Show the build form and results (GET /build)

=cut

sub build ($c) {
    my $query   = $c->param('query');
    my $results = _build_term( $c, query => $query );

    $c->render(
        template       => 'build',
        query          => $query,
        results        => $results,
        logged_in_user => $c->logged_in_user,
    );
}

=head2 search

Show the search form and results (GET /search)

=cut

sub search ($c) {
    my $query = $c->param('query');
    my $etym  = $c->param('etymology');
    my $type  = $c->param('type') // 'affix';

    my $results = _search_term(
        $c,
        query => $query,
        type  => $type,
        etym  => $etym,
    );

    $c->render(
        template       => 'search',
        query          => $query,
        results        => $results,
        checked        => $type,
        etymology      => $etym,
        logged_in_user => $c->logged_in_user,
    );
}

=head2 login

Show the login form (GET) and authenticate (POST /login)

=cut

sub login ($c) {
    if ( $c->req->method eq 'POST' ) {
        my $username = $c->param('username');
        my $password = $c->param('password');
        my $return_url = $c->param('return_url') || '/';

        my $user = $c->schema->resultset('User')->find({ username => $username });

        if ( $user && $PASSPHRASE->verify_password( $password, $user->password ) ) {
            $c->session( username => $user->username );
            return $c->redirect_to($return_url);
        }

        return $c->render(
            template            => 'login',
            return_url          => $return_url,
            login_fail_message  => 'LOGIN FAILED',
        );
    }

    $c->render(
        template   => 'login',
        return_url => scalar $c->param('return_url'),
    );
}

=head2 logout

Clear the session (GET /logout)

=cut

sub logout ($c) {
    $c->session( expires => 1 );
    $c->redirect_to('/');
}

# --- helpers ------------------------------------------------------------

sub _parse_word ($c, $query) {
    my $results;

    if ( $query && length $query > MAX_QUERY_SIZE ) {
        $c->flash(error => 'The word cannot have more than ' . MAX_QUERY_SIZE . ' letters');
    }
    elsif ($query) {
        my $config = $c->app->config->{database};
        my $p = Lingua::Word::Parser->new(
            word   => $query,
            dbname => $config->{database},
            dbuser => $config->{username},
            dbpass => $config->{password},
            dbtype => $config->{driver},
            dbhost => $config->{host},
        );

        # Find the known word-part positions.
        $p->knowns;
        $p->power;
        my $score = $p->score_parts( '<i><b>', '</b></i>' );

        my @elements = map { @{ $score->{$_} } } keys %$score;

        for my $element (
            sort {
                   $b->{familiarity}[1] <=> $a->{familiarity}[1]
                || $b->{familiarity}[0] <=> $a->{familiarity}[0]
                || $a->{score}{knowns} <=> $b->{score}{knowns}
            } @elements
        ) {
            push @$results, $element;
        }
    }

    return $results;
}

sub _search_term ($c, %args) {
    my @results;

    if ( length( $args{query} // '' ) ) {
        # Allow entry of prefix/suffix indicators with hyphens
        my ( $suffix, $affix, $prefix ) = $args{query} =~ m/^(-?)([();,.\s\w]+)(-?)$/;
        $affix //= '';
        $prefix = $prefix ? PREFIX : '';
        $suffix = $suffix ? SUFFIX : '';
        my $like = quotemeta("$suffix$affix$prefix");

        my $fragments = $c->schema->resultset('Fragment')->search(
            {
                $args{type} => { like => '%' . $like . '%' },
                $args{etym} ? ( etymology => $args{etym} ) : (),
            },
            {
                order_by => { -asc => $args{type} },
            }
        );

        while ( my $result = $fragments->next ) {
            push @results, {
                id         => $result->id,
                affix      => $result->affix,
                definition => $result->definition,
                etymology  => $result->etymology,
            };
        }
    }

    return \@results;
}

sub _build_term ($c, %args) {
    my @results;

    if ( length( $args{query} // '' ) ) {
        my @defn = split /\s+/, $args{query};

        for my $def (@defn) {
            my $fragments = $c->schema->resultset('Fragment')->search(
                { definition => { like => '%' . $def . '%' } },
                { order_by   => { -asc => 'definition' } },
            );

            while ( my $result = $fragments->next ) {
                push @results, {
                    id         => $result->id,
                    affix      => $result->affix,
                    definition => $result->definition,
                    etymology  => $result->etymology,
                };
            }
        }
    }

    return \@results;
}

sub _prefix_suffix ( $affix, $prefix, $suffix ) {
    $affix  = SUFFIX . $affix if $suffix;
    $affix .= PREFIX          if $prefix;
    return $affix;
}

1;
