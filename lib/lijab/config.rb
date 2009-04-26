
module Lijab

module Config
   module_function

   def init(args)
      @opts = {}
      @dirs = {}
      @files = {}
      @accounts = []
      @account = nil

      setup_basedir(args[:basedir])
      read_accounts(args[:account])
      read_options()

      @jid = Jabber::JID.new("#{@account[:jabberid]}")
      @jid.resource ||= "lijab#{(0...5).map{rand(10).to_s}.join}"
      @account[:server] ||= @jid.domain

      create_account_dirs()
   end

   def setup_basedir(basedir)
      xdg = ENV["XDG_CONFIG_HOME"]
      @basedir = basedir || xdg && File.join(xdg, "lijab") || File.expand_path("~/.lijab")

      unless File.directory?(@basedir)
         puts "Creating #{@basedir} with the default configs"
      end

      %w{accounts commands hooks}.each do |d|
         @dirs[d.to_sym] = path = File.join(@basedir, d)
         FileUtils.mkdir_p(path)
      end

      %w{accounts config}.each do |f|
         @files[f.to_sym] = path = File.join(@basedir, "#{f}.yml")
         unless File.file?(path)
            File.open(path, 'w') { |fd| fd.puts(DEFAULT_FILES[f]) }
         end
      end
   end

   def read_accounts(account)
      File.open(@files[:accounts]) do |f|
         YAML.load_documents(f) { |a| @accounts << a }
      end

      errors = []
      errors << "need at least one account!" if @accounts.empty?

      @accounts.each do |a|
         a[:port] ||= 5222

         errors << "account #{a} needs a name" unless a.key?(:name)
         errors << "account #{a[:name] || a} needs a jabberid" unless a.key?(:jabberid)
      end

      @account = account ? @accounts.find { |a| a[:name] == account} : @accounts[0]

      errors << "no account with name #{account} in #{@accounts_file}" if account && !@account

      errors.each do |e|
         STDERR.puts("#{File.basename($0)}: error: #{e}")
      end

      exit(1) unless errors.empty?
   end

   def read_options
      # FIXME: error check / validate
      @opts = YAML.load(DEFAULT_FILES["config"])
      @opts.merge!(YAML.load_file(@files[:config]))
   end

   def create_account_dirs
      @accounts.each do |a|
         a[:dir] = File.join(@dirs[:accounts], @jid.strip.to_s)
         a[:log_dir] = File.join(a[:dir], "logs")
         a[:typed] = File.join(a[:dir], "typed_history")

         [:dir, :log_dir].each { |s| FileUtils.mkdir_p(a[s]) }
      end
   end

   DEFAULT_FILES = {
      "accounts" => %Q{
         # Accounts go here. Separate each one with ---
         # First one is the default.

         #---
         #:name : an_account                  # the account name
         #:jabberid : fisk@example.com/lijab  # the resource is optional
         #:password : frosk                   # optional, will prompt if not present
         #:server : localhost                 # optional, will use the jid domain if not present
         #:port : 5222                        # optional
         #:log : yes                          # yes|no ; default no

         #---
         #:name : another_account
         #:jabberid : another_user@example.com/lijab
      }.gsub!(/^\s*/, ''),

      "config" => %Q{# default config file

# Time formatting (leave empty to not show timestamps)
:datetime_format : %H:%M:%S                   # normal messages
:history_datetime_format : %Y-%b-%d %H:%M:%S  # history messages

# When completing contacts try to find matches for online contacts, and if none
# is found try to find matches on all of them. Otherwise always match every
# contact.
:autocomplete_online_first : yes

# ctrl+c quits the program if enabled, otherwise ctrl+c ignores whatever is
# typed and you get a clean prompt, and ctrl+d on a clean line exits lijab,
# terminal style
:ctrl_c_quits : no

# Show changes in contacts' status
:show_status_changes : no

# Command aliases.
# <command_alias> : <existing_command>
# Commands can be overloaded.
# For instance /who could be redefined like so to sort by status by default
# /who : /who status
:aliases :
   /h : /history
   /exit : /quit
      }
   }

   attr_reader     :jid, :account, :basedir, :dirs, :files, :opts
   module_function :jid, :account, :basedir, :dirs, :files, :opts
end

end

