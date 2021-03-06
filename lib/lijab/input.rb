require 'readline'
require 'readline/extra'

module Lijab

module InputHandler

   DEFAULT_PROMPT = "> "

   @prompt = DEFAULT_PROMPT
   @last_to = ""
   @last_typed = ""
   @multiline = false
   @multilines = []

   module_function

   def init
      Readline::completer_word_break_characters = ""
      Readline::completion_append_character = " "
      Readline::completion_proc = method(:completer).to_proc
      Readline::pre_input_proc = lambda do
         print "#{ANSI.cleartoeol}" ; STDOUT.flush
         unless @last_to.empty?
            Readline::insert_text("#{@last_to}: ")
            Readline::redisplay
         end
      end

      if Config.opts[:ctrl_c_quits]
         trap("SIGINT") { Main.quit }
      else
         trap("SIGINT") do
            Readline::line_buffer = ""
            puts
            Out::make_infoline
            print "#{@prompt}"
            STDOUT.flush
         end
      end

      read_typed_history()

      init_char_input_stuff()

      @input_thread = Thread.new { read_input() }
   end

   def prompt(p=nil)
      return @prompt unless p
      @prompt = p
   end

   def reset_prompt
      @prompt = DEFAULT_PROMPT
   end

   def init_char_input_stuff
      # i'm surprised this doesn't make typing fucking unbearable

      @on_char_input_blocks = []

      @on_char_input_blocks << lambda do |c|
         to, msg = Readline::line_buffer.split(":", 2).strip
         if to && msg && Main.contacts.key?(to)
            # TODO: try to see if a thread improves things
            Main.contacts[to].typed_stuff
         end
         c
      end

      Readline::char_input_proc = lambda do |c|
         ret = c
         @on_char_input_blocks.each do |block|
            ret = block.call(c)
            break if ret != c
         end
         ret
      end
   end

   def on_char_input(&block)
      @on_char_input_blocks << block
   end

   #def composing_watcher
   #   timer = nil
   #   loop do
   #      sleep(1)

   #      buf = Readline::line_buffer
   #      next unless buf != @last_line

   #      @last_line = buf
   #      to, msg = buf.split(":", 2).strip

   #      next unless to && msg && Main.contacts.key?(to)
   #   end
   #end

   def read_input
      loop do
         Out::make_infoline

         t = Readline::readline(@prompt, true)

         @last_typed = t || ""

         if !t
            if @multiline
               @last_typed = @multilines
               process_input(@multilines.join("\n"))
               multiline(false)
            else
               if Config.opts[:ctrl_c_quits]
                  puts ; next
               else
                  Main.quit
               end
            end
         elsif !@multiline && t =~ /^\s*$/
            Readline::HISTORY.pop
         else
            Readline::HISTORY.pop if Readline::HISTORY.to_a[-2] == t

            if @multiline
               @multilines.push(t)
               @last_typed = @multilines
            else
               process_input(t)
            end
         end
      end
   end

   def process_input(text)
      return if text.empty?

      if !Main.connected
         # FIXME: brute force ftw!
         Out::error("not connected :-(", false)
         return
      end

      if text[0] == ?/
         Commands::run(*text[1..-1].split(" ", 2))
         @last_to = ""
      else
         to, msg = text.split(":", 2)
         return unless to && msg && !msg.empty? && Main.contacts.key?(to)
         msg = msg[1..-1] if msg[0].chr == " " # goddammit, whitespace will be the death of me

         @last_to = to
         jid = Jabber::JID.new(to)
         jid = nil unless jid.resource
         Main.contacts[to].send_message(msg, jid)
      end
   end

   def delete_last_typed
      if @last_typed.is_a?(Array)
         @last_typed.each do |line|
            # line length + multiline prompt + \n
            # FIXME: put the multiline prompt somewhere
            print "\b" * (line.length + 6)
            print "#{ANSIMove.up(1)}"
         end
         print "#{ANSIMove.down(1)}" if @last_typed.length > 0
      else
         print "\b" * @last_typed.length
      end
   end

   def delete_typed
      if @multiline
         delete_last_typed()
      else
         print "\b" * Readline::line_buffer.length
      end
   end

   def redisplay_input()
      if @multiline && !@multilines.empty?
         puts "#{ANSI.clearline}#{DEFAULT_PROMPT}#{@multilines[0]}"
         @multilines[1..-1].each do |line|
            puts "#{ANSI.clearline}#{@prompt}#{line}"
         end
      end

      Out::make_infoline()
      print "#{@prompt}#{Readline::line_buffer}"
      STDOUT.flush
   end


   def completer(line)
      return if !Main.connected

      if line[0] == ?/
         Commands::completer(line)
      else
         Main.contacts.completer(line)
      end
   end

   def save_typed_history
      File.open(Config.account[:typed], 'w') do |f|
         f.puts(Readline::HISTORY.to_a[-300..-1] || Readline::HISTORY.to_a)
      end
   end

   def read_typed_history
      path = Config.account[:typed]
      File.read(path).each { |l| Readline::HISTORY.push(l.chomp) } if File.file?(path)
   end

   def multiline?
      @multiline
   end

   def multiline(enable, first_line="")
      @multiline = enable
      @multilines = []
      if enable
         @multilines.push(first_line) unless first_line.empty?
         prompt("---> ")
      else
         reset_prompt()
      end
   end
end

end

