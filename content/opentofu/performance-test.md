You achieved a combined throughput of **17.4 Gbits/sec** (~2.15 Gigabytes per second).

Your goal of exceeding **10 Gbps** over Thunderbolt 4 is confirmed.

---

## Performance Analysis

* **Throughput:** Moving **20.2 GBytes in 10 seconds** confirms your Thunderbolt networking layer (`thunderbolt-net`) is functioning at full speed.
* **Overhead Expectation:** While Thunderbolt 4 supports up to 40 Gbps PHY link speed, Thunderbolt Networking encapsulates Ethernet packets inside PCIe/Thunderbolt frames. Reaching 17–22 Gbps point-to-point network throughput is typical for Linux peer-to-peer laptop connections due to kernel TCP stack and CPU interrupt handling.
* **TCP Retransmissions (`Retr: 82,860`):** The high number of retransmissions indicates packet drops, likely caused by TCP buffer limits, CPU core saturation, or small MTU sizes under heavy multi-stream load (`-P 8`).

---

## Steps to Maximize Throughput

To reduce packet drops and approach ~22–25 Gbps, apply the following optimizations:

### 1. Increase MTU to 9000 (Jumbo Frames)

Standard Ethernet uses an MTU of 1500 bytes. Enabling Jumbo Frames reduces CPU interrupt overhead significantly.

* **On Proxmox:**
```bash
ip link set dev thunderbolt0 mtu 9000

```


* **On Linux Mint:**
```bash
sudo ip link set dev thunderbolt0 mtu 9000

```



### 2. Increase TCP Socket Buffers

Run these commands on **both** Proxmox and Linux Mint to prevent packet drops at high bitrates:

```bash
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

```

### 3. Re-test Bandwidth

Run `iperf3` again with 4 parallel streams instead of 8:

```bash
iperf3 -c 192.168.99.2 -P 4 -t 10

```

---
