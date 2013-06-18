Duoconsole
==========

Launch Rails development console with test environment as a child process, so that you can run the `test` command from the [Rails commands gem](https://github.com/rails/commands) in your development console.

Example:

    $ bundle exec duoconsole
    Loading development environment (Rails 3.2.9)
    irb(main):001:0> test 'unit/post'
    Run options: --seed 28947

    # Running tests:

    .........

    Finished tests in 0.358498s, 25.1047 tests/s, 50.2095 assertions/s.

    9 tests, 18 assertions, 0 failures, 0 errors, 0 skips
    => "Completed"
    irb(main):002:0>


You can also run rake commands in the test environment via the `testenv` proxy:

    irb(main):003:0> testenv.rake 'db:schema:load'

    ... loads the schema into the test database ...

    => "Completed"
    irb(main):004:0>

See the [Rails commands README](https://github.com/rails/commands/blob/master/README.md) for available commands and options.


Installation
------------

Add this line to your application's Gemfile:

    gem 'duoconsole', :group => :development

And then execute:

    $ bundle


Starting the console
--------------------
From the root of your project, instead of running `rails console`, run:

    bundle exec duoconsole


How it works
------------

When you start Duoconsole, you'll create two processes: the main process, which is running the Rails console in the development environment, and a child process that has your app loaded in the test environment. The parent process sends commands to the child process via a Unix socket.

The child process is created after Rails and all gems in Gemfile are required (via `Bundler.require`), so that this work only needs to be performed once.

The test process will fork another process for each test run, so that each run will exist in isolation, and can be easily aborted with ctrl-c. This runner process dies once tests are finished, or aborted.

The [rebootable branch](https://github.com/gbuesing/duoconsole/tree/rebootable) forks an extra process after gems are required, so that the test environment can be reloaded when changes are made to the app outside of the app/ directory. I'm not sure yet if this additional complexity is necessary, or if it's just as easy to exit and reload the console.


Caveats
-------
The test command won't detect changes outside of your app/ directory, e.g. changes to files in lib/, config/, Gemfile etc. won't be picked up.

You'll need to exit and reload the console to pick up these changes.


Platform Compatibility
----------------------
Duoconsole has been tested on OS X on a Rails 4 app running on MRI Ruby 2.0.0 and a Rails 3.2 app running on MRI Ruby 1.9.3.

AFAIK this won't work on Windows or JRuby because of a lack of support for `Kernel.fork`.

