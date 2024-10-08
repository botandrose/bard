require "open3"
def type(command)
  @stdout, @stderr, @status = Open3.capture3(@env, command)
  if ENV['DEBUG']
    puts '-' * 20
    puts "Executing command: #{command}"
    puts "  Status: #{@status}"
    puts "  Stdout:\n #{@stdout}"
    puts "  Stderr:\n #{@stderr}"
    puts '-' * 20
  end
  @stdout || @stderr
end

def file_append(file_name, contents)
  File.open(file_name, 'ab') { |file| file.puts("\n#{contents}") }
end

def file_inject(file_name, sentinel, string, before_after=:after)
  gsub_file file_name, /(#{Regexp.escape(sentinel)})/mi do |match|
    if before_after == :after
      "#{match}\n#{string}"
    else
      "#{string}\n#{match}"
    end
  end
end

def gsub_file(file_name, regexp, *args, &block)
  content = File.read(file_name).gsub(regexp, *args, &block)
  File.open(file_name, 'wb') { |file| file.write(content) }
end
