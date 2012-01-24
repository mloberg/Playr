APP_DIR = File.expand_path(File.dirname(__FILE__) + '/../')

worker_processes 2

working_directory APP_DIR

pid "#{APP_DIR}/tmp/web.pid"

listen 8080

before_fork do |server, worker|
  old_pid = "#{APP_DIR}/tmp/web.pid.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end