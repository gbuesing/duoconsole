require 'socket'

class Duoconsole

  def self.start
    new.start
  end

  attr_accessor :child_socket, :parent_socket

  def start
    preload_gems
    create_socket_pair
    fork_child
    load_application
    initialize_command_client
    start_console
  end

  def preload_gems
    require 'rails/all'

    if defined?(Bundler)
      Bundler.require(:default, :assets)
    end

    require 'commands'
  end

  def create_socket_pair
    self.child_socket, self.parent_socket = Socket.pair(:UNIX, :DGRAM, 0)
  end

  def fork_child
    child_pid = fork do
      Rails.env = ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'

      load_application
      monkeypatch_test_environment

      trap(:INT) {
        # Ignore. This process needs to stay alive until the parent process exits
      }

      CommandServer.new(child_socket).start
    end

    # cleanup before exiting
    at_exit {
      Process.kill(:QUIT, child_pid)
      parent_socket.close
      child_socket.close
    }
  end

  def load_application
    require APP_PATH

    if Rails.env.test?
      # Initializer copied from https://github.com/jonleighton/spring/blob/master/lib/spring/application.rb#L30
      #
      # The test environment has config.cache_classes = true set by default.
      # However, we don't want this to prevent us from performing class reloading,
      # so this gets around that.
      Rails::Application.initializer :initialize_dependency_mechanism, group: :all do
        ActiveSupport::Dependencies.mechanism = :load
      end
    end

    Rails.application.require_environment!
  end

  def initialize_command_client
    ConsoleDelegation.command_client = CommandClient.new(parent_socket)
  end

  def start_console
    require 'rails/commands/console'
    require 'rails/console/app'
    Rails::ConsoleMethods.send :include, ConsoleDelegation
    Rails::Console.start(Rails.application)
  end

  def monkeypatch_test_environment
    Rails::Commands::TestEnvironment.module_eval do
      # Overriding this method to add the following behavior:
      #   1. fix issue with Postgres adapter and forking behavior
      #   2. trap INT signal and exit
      def fork
        ActiveRecord::Base.clear_active_connections!
        Rails::Commands::Environment.fork do
          setup_for_test
          trap(:INT) { exit(1) }

          yield
          ActiveRecord::Base.clear_active_connections!
        end
      end
    end
  end


  class CommandClient
    attr_reader :socket

    def initialize socket
      @socket = socket
    end

    def send msg
      socket.write(msg)
      recv
    end

    def recv
      socket.recv(1000)
    rescue IRB::Abort => e
      # IRB::Abort is triggered by ctrl-c
      # When raise, we didn't get to recv message returned from this run
      # Clear it out now so that it won't be in the buffer for next run
      socket.recv(1000)
      raise e
    end

    def method_missing(m, *args, &block)
      send "#{m} #{args.join(' ')}"
    end
  end


  class CommandServer
    attr_reader :socket

    def initialize socket
      @socket = socket
    end

    def start
      loop do
        msg = socket.recv(1000)
        command, args = get_command_and_args msg

        retval = if commander.respond_to?(command)
          commander.send(command, args)
        else
          'Unrecognized command'
        end

        socket.write(retval)
      end
    end

    def get_command_and_args msg
      parts = msg.split(' ')
      command = parts.shift
      args = parts.join(' ')
      args = nil unless args.match(/\S/)
      [command, args]
    end

    def commander
      @commander ||= Rails::Commands::Commander.new
    end
  end


  module ConsoleDelegation
    def self.command_client= client
      @@command_client = client
    end

    def testenv
      @@command_client
    end

    def test *args
      testenv.test *args
    end
  end
end
