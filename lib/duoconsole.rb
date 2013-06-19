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
    start_console
  end

  def preload_gems
    require 'rails/all'

    if defined?(Bundler)
      Bundler.require(:default, :assets)
    end
  end

  def create_socket_pair
    self.child_socket, self.parent_socket = Socket.pair(:UNIX, :DGRAM, 0)
  end

  def fork_child
    child_pid = fork do
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
    Rails.application.require_environment!
  end

  def start_console
    require 'rails/commands/console'
    require 'rails/console/app'
    ConsoleDelegation.duoconsole = self
    Rails::ConsoleMethods.send :include, ConsoleDelegation
    Rails::Console.start(Rails.application)
  end

  def command_client
    @command_client ||= CommandClient.new(parent_socket)
  end


  class CommandClient
    attr_reader :socket

    def initialize socket
      @socket = socket
    end

    def method_missing(m, *args, &block)
      send m, args
    end

  private

    def send command, args
      msg = Marshal.dump([command, args])
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
      # e.class.name
    end
  end


  class CommandServer
    RECOGNIZED_COMMANDS = [:test, :rake]
    attr_reader :socket

    def initialize socket
      @socket = socket
    end

    def start
      loop do
        msg = socket.recv(1000)
        command, args = Marshal.load(msg)

        retval = if valid_command?(command)
          require_app unless @app_required
          run_command(command, args)
        else
          "Unrecognized command. Valid commands are #{RECOGNIZED_COMMANDS.join(', ')}"
        end

        socket.write(retval)
      end
    end

  private

    def valid_command? command
      RECOGNIZED_COMMANDS.include?(command.to_sym)
    end

    def run_command command, args
      commander.send(command, *args)
    rescue => e
      dump_exception e
      e.class.name
    end

    def commander
      @commander ||= Rails::Commands::Commander.new
    end

    def dump_exception e
      puts "#{e.class}: #{e.message}"
      puts e.backtrace.map {|line| "\t#{line}"}
    end

    def require_app
      Rails.env = ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test'
      require APP_PATH
      require 'commands'
      monkeypatch_commands_gem
      @app_required = true
    end

    def monkeypatch_commands_gem
      Rails::Commands::TestEnvironment.module_eval do
        def fork
          Rails::Commands::Environment.fork do
            trap(:INT) {
              $stderr.flush
              exit
            }

            Rails.application.require_environment!

            if defined?(ActiveRecord::Base)
              ActiveRecord::Base.establish_connection
            end

            add_test_dir_to_load_path

            yield
          end
        end
      end
    end
  end


  module ConsoleDelegation
    def self.duoconsole= dc
      @@duoconsole = dc
    end

    def testenv
      @@duoconsole.command_client
    end

    def test *args
      testenv.test *args
    end
  end
end
