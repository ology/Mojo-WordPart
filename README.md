# Word::Partition (Mojolicious port)

A modern-Perl port of the original Dancer app to Mojolicious.

## Run it

```
carton install          # or: cpanm --installdeps .
morbo script/word_partition        # dev server, auto-reload
# or
hypnotoad script/word_partition    # production
```

Configure the DB via environment variables (see `word_partition.conf`):
`WORD_PARTITION_DSN`, `WORD_PARTITION_DB_USER`, `WORD_PARTITION_DB_PASS`,
`WORD_PARTITION_DB_NAME`, `WORD_PARTITION_DB_DRIVER`, `WORD_PARTITION_DB_HOST`,
and `WORD_PARTITION_SECRET` for the session-cookie signing secret.

## What changed vs. the Dancer app

- **Framework**: `Dancer` → `Mojolicious`, using a real app class
  (`lib/Word/Partition.pm`, `sub startup`) instead of top-level DSL calls.
- **Routing**: routes now live in `startup()` and dispatch to
  `Word::Partition::Controller::Main`, rather than route subs defined
  directly with Dancer's `get`/`post` sugar.
- **Auth**: `Dancer::Plugin::Auth::Extensible` (`require_login`,
  `logged_in_user`) is replaced with:
  - a `logged_in_user` helper reading `session->{username}`,
  - an `under()` bridge that protects `/new`, `/add`, `/edit`, `/update`,
    `/delete` and redirects to `/login` (preserving `return_url`) if not
    authenticated,
  - a new `Word::Partition::Schema::Result::User` result class plus
    `Crypt::Passphrase` (Argon2) for password verification, since the
    original user/role tables used by Auth::Extensible weren't among the
    uploaded files. **You'll want to point this at your real user table
    and hashing scheme if one already exists.**
- **Flash messages**: `Dancer::Plugin::FlashMessage` → Mojolicious's
  built-in `flash`, used the same way (`$c->flash(error => ...)`, read in
  the layout with `flash('error')`).
- **DB access**: `Dancer::Plugin::DBIC` → an explicit `schema` helper in
  `startup()` that lazily connects via `Word::Partition::Schema->connect`
  (`state` gives you a single cached `$schema`, same effect as the plugin).
- **Templates**: Template Toolkit (`.tt`) → Mojolicious's built-in
  Embedded Perl (`.html.ep`), including a shared layout
  (`templates/layouts/main.html.ep`, replacing `main.tt`) and a
  `partials/_header.html.ep` partial (replacing the `INCLUDE header.tt`
  pattern). Nav-link "active" highlighting now uses Mojolicious's
  `current_route` instead of comparing `request.path` strings.
- **Controllers**: the private `_add_entry`/`_delete_entry`/etc. subs from
  `Word::Partition.pm` are now real controller actions/helpers taking
  `$c` (the Mojolicious controller) instead of reaching for Dancer's
  `params`/`request` globals — this also makes the code testable with
  `Test::Mojo` without booting a Dancer app.
- **Modern Perl syntax**: `use v5.36` + `Mojo::Base -signatures`
  throughout, so subs take real signatures (`sub add ($c) { ... }`)
  instead of `my %args = @_;` unpacking, and `//`/postfix deref are used
  where they clean things up. `Readonly` constants became plain `use
  constant`.
- **DBIx::Class result classes** (`Schema.pm`, `Fragment.pm`,
  `ApiAccess.pm`) are functionally unchanged — DBIx::Class works
  identically under Mojolicious — just tidied (dropped `use strict;
  use warnings;` in favor of `use v5.36`, which implies both).

## Not migrated

- `public/` static assets (CSS, Foundation, images, jQuery) — copy them
  over as-is; Mojolicious serves `public/` the same way Dancer does.
- The `Lingua::Word::Parser` dependency and its `sandbox/` lib path are
  kept as-is in the controller; adjust the `use lib` line for your
  environment or, better, install it properly via `cpanm`/`carton`.
