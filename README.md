# squealgen

Generate squeal types from a running database.

## why?

[Squeal](https://hackage.haskell.org/package/squeal-postgresql) is a lovely way to interact with a database, but setting up the initial schema is a struggle.
By default, it assumes you will be managing and migrating your database with Squeal, and if you are starting
from scratch, that works great, but if you're managing it some other way, or even just want to test out Squeal
on an existing database, it's tedious to have to set up the database types and keep them up to date.

## how?

1. clone the repo and change into the directory
2. `make prefix=$HOME/.local install`. (We will assume here that `$HOME/.local/bin` is in your path, obviously
feel free to install wherever makes sense to you.)
2. If my database is `cooldb`, my haskell module file is `Schema.hs`, and i want to use the `public` schema (the default),
I would run `squealgen cooldb Schema public > ~/myproject/src/Schema.hs`.

You could integrate this in various ways: perhaps just as an initial scaffold, or perhaps integrated as part
of your build process. A true madman could integrate this into a TH call, but I suspect this would be slow and
prone to failing (for instance, better never compile any code if you don't have access to the right version
of psql or a way of spinning up an empty database.)

I highly recommend having a scripted way to bring up a temporary database and run all migrations first. I use
Jonathan Fischoff's [tmp-postgres](https://hackage.haskell.org/package/tmp-postgres-1.34.1.0) library and
recommend it if you're running migrations through Haskell.

## hacking?

My workflow looks like this:

```make testwatch```


## what next?

- Remove string-hacking, generate in a more principled way.
- Extract check constraints (maybe). This is much harder than the rest of it.
- Views
- Triggers
