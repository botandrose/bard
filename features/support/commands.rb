def type(command)
  @status, @stdout, @stderr = systemu command
  return unless ENV['DEBUG']
  puts '-' * 20
  puts "Executing command: #{command}"
  puts "  Status: #{@status}"
  puts "  Stdout:\n #{@stdout}"
  puts "  Stderr:\n #{@stderr}"
  puts '-' * 20
end
