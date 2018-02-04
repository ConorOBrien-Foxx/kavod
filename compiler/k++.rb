
# k++
# compiler for the kavod language

def parse_line(line)
    line.gsub(/;.*$/, "").strip.scan(/"[^"]*"|[.:]?\w+|-?\d+/).map { |e|
        if e[0] == '"'
            e[1..-2]
        else
            e
        end
    }
end

def kavod_tokens(program)
    program.scan(/\d+|./)
end

class Temporary
    def initialize(name, source=nil)
        @name = name
        @source = source
    end
    attr_accessor :name, :source
end

class Compiler
    @@call_stack_ref = 9
    def initialize(program, current="main")
        @tokens = []
        @lines = program.lines
        @token_pos = 0
        @i = 0
        @focus = 0
        @labels = {}
        @temp_domains = {}
        @included_libs = []
        @meta = {
            offset: 0,
            current: current
        }
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
            push Temporary.new name, @i
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
    
    def append_lib(name)
        return if @included_libs.include? name
        @included_libs << name
        # p "asdf"
        file_name = "./libs/#{name}.kpp"
        # p file_name
        @lines.concat File.read(file_name).lines
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
            error "I have no idea what you mean by #{str.inspect}"
        end
    end
    
    def line_message(i=@i)
        "#{@meta[:current]}:#{i - @meta[:offset]}"
    end
    
    def error(msg, code=-1, i=@i)
        i += 1
        # p @meta
        STDERR.puts "Error [#{line_message i}]: #{msg}"
        # STDERR.puts "On line: #{@lines[i].inspect}"
        # STDERR.puts "Error [#{@meta[:current]}:#{i}]: #{msg}"
        exit code
    end
    
    def set_label(name, val=@token_pos)
        unless @labels[name].nil?
            error "Duplicate label :#{name}", -4
        end
        @labels[name] = val
    end
    
    def arity_error(source, args, expected)
        error "Unsupported arity #{args.size} for #{source.inspect}; expected #{expected}", -4
    end
    
    def ensure_arity(arity, source, args)
        unless [*arity].include? args.size
            arity_error(source, args, arity)
        end
    end
    
    def exec(line)
        head, *args = parse_line line
        
        return if head.nil?
        
        case head
            # meta
            when ".section"
                ensure_arity 1, head, args
                @meta[:offset] = @i
                @meta[:current] = args[0]
                
                
            when ".lib"
                ensure_arity 1, head, args
                args.each { |a|
                    append_lib a
                }
            
            when "string", "str"
                ensure_arity 2, head, args
                pos, str = args
                str.chars.reverse_each { |c|
                    exec "pushto #{pos} #{c.ord}"
                }
                exec "pushto #{pos} #{str.size}"
            
            # regular
            when "push"
                ensure_arity 1, head, args
                push_data args[0]
            
            when "add"
                case args.size
                    when 0
                        push "+"
                    when 1
                        exec "push #{args[0]}"
                        push "+"
                    else
                        arity_error head, args, 0..1
                end
            
            when "sub"
                case args.size
                    when 0
                        push "-"
                    when 1
                        exec "push #{args[0]}"
                        push "-"
                    else
                        arity_error head, args, 0..1
                end
            
            when "jump"
                ensure_arity 1, head, args
                push_label args[0]
                push "."
            
            when "pop"
                ensure_arity 0..1, head, args
                push "~#{args[0] || @focus}~"
            
            when "drop"
                ensure_arity 0, head, args
                push "><-+"
            
            when "zero"
                ensure_arity 0, head, args
                push "><-"
            
            when "dup"
                ensure_arity 0, head, args
                push "><"
            
            when "dup2"
                ensure_arity 0, head, args
                push ">#{@focus^8}}>#{@focus^8}~>~#{@focus}~<<<"
            
            when "focus"
                case args.size
                    when 0
                        STDERR.puts "Warning: be sure to return to #{@focus}"
                        STDERR.puts "[#{line_message}] #{line}"
                        push "~"
                    when 1
                        if /safe/i === args[0]
                            push "~"
                        else
                            push "#{args[0]}~"
                            @focus = args[0].to_i
                        end
                    else
                        arity_error head, args, 0..1
                end
            
            when "pushto", "pt"
                case args.size
                    when 1
                        push "#{args[0]}}"
                    when 2
                        exec "push #{args[1]}"
                        exec "pushto #{args[0]}"
                    else
                        arity_error head, args, 1..2
                end
            
            when "popfrom", "pf"
                ensure_arity 1, head, args
                push "#{args[0]}{"
            
            when "getc"
                ensure_arity 0, head, args
                push "*"
            
            when "swap"
                ensure_arity 0, head, args
                push "#{@focus^8}}#{@focus^9}}#{@focus^8}{#{@focus^9}{"
            
            when "copy"
                case args.size
                    when 0
                        push ">"
                    when 1
                        exec "push #{args[0]}"
                        push ">"
                        exec "pop"
                    else
                        arity_error head, args, 0..1
                end
            
            when "load"
                ensure_arity 0, head, args
                push "<"
            
            when "debug"
                ensure_arity 0, head, args
                push "`"
            
            when "jif"
                ensure_arity 1, head, args
                push_label args[0]
                push "?"
            
            when "jnt"
                ensure_arity 1, head, args
                temp = get_label "jnt"
                push_label temp
                push "?"
                exec "jump #{args[0]}"
                set_label temp
                
            when "call"
                args[1..-1].each { |a|
                    exec "push #{a}"
                }
                temp = get_label "call"
                push_label temp
                exec "pushto #{@@call_stack_ref}"
                exec "jump #{args[0]}"
                set_label temp
                
            when "ret"
                ensure_arity 0, head, args
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
                set_label $1
            
            else
                error "Non-existant command #{head}", -3
        end
    end
    
    def handle_temps
        @tokens.map! { |tok|
            if tok.is_a? Temporary
                res = @labels[tok.name]
                if res.nil?
                    msg = "Non-existant label :#{tok.name}"
                    if tok.name.start_with? ":"
                        msg += "\nPerhaps you meant :#{tok.name[1..-1]}?"
                    end
                    error msg, -2, tok.source
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

c = Compiler.new prog, ARGV[0]
print c.compile