
# k++
# compiler for the kavod language

def parse_line(line)
    line.gsub(/;.*$/, "").strip.split
end

def kavod_tokens(program)
    program.scan(/\d+|./)
end

class Temporary
    def initialize(name)
        @name = name
    end
    attr_accessor :name
end

class Compiler
    @@call_stack_ref = 9
    def initialize(program)
        @tokens = []
        @lines = program.lines
        @token_pos = 0
        @i = 0
        @focus = 0
        @labels = {}
        @temp_domains = {}
        @included_libs = []
        push Temporary.new "eof"
        push "9}"
        # push "9}0 9}"
    end
    
    def number?(x)
        /^\d+$/ === x || x.is_a?(Temporary)
    end
    
    def concatable?(x, y)
        !(number?(x) && number?(y))
    end
    
    def push(tokens)
        tokens = kavod_tokens tokens rescue [*tokens]
        tokens.each { |token|
            top = @tokens.last
            if top.nil?
                @tokens << token
            elsif concatable? top, token
                @tokens << token
            else
                @tokens << " "
                @tokens << token
                @token_pos += 1
            end
            @token_pos += 1
        }
    end
    
    def push_label(name)
        if @labels[name].nil?
            push Temporary.new name
        else
            push @labels[name]
        end
    end
    
    def get_label(domain="temp")
        @temp_domains[domain] ||= 0
        res = domain + @temp_domains[domain].to_s
        @temp_domains[domain] += 1
        res
    end
    
    def push_string(s)
        s.reverse.chars.each { |c|
            push "#{c.ord}"
        }
        push "#{s.size}"
    end
    
    def append_lib(name)
        return if @included_libs.include? name
        @included_libs << name
        @lines.concat File.read("./libs/#{name}.kpp").lines
    end
    
    def push_data(str)
        if /^-?\d+$/ === str
            i = str.to_i
            if i.negative?
                push "0"
                push i.abs.to_s
                push "-"
            else
                push str
            end
        else
            STDERR.puts "I have no idea what you mean by #{str.inspect}"
            exit -1
        end
    end
    
    def exec(line)
        head, *args = parse_line line
        
        return if head.nil?
        
        case head
            when "lib"
                args.each { |a|
                    append_lib a
                }
            when "push"
                push_data args[0]
            when "add"
                case args.size
                    when 0
                        push "+"
                    when 1
                        exec "push #{args[0]}"
                        push "+"
                    else
                        STDERR.puts "Unsupported arity for #{head}: #{args.size}"
                end
            when "sub"
                case args.size
                    when 0
                        push "-"
                    when 1
                        exec "push #{args[0]}"
                        push "-"
                    else
                        STDERR.puts "Unsupported arity for #{head}: #{args.size}"
                end
            when "jump"
                push_label args[0]
                push "."
            when "pop"
                push "~#{@focus}~"
            when "drop"
                push "><-+"
            # when "zero2"
                # push "+><-"
            when "zero"
                push "><-"
                # push "~#{@focus}~"
            when "dup"
                push "><"
            when "dup2"
                push ">#{@focus^8}}>#{@focus^8}~>~#{@focus}~<<<"
            when "focus"
                push "#{args[0]}~"
            when "pushto", "pt"
                case args.size
                    when 1
                        push "#{args[0]}}"
                    when 2
                        exec "push #{args[1]}"
                        exec "pushto #{args[0]}"
                    else
                        STDERR.puts "Unsupported arity for #{head}: #{args.size}"
                end
            when "popfrom", "pf"
                push "#{args[0]}{"
            when "getc"
                push "*"
            when "pst"
                push_string args.join " "
            when "swap"
                push "#{@focus^8}}#{@focus^9}}#{@focus^8}{#{@focus^9}{"
            when "copy"
                push ">"
            when "load"
                push "<"
            when "debug"
                push "`"
            when "jif"
                push_label args[0]
                push "?"
            when "jnt"
                # jif continue
                # jump <label>
                # :continue
                # ...
                # :<label>
                temp = get_label "jnt"
                push_label temp
                push "?"
                exec "jump #{args[0]}"
                @labels[temp] = @token_pos
                
            when "call"
                args[1..-1].each { |a|
                    exec "push #{a}"
                }
                temp = get_label "call"
                push_label temp
                exec "pushto #{@@call_stack_ref}"
                # exec "pushto #{@@call_stack_ref} #{@focus}"
                exec "jump #{args[0]}"
                @labels[temp] = @token_pos
                
            when "ret"
                # exec "popfrom #{@@call_stack_ref}"
                # push "~"
                exec "popfrom #{@@call_stack_ref}"
                push "."
                
            when "putc"
                unless args.empty?
                    args.each { |a|
                        exec "push #{a}"
                        push "#"
                    }
                else
                    push "#"
                end
            when /^:(\w+)/
                @labels[$1] = @token_pos
            else
                STDERR.puts "Error: Non-existant command #{head}"
                exit -3
        end
    end
    
    def handle_temps
        @tokens.map! { |tok|
            if tok.is_a? Temporary
                res = @labels[tok.name]
                if res.nil?
                    STDERR.puts "Error: Non-existant label :#{tok.name}"
                    if tok.name.start_with? ":"
                        STDERR.puts "Perhaps you meant :#{tok.name[1..-1]}?"
                    end
                    exit -2
                end
                res
            else
                tok
            end
        }
    end
    
    def step
        exec @lines[@i]
        @i += 1
    end
    
    def compile
        step while @i < @lines.size
        @labels["eof"] = @token_pos
        handle_temps
        @tokens.join
    end
end

prog = File.read ARGV[0]

c = Compiler.new prog
print c.compile