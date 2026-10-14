Wat doet dit script?

    Dual-homed: Het krijgt net als je router 2 netwerkkaarten (eth0 voor bereikbaarheid vanuit je huisnetwerk en eth1 op 10.10.50.x in het Talos-subnet).

    SSH-login en tools via Ansible: De SSH-server, de 'jan'-login (met sudo) en de nieuwste versies van talosctl en kubectl worden geconfigureerd met het Ansible-project in ./ansible (ansible-playbook ansible/site.yml).

    Vanaf deze container kun je nu probleemloos commando's uitvoeren zoals talosctl -n 10.10.50.X health omdat de container zich in exact hetzelfde geïsoleerde subnet bevindt als je Talos-nodes.
