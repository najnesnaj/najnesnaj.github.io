Wat doet dit script?

    Dual-homed: Het krijgt net als je router 2 netwerkkaarten (eth0 voor bereikbaarheid vanuit je huisnetwerk en eth1 op 10.10.50.x in het Talos-subnet).

    Tools automatisch geïnstalleerd: Tijdens de eerste boot downloadt en installeert het automatisch de meest recente versies van zowel talosctl als kubectl.

    Vanaf deze container kun je nu probleemloos commando's uitvoeren zoals talosctl -n 10.10.50.X health omdat de container zich in exact hetzelfde geïsoleerde subnet bevindt als je Talos-nodes.
