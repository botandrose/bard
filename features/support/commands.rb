def type(command)
  @status, @stdout, @stderr = systemu command
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
