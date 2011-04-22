module Babushka
  class YumHelper < PkgHelper
  class << self
    def pkg_type; :rpm end
    def pkg_cmd; pkg_binary end
    def pkg_binary; "yum" end
    def manager_key; :yum end

    private

    def _has? pkg_name
      # Some example output, with 'wget' installed:
      #   fedora-13:  'wget.x86_64  1.12-2.fc13       @fedora'
      #   centos-5.5: 'wget.x86_64  1.11.4-2.el5_4.1  installed'
      failable_shell("#{pkg_binary} list -q '#{pkg_name}'").stdout.split("\n").select {|line|
        line[/^#{Regexp.escape(pkg_name.to_s)}\.\w+\b/] # e.g. wget.x86_64
      }.any? {|match|
        final_word = match[/[^\s]+$/] || ''
        (final_word == 'installed') || final_word.starts_with?('@')
      }
    end


    # I just added these two methods. They're untested and I
    # don't know yum so they're just a starting point.

    def _install! pkgs, opts
      # For yum, it will probably need to iterate, setting the verb each time.
      pkgs.all? {|pkg|
        # This is the same command from PkgHelper#_install!, with 'install' replaced with the call to #install_verb_for.
        log_shell "Installing #{pkg} via #{manager_key}", "#{pkg_cmd} -y #{install_verb_for(pkg)} #{pkg} #{opts}", :sudo => should_sudo?
      }
    end

    def install_verb_for pkg
      # Some yum-specific check.
      shell("yum is-this-a-group-package #{pkg}") ? 'groupinstall' : 'install'
    end

  end
  end
end
