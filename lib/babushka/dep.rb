module Babushka
  module DepHelpers
    def self.included base # :nodoc:
      base.send :include, HelperMethods
    end

    module HelperMethods
      def     Dep name;         Dep.for name                       end
      def     dep name, &block; Dep.new name, block                end
      def pkg_dep name, &block; Dep.new name, block, PkgDepDefiner end
      def gem_dep name, &block; Dep.new name, block, GemDepDefiner end
      def ext_dep name, &block; Dep.new name, block, ExtDepDefiner end
    end
  end

  class Dep
    include PromptHelpers

    attr_reader :name
    attr_reader :name, :local_vars
    attr_accessor :unmet_message

    def initialize name, block, definer_class = DepDefiner
      @name = name
      @local_vars = {}
      @opts = {
        :parent_vars => {},
        :child_vars => {}
      }
      @definer = definer_class.new self
      @definer.process &block
      debug "\"#{name}\" depends on #{payload[:requires].inspect}"
      Dep.register self
    end

    def self.deps
      @@deps ||= {}
    end

    def self.register dep
      raise "There is already a registered dep called '#{dep.name}'." unless deps[dep.name].nil?
      deps[dep.name] = dep
    end
    def self.for name
      returning dep = deps[name] do |result|
        log"#{name.colorize 'grey'} #{"<- this dep isn't defined!".colorize('red')}" unless result
      end
    end

    def met? opts = {}
      process opts.merge default_run_opts.merge :attempt_to_meet => false
    end
    def meet opts = {}
      process opts.merge default_run_opts.merge :attempt_to_meet => !Base.opts[:dry_run]
    end

    def vars
      opts[:parent_vars].merge(opts[:child_vars]).merge(local_vars)
    end
    def set key, value
      @local_vars[key.to_s] = value
    end
    def opts
      @opts.merge @run_opts || {}
    end

    def ask_for_var key, default = nil
      # TODO this should be elsewhere
      read_method = [payload[:run_in]].include?(key) ? :read_path_from_prompt : :read_value_from_prompt
      printable_key = key.to_s.gsub '_', ' '
      @local_vars[key] = send read_method, "#{printable_key}#{" for #{name}" unless printable_key == name}", :default => default
    end


    private

    def process run_opts
      @run_opts = run_opts
      cached? ? cached_result : process_and_cache
    end

    def process_and_cache
      log name, :closing_status => (opts[:attempt_to_meet] ? true : :dry_run) do
        if opts[:callstack].include? self
          log_error "Oh crap, endless loop! (#{opts[:callstack].push(self).drop_while {|dep| dep != self }.map(&:name).join(' -> ')})"
        else
          opts[:callstack].push self
          returning ask_for_vars && process_in_dir do
            opts[:callstack].pop
          end
        end
      end
    end

    def ask_for_vars
      payload[:asks_for].reject {|key|
        vars[key]
      }.each {|key|
        ask_for_var key
      }
    end

    def process_in_dir
      path = payload[:run_in].is_a?(Symbol) ? vars[payload[:run_in]] : payload[:run_in]
      in_dir path do
        process_deps and process_self
      end
    end

    def process_deps
      requires_for_system.send(opts[:attempt_to_meet] ? :all? : :each, &L{|dep_name|
        unless (dep = Dep(dep_name)).nil?
          returning dep.send :process, opts.merge(:parent_vars => vars) do
            opts[:child_vars].update dep.vars
          end
        end
      })
    end

    def process_self
      if !(met_result = run_met_task(:initial => true))
        if !opts[:attempt_to_meet]
          met_result
        else
          call_task :before and
          returning call_task :meet do call_task :after end
          run_met_task
        end
      elsif :fail == met_result
        log "fail lulz"
      else
        true
      end
    end

    def run_met_task task_opts = {}
      returning cache_process(call_task(:met?)) do |result|
        if :fail == result
          log_extra "You'll have to fix '#{name}' manually."
        elsif !result && task_opts[:initial]
          log_extra "#{name} not already met#{unmet_message_for(result)}."
        elsif result && !task_opts[:initial]
          log "#{name} met.".colorize('green')
        end
      end
    end

    def has_task? task_name
      !payload[task_name].nil?
    end

    def call_task task_name
      (payload[task_name] || default_task(task_name)).call
    end

    def default_task task_name
      {
        :met? => L{
          log_extra "#{name} / met? not defined, moving on."
          true
        },
        :meet => L{ log_extra "#{name} / meet not defined; nothing to do." }
      }[task_name] || L{ true }
    end

    def unmet_message_for result
      unmet_message.nil? || result ? '' : " - #{unmet_message.capitalize}"
    end

    def cached_result
      returning cached_process do |result|
        log_result "#{name} (cached)", :result => result
      end
    end
    def cached?
      instance_variable_defined? :@_cached_process
    end
    def cached_process
      @_cached_process
    end
    def cache_process value
      @_cached_process = value
    end

    def default_run_opts
      {
        :callstack => []
      }
    end

    def payload
      @definer.payload
    end

    def requires_for_system
      (payload[:requires][:all] + payload[:requires][uname]).uniq
    end

    def inspect
      "#<Dep:#{object_id} '#{name}' #{" #{'un' if cached_result}met" if cached?}{ #{payload[:requires].join(', ')} }>"
    end
  end
end