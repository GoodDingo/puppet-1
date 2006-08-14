# Sun packaging.  No one else uses these package tools, AFAIK.

Puppet::Type.type(:package).provide :sun do
    desc "Sun's packaging system.  Requires that you specify the source for
        the packages you're managing."
    commands :info => "/usr/bin/pkginfo",
             :add => "/usr/sbin/pkgadd",
             :rm => "/usr/sbin/pkgrm"

    defaultfor :operatingsystem => :solaris

    def self.list
        packages = []
        hash = {}
        names = {
            "PKGINST" => :name,
            "NAME" => nil,
            "CATEGORY" => :category,
            "ARCH" => :platform,
            "VERSION" => :ensure,
            "BASEDIR" => :root,
            "HOTLINE" => nil,
            "EMAIL" => nil,
            "VENDOR" => :vendor,
            "DESC" => :description,
            "PSTAMP" => nil,
            "INSTDATE" => nil,
            "STATUS" => nil,
            "FILES" => nil
        }

        cmd = "#{command(:info)} -l"

        # list out all of the packages
        execpipe(cmd) { |process|
            # we're using the long listing, so each line is a separate
            # piece of information
            process.each { |line|
                case line
                when /^$/:
                    hash[:provider] = :sun

                    packages.push Puppet.type(:package).installedpkg(hash)
                    hash.clear
                when /\s*(\w+):\s+(.+)/:
                    name = $1
                    value = $2
                    if names.include?(name)
                        unless names[name].nil?
                            hash[names[name]] = value
                        end
                    else
                        raise "Could not find %s" % name
                    end
                when /\s+\d+.+/:
                    # nothing; we're ignoring the FILES info
                end
            }
        }
        return packages
    end

    # Get info on a package, optionally specifying a device.
    def info2hash(device = nil)
        names = {
            "PKGINST" => :name,
            "NAME" => nil,
            "CATEGORY" => :category,
            "ARCH" => :platform,
            "VERSION" => :ensure,
            "BASEDIR" => :root,
            "HOTLINE" => nil,
            "EMAIL" => nil,
            "VSTOCK" => nil,
            "VENDOR" => :vendor,
            "DESC" => :description,
            "PSTAMP" => nil,
            "INSTDATE" => nil,
            "STATUS" => nil,
            "FILES" => nil
        }

        hash = {}
        cmd = "#{command(:info)} -l"
        if device
            cmd += " -d #{device}"
        end
        cmd += " #{@model[:name]}"

        begin
            # list out all of the packages
            execpipe(cmd) { |process|
                # we're using the long listing, so each line is a separate
                # piece of information
                process.each { |line|
                    case line
                    when /^$/:  # ignore
                    when /\s*([A-Z]+):\s+(.+)/:
                        name = $1
                        value = $2
                        if names.include?(name)
                            unless names[name].nil?
                                hash[names[name]] = value
                            end
                        end
                    when /\s+\d+.+/:
                        # nothing; we're ignoring the FILES info
                    end
                }
            }
            return hash
        rescue Puppet::ExecutionFailure
            return nil
        end
    end

    def install
        unless @model[:source]
            raise Puppet::Error, "Sun packages must specify a package source"
        end
        cmd = [command(:add)]
        
        if @model[:adminfile]
            cmd << " -a " + @model[:adminfile]
        end

        if @model[:responsefile]
            cmd << " -r " + @model[:responsefile]
        end

        cmd += ["-d", @model[:source]]
        cmd += ["-n", @model[:name]]
        cmd = cmd.join(" ")

        begin
            output = execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::PackageError.new(output)
        end
    end

    # Retrieve the version from the current package file.
    def latest
        hash = info2hash(@model[:source])
        hash[:ensure]
    end

    def query
        info2hash()
    end

    def uninstall
        command  = "#{command(:rm)} -n "

        if @model[:adminfile]
            command += " -a " + @model[:adminfile]
        end

        command += " " + @model[:name]
        begin
            execute(command)
        rescue ExecutionFailure => detail
            raise Puppet::Error,
                "Could not uninstall %s: %s" %
                [@model[:name], detail]
        end
    end

    # Remove the old package, and install the new one.  This will probably
    # often fail.
    def update
        if @model.is(:ensure) != :absent
            self.uninstall
        end
        self.install
    end
end

# $Id$
