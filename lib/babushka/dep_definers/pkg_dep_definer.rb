module Babushka
  class PkgDepDefiner < BaseDepDefiner

    accepts_list_for :installs, :default_pkg
    accepts_list_for :provides, :default_pkg

    def default_pkg
      VersionOf.new name
    end

    def process
      super

      requires pkg_manager.manager_dep
      met? {
        if !applicable?
          log_ok "Not required on #{pkg_manager.manager_key}-based systems."
        else
          packages_present and cmds_in_path
        end
      }
      meet { install_packages }
    end


    private

    def chooser
      PkgManager.for_system.manager_key
    end

    def applicable?
      !installs.blank?
    end

    def packages_present
      installs.all? {|pkg| pkg_manager.has? pkg }
    end

    def cmds_in_path
      present, missing = provides.partition {|cmd_name| cmd_dir(cmd_name) }
      good, bad = present.partition {|cmd_name| pkg_manager.cmd_in_path? cmd_name }

      log_ok "#{good.map {|i| "'#{i}'" }.to_list} run#{'s' if good.length == 1} from #{cmd_dir(good.first)}." unless good.empty?
      log_error "#{missing.map {|i| "'#{i}'" }.to_list} #{missing.length == 1 ? 'is' : 'are'} missing from your PATH." unless missing.empty?

      unless bad.empty?
        log_error "#{bad.map {|i| "'#{i}'" }.to_list} incorrectly run#{'s' if bad.length == 1} from #{cmd_dir(bad.first)}."
        log "You need to put #{pkg_manager.prefix} before #{cmd_dir(bad.first)} in your PATH."
      end

      missing.empty? and bad.empty?
    end

    def install_packages
      pkg_manager.install! installs
    end

    def pkg_manager
      PkgManager.for_system
    end
  end
end
