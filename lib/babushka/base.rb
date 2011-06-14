module Babushka
  class Base
  class << self

    # +task+ represents the overall job that is being run, and the parts that
    # are external to running the corresponding dep tree itself - logging, and
    # var loading and saving in particular.
    def task
      Task.instance
    end

    # +cmdline+ is an instance of +Cmdline::Parser+ that represents the arguments
    # that were passed via the commandline. It handles parsing those arguments,
    # and choosing the task to perform based on the 'verb' supplied - e.g. 'meet',
    # 'list', etc.
    def cmdline
      @cmdline ||= Cmdline::Parser.for(ARGV)
    end

    # +host+ is an instance of Babushka::SystemProfile for the system the command
    # was invoked on. If the current system isn't supported, SystemProfile.for_host
    # will return +nil+, and Base.run will fail early.
    def host
      @host ||= Babushka::SystemProfile.for_host
    end

    # +sources+ is an instance of Babushka::SourcePool, contains all the
    # sources that babushka can currently load deps from. This means all the sources
    # found in ~/.babushka/sources, plus the default sources:
    #   - anonymous (no source file; i.e. deps defined in an +irb+ session,
    #     or similar)
    #   - core (the builtin deps that babushka uses to install itself)
    #   - current dir (the contents of ./babushka-deps)
    #   - personal (the contents of ~/.babushka/deps)
    def sources
      SourcePool.instance
    end

    def threads
      @threads ||= []
    end

    def in_thread &block
      threads.push Thread.new(&block)
    end

    # The top-level entry point for babushka runs invoked at the command line.
    # When the `babushka` command is run, bin/babushka first triggers a load
    # via lib/babushka.rb, and then calls this method.
    def run
      cmdline.run
    ensure
      threads.each &:join
    end

    def exit_on_interrupt!
      if $stdin.tty?
        stty_save = `stty -g`.chomp
        trap("INT") {
          system "stty", stty_save
          unless Base.task.callstack.empty?
            puts "\n#{closing_log_message("#{Base.task.callstack.first.contextual_name} (cancelled)", false, :closing_status => true)}"
          end
          exit
        }
      end
    end

    def program_name
      @program_name ||= ENV['PATH'].split(':').include?(File.dirname($0)) ? File.basename($0) : $0
    end
  end
  end
end
