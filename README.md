Duoconsole
==========

Launch Rails development console with test environment as a child process.

This allows you to run the `test` command from the [Rails commands gem](https://github.com/rails/commands) in your development console.


Installation
------------

Add this line to your application's Gemfile:

    gem 'duoconsole'

And then execute:

    $ bundle


Usage
-----
From the root of your project, instead of running `rails console`, run:

    bundle exec duoconsole

This will launch your app's console in development environment, with the app's test environment as a child process.

This setup allows you to successfully run the `test` command in your development console, instead of having to launch a separate console for test mode.

Example:

    > test 'unit/person'

You can also run other commands in the test environment using the `testenv` proxy:

    > testenv.rake 'db:schema:load'

See [Rails commands README](https://github.com/rails/commands/blob/master/README.md) for available commands.


Platform Compatibility
----------------------
This was tested on OS X using a Rails 3.2 app with a Postgres DB and Ruby 1.9.3.

This won't work on Windows because of a lack of support for `fork`.

