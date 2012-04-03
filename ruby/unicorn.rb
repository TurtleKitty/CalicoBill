
listen "127.0.0.1:16389"
worker_processes 8
working_directory "/home/calicobill/ruby"
pid "/home/calicobill/ruby/tmp/pids/unicorn.pid"
stdout_path "/home/calicobill/ruby/log/unicorn-stdout.log"
stderr_path "/home/calicobill/ruby/log/unicorn-stderr.log"
user "nobody", "nobody"

