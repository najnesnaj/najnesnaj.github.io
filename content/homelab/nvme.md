---
title: 'Nvme'
weight: 100
draft: false
---

# nvme

insert M2 into pci

check temperature :
nvme smart-log /dev/nvme0
Smart Log for NVME device:nvme0 namespace-id:ffffffff
critical_warning                        : 0
temperature                             : 33°C (306 Kelvin)
available_spare                         : 100%
available_spare_threshold               : 10%
percentage_used                         : 0%
endurance group critical warning summary: 0
Data Units Read                         : 7,871 (4.03 GB)
Data Units Written                      : 167,622 (85.82 GB)
host_read_commands                      : 152,308
host_write_commands                     : 676,518
controller_busy_time                    : 1
power_cycles                            : 2
power_on_hours                          : 0
unsafe_shutdowns                        : 2
media_errors                            : 0
num_err_log_entries                     : 0
Warning Temperature Time                : 0
Critical Composite Temperature Time     : 0
Temperature Sensor 1           : 33°C (306 Kelvin)
Thermal Management T1 Trans Count       : 0
Thermal Management T2 Trans Count       : 0
Thermal Management T1 Total Time        : 0
Thermal Management T2 Total Time        : 0
