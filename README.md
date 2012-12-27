Duoconsole
==========

Rails development console with test environment as a child process.

Requires [Rails commands gem](https://github.com/rails/commands).


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
