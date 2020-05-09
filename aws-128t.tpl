#cloud-config
write_files:
- path: /etc/salt/minion
  content: |
    master:
      - ${conductor-address}
    auth_safemode: True
    autoload_dynamic_modules: False
    enable_legacy_startup_events: False
    master_alive_interval: 30
    master_tries: -1
    ping_interval: 1
    random_reauth_delay: 120
    recon_default: 5000
    recon_max: 30000
    recon_randomize: True
    transport: tcp
    tcp_authentication_retries: -1
    tcp_keepalive_cnt: 3
    tcp_keepalive_idle: 5
    tcp_keepalive_intvl: 10
runcmd:
- systemctl restart salt-minion
