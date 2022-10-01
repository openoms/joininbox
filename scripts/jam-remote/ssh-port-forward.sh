ssh -L local_port:destination_server_ip:remote_port ssh_server_hostname
28283 28183 62601

joininboxip=192.168.3.190

ssh -L 62601:${joininboxip}:62601 -L 28283:${joininboxip}:28283 -L 28183:${joininboxip}:28183 joinmarket@${joininboxip}