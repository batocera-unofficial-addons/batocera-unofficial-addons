#!/usr/bin/env python3
"""
netwatch (phase 2): connection collector + session model, terminal output.

Pure Python stdlib. Talks to the kernel's conntrack over netlink directly,
so no conntrack-tools install is needed. Must run as root.

  python3 netwatch.py                 # live view, on-screen overlay notifications
  python3 netwatch.py --notify es     # EmulationStation popup instead of the overlay
  python3 netwatch.py --once          # one snapshot and exit

NETWATCH_HOME (env var) sets the install/config directory; default below.
"""
import argparse
import base64
import collections
import hmac
import errno
import http.client
import ipaddress
import json
import logging
import logging.handlers
import os
import queue
import re
import socket
import struct
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NETWATCH_HOME = os.environ.get("NETWATCH_HOME", "/userdata/system/add-ons/netwatch")
APP_DIR = os.path.dirname(os.path.abspath(__file__))
OVERLAY_SCRIPT = os.path.join(APP_DIR, "overlay.py")
DASHBOARD_FILE = os.path.join(APP_DIR, "dashboard.html")
LOG = logging.getLogger("netwatch")

# ---------------------------------------------------------------- netlink ---
NETLINK_NETFILTER = 12
NLMSG_ERROR, NLMSG_DONE = 2, 3
NLM_F_REQUEST, NLM_F_DUMP = 0x1, 0x300
NFNL_SUBSYS_CTNETLINK = 1
IPCTNL_MSG_CT_NEW, IPCTNL_MSG_CT_GET, IPCTNL_MSG_CT_DELETE = 0, 1, 2
NF_NETLINK_CONNTRACK_NEW, NF_NETLINK_CONNTRACK_DESTROY = 0x1, 0x4

CTA_TUPLE_ORIG, CTA_TUPLE_REPLY = 1, 2
CTA_COUNTERS_ORIG, CTA_COUNTERS_REPLY = 9, 10
CTA_ID, CTA_TIMESTAMP = 12, 20
CTA_TUPLE_IP, CTA_TUPLE_PROTO = 1, 2
CTA_IP_V4_SRC, CTA_IP_V4_DST, CTA_IP_V6_SRC, CTA_IP_V6_DST = 1, 2, 3, 4
CTA_PROTO_NUM, CTA_PROTO_SRC_PORT, CTA_PROTO_DST_PORT = 1, 2, 3
CTA_COUNTERS_PACKETS, CTA_COUNTERS_BYTES = 1, 2
CTA_TIMESTAMP_START = 1
CTA_PROTOINFO, CTA_PROTOINFO_TCP, CTA_PROTOINFO_TCP_STATE = 4, 1, 1
TCP_CLOSED_STATES = {6, 7, 8}   # LAST_ACK, TIME_WAIT, CLOSE
NLA_TYPE_MASK = 0x3FFF

PROTO_NAMES = {1: "icmp", 6: "tcp", 17: "udp", 58: "icmp6", 132: "sctp"}


def parse_attrs(buf):
    attrs, off = {}, 0
    while off + 4 <= len(buf):
        ln, typ = struct.unpack_from("=HH", buf, off)
        if ln < 4:
            break
        attrs[typ & NLA_TYPE_MASK] = buf[off + 4:off + ln]
        off += (ln + 3) & ~3
    return attrs


def parse_tuple(buf):
    a = parse_attrs(buf)
    ip = parse_attrs(a.get(CTA_TUPLE_IP, b""))
    pr = parse_attrs(a.get(CTA_TUPLE_PROTO, b""))
    if CTA_IP_V4_SRC in ip:
        fam, s, d = socket.AF_INET, ip[CTA_IP_V4_SRC], ip.get(CTA_IP_V4_DST)
    elif CTA_IP_V6_SRC in ip:
        fam, s, d = socket.AF_INET6, ip[CTA_IP_V6_SRC], ip.get(CTA_IP_V6_DST)
    else:
        return None
    if d is None:
        return None
    proto = pr[CTA_PROTO_NUM][0] if CTA_PROTO_NUM in pr else 0
    sport = struct.unpack(">H", pr[CTA_PROTO_SRC_PORT])[0] if CTA_PROTO_SRC_PORT in pr else 0
    dport = struct.unpack(">H", pr[CTA_PROTO_DST_PORT])[0] if CTA_PROTO_DST_PORT in pr else 0
    return proto, socket.inet_ntop(fam, s), socket.inet_ntop(fam, d), sport, dport


def parse_counters(buf):
    if not buf:
        return 0, 0
    a = parse_attrs(buf)
    pk = struct.unpack(">Q", a[CTA_COUNTERS_PACKETS])[0] if CTA_COUNTERS_PACKETS in a else 0
    by = struct.unpack(">Q", a[CTA_COUNTERS_BYTES])[0] if CTA_COUNTERS_BYTES in a else 0
    return pk, by


class Flow:
    __slots__ = ("key", "proto", "osrc", "odst", "osport", "odport",
                 "pkts_o", "pkts_r", "bytes_o", "bytes_r", "has_counters",
                 "start", "seen", "direction", "remote", "lport", "rport", "proc",
                 "state")

    def ingress_bytes(self):
        return self.bytes_o if self.direction == "in" else self.bytes_r

    def egress_bytes(self):
        return self.bytes_r if self.direction == "in" else self.bytes_o

    def packets(self):
        return self.pkts_o + self.pkts_r


def parse_ct(payload):
    if len(payload) < 4:
        return None
    a = parse_attrs(payload[4:])  # skip nfgenmsg
    if CTA_TUPLE_ORIG not in a:
        return None
    t = parse_tuple(a[CTA_TUPLE_ORIG])
    if not t:
        return None
    f = Flow()
    f.proto, f.osrc, f.odst, f.osport, f.odport = t
    f.pkts_o, f.bytes_o = parse_counters(a.get(CTA_COUNTERS_ORIG))
    f.pkts_r, f.bytes_r = parse_counters(a.get(CTA_COUNTERS_REPLY))
    f.has_counters = CTA_COUNTERS_ORIG in a
    f.start = None
    if CTA_TIMESTAMP in a:
        ts = parse_attrs(a[CTA_TIMESTAMP])
        if CTA_TIMESTAMP_START in ts:
            f.start = struct.unpack(">Q", ts[CTA_TIMESTAMP_START])[0] / 1e9
    f.state = None
    if CTA_PROTOINFO in a:
        tcp = parse_attrs(parse_attrs(a[CTA_PROTOINFO]).get(CTA_PROTOINFO_TCP, b""))
        if CTA_PROTOINFO_TCP_STATE in tcp:
            f.state = tcp[CTA_PROTOINFO_TCP_STATE][0]
    if CTA_ID in a:
        f.key = struct.unpack(">I", a[CTA_ID])[0]
    else:
        f.key = (f.proto, f.osrc, f.osport, f.odst, f.odport)
    f.seen = 0.0
    f.direction = f.remote = None
    f.lport = f.rport = 0
    f.proc = None
    return f


def iter_nlmsgs(data):
    off = 0
    while off + 16 <= len(data):
        ln, typ, flags, _seq, _pid = struct.unpack_from("=IHHII", data, off)
        if ln < 16:
            break
        yield typ, flags, data[off + 16:off + ln]
        off += (ln + 3) & ~3


def ct_dump():
    """Full conntrack table (IPv4 + IPv6) as {key: Flow}."""
    s = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_NETFILTER)
    try:
        s.bind((0, 0))
        hdr = struct.pack("=IHHII", 20, (NFNL_SUBSYS_CTNETLINK << 8) | IPCTNL_MSG_CT_GET,
                          NLM_F_REQUEST | NLM_F_DUMP, int(time.time()) & 0xFFFFFFFF, 0)
        s.sendto(hdr + struct.pack("=BBH", socket.AF_UNSPEC, 0, 0), (0, 0))
        flows = {}
        while True:
            data = s.recv(1 << 18)
            for typ, _flags, payload in iter_nlmsgs(data):
                if typ == NLMSG_DONE:
                    return flows
                if typ == NLMSG_ERROR:
                    err = struct.unpack_from("=i", payload)[0]
                    if err:
                        raise OSError(-err, os.strerror(-err))
                    continue
                f = parse_ct(payload)
                if f:
                    flows[f.key] = f
    finally:
        s.close()


def ct_events(handler):
    """Blocking loop: calls handler(kind, flow) for NEW / DESTROY events."""
    s = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, NETLINK_NETFILTER)
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 << 20)
    except OSError:
        pass
    s.bind((0, NF_NETLINK_CONNTRACK_NEW | NF_NETLINK_CONNTRACK_DESTROY))
    while True:
        try:
            data = s.recv(1 << 18)
        except OSError as e:
            if e.errno == errno.ENOBUFS:
                handler("overrun", None)
                continue
            raise
        for typ, _flags, payload in iter_nlmsgs(data):
            if typ >> 8 != NFNL_SUBSYS_CTNETLINK:
                continue
            f = parse_ct(payload)
            if not f:
                continue
            msg = typ & 0xFF
            if msg == IPCTNL_MSG_CT_NEW:
                handler("new", f)
            elif msg == IPCTNL_MSG_CT_DELETE:
                handler("destroy", f)


# ---------------------------------------------------------------- helpers ---
TS_V4 = ipaddress.ip_network("100.64.0.0/10")
TS_V6 = ipaddress.ip_network("fd7a:115c:a1e0::/48")


def fmt_bytes(n):
    for unit in ("B", "K", "M", "G", "T"):
        if n < 1024 or unit == "T":
            return f"{n:.0f}{unit}" if unit == "B" else f"{n:.1f}{unit}"
        n /= 1024


def fmt_dur(sec):
    sec = max(0, int(sec))
    h, rem = divmod(sec, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m:02d}:{s:02d}"


def read_gateways():
    """Default-route next hops from the kernel's main routing table."""
    gws = set()
    try:
        with open("/proc/net/route") as fh:
            next(fh, None)
            for line in fh:
                p = line.split()
                # Iface Destination Gateway Flags ...; RTF_GATEWAY = 0x2
                if len(p) > 3 and p[1] == "00000000" and int(p[3], 16) & 0x2:
                    gws.add(socket.inet_ntoa(struct.pack("<I", int(p[2], 16))))
    except (OSError, ValueError):
        pass
    try:
        with open("/proc/net/ipv6_route") as fh:
            for line in fh:
                p = line.split()
                # dest dest_len src src_len next_hop metric refcnt use flags iface
                if len(p) >= 10 and p[0] == "0" * 32 and p[1] == "00" and p[4] != "0" * 32:
                    gws.add(str(ipaddress.IPv6Address(bytes.fromhex(p[4]))))
    except (OSError, ValueError):
        pass
    return gws


def split_hostport(s):
    host, _, port = s.rpartition(":")
    return host.strip("[]"), int(port) if port.isdigit() else 0


class SunshinePorts:
    """Sunshine derives every port from one base port (default 47989)."""

    def __init__(self, conf_path):
        self.conf_path, self.mtime = conf_path, None
        self.set_base(47989)

    def set_base(self, base):
        self.base = base
        self.https, self.http, self.web = base - 5, base, base + 1
        self.video, self.control, self.audio = base + 9, base + 10, base + 11
        self.rtsp = base + 21
        self.stream = {self.video, self.control, self.audio, self.rtsp}
        self.labels = {self.https: "sunshine-https", self.http: "sunshine-http",
                       self.web: "sunshine-webui", self.rtsp: "sunshine-rtsp",
                       self.video: "sunshine-video", self.control: "sunshine-control",
                       self.audio: "sunshine-audio"}

    def refresh(self):
        try:
            mt = os.stat(self.conf_path).st_mtime
        except OSError:
            return
        if mt == self.mtime:
            return
        self.mtime = mt
        base = 47989
        with open(self.conf_path, errors="replace") as fh:
            for line in fh:
                m = re.match(r"\s*port\s*=\s*(\d+)", line)
                if m:
                    base = int(m.group(1))
        self.set_base(base)


COMMON_PORTS = {22: "ssh", 53: "dns", 67: "dhcp", 68: "dhcp", 123: "ntp",
                137: "netbios-ns", 138: "netbios-dgm", 139: "netbios", 443: "https",
                80: "http", 445: "smb", 1234: "es-api", 1900: "ssdp", 3478: "stun",
                5351: "nat-pmp", 5353: "mdns", 8080: "http-alt", 41641: "tailscale-wg"}

TS_SERVICE_IP = "100.100.100.100"   # MagicDNS / Tailscale's in-node services
BRIDGE_PREFIXES = ("docker", "br-", "virbr", "cni", "podman", "veth", "lxc",
                   "flannel", "cali")


def socket_owners():
    """{(proto, local_port): process name} for every TCP/UDP socket on the host."""
    inode_comm = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/comm") as fh:
                comm = fh.read().strip()
            fds = os.listdir(f"/proc/{pid}/fd")
        except OSError:
            continue
        for fd in fds:
            try:
                link = os.readlink(f"/proc/{pid}/fd/{fd}")
            except OSError:
                continue
            if link.startswith("socket:["):
                inode_comm[link[8:-1]] = comm
    owners = {}
    for proto, names in ((6, ("tcp", "tcp6")), (17, ("udp", "udp6"))):
        for name in names:
            try:
                fh = open(f"/proc/net/{name}")
            except OSError:
                continue
            with fh:
                next(fh, None)
                for line in fh:
                    p = line.split()
                    if len(p) < 10:
                        continue
                    comm = inode_comm.get(p[9])
                    if comm:
                        owners.setdefault((proto, int(p[1].rsplit(":", 1)[1], 16)), comm)
    return owners


# ----------------------------------------------------------- environment ---
class TailscaleClient:
    def __init__(self, sock_path):
        self.sock_path = sock_path

    def status(self):
        class Conn(http.client.HTTPConnection):
            def connect(conn):
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(3)
                s.connect(self.sock_path)
                conn.sock = s

        c = Conn("local-tailscaled.sock", timeout=3)
        try:
            c.request("GET", "/localapi/v0/status",
                      headers={"Host": "local-tailscaled.sock", "Sec-Tailscale": "localapi"})
            r = c.getresponse()
            if r.status != 200:
                raise OSError(f"tailscale localapi HTTP {r.status}")
            return json.loads(r.read())
        finally:
            c.close()


class Env:
    """Everything about the host and its neighbours, refreshed periodically."""

    def __init__(self, args):
        self.args = args
        self.local_ips = {}          # ip -> ifname
        self.local_nets = []         # (network, ifname), excluding tailscale0
        self.ts_peers = {}           # tailnet ip -> peer info
        self.ts_endpoints = set()    # (ip, port) of peer WireGuard endpoints
        self.router_ips = set(args.subnet_router)
        self.gateways = set()        # default-route next hops (IPv4 and IPv6)
        self.ts_error = None
        self.arp = {}                # ip -> mac
        self.aliases = {}            # mac or ip -> name
        self.aliases_mtime = None
        self.sun = SunshinePorts(args.sunshine_conf)
        self.ts = TailscaleClient(args.ts_socket)
        self.rdns = {}               # ip -> (name or None, fetched_at)
        self.rdns_q = queue.Queue(maxsize=256)
        self.owners = {}             # (proto, local port) -> process name
        self.owners_at = 0.0
        self.last_refresh = 0.0
        threading.Thread(target=self._rdns_worker, daemon=True).start()

    # -- refresh -----------------------------------------------------------
    def refresh(self, force=False):
        now = time.time()
        if force or now - self.owners_at >= 5:
            self._refresh_owners(now)
        if not force and now - self.last_refresh < 30:
            self._read_arp()
            return
        self.last_refresh = now
        self._read_addrs()
        self._read_arp()
        self._read_aliases()
        self.sun.refresh()
        self._read_tailscale()

    def _read_addrs(self):
        try:
            out = subprocess.run(["ip", "-o", "addr", "show"], capture_output=True,
                                 text=True, timeout=5).stdout
        except (OSError, subprocess.SubprocessError):
            return
        ips, nets = {}, []
        for line in out.splitlines():
            p = line.split()
            if len(p) < 4 or p[2] not in ("inet", "inet6"):
                continue
            ifname = p[1].rstrip(":").split("@")[0]
            try:
                iface = ipaddress.ip_interface(p[3])
            except ValueError:
                continue
            ips[str(iface.ip)] = ifname
            if ifname != "tailscale0" and not iface.ip.is_loopback:
                nets.append((iface.network, ifname))
        if ips:
            self.local_ips, self.local_nets = ips, nets
        self.gateways = read_gateways()

    def _read_arp(self):
        arp = {}
        try:
            with open("/proc/net/arp") as fh:
                next(fh)
                for line in fh:
                    p = line.split()
                    if len(p) >= 4 and p[3] != "00:00:00:00:00:00":
                        arp[p[0]] = p[3].lower()
        except OSError:
            return
        self.arp = arp

    def _read_aliases(self):
        path = self.args.aliases
        try:
            mt = os.stat(path).st_mtime
        except OSError:
            self.aliases = {}
            return
        if mt == self.aliases_mtime:
            return
        self.aliases_mtime, al = mt, {}
        with open(path, errors="replace") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if "=" in line:
                    k, v = (x.strip() for x in line.split("=", 1))
                    if k and v:
                        al[k.lower()] = v
        self.aliases = al

    def _read_tailscale(self):
        try:
            st = self.ts.status()
        except (OSError, ValueError, http.client.HTTPException) as e:
            self.ts_error = str(e)
            return
        self.ts_error = None
        peers, endpoints = {}, set()
        routers = set(self.args.subnet_router)
        for p in (st.get("Peer") or {}).values():
            name = (p.get("DNSName") or "").split(".")[0] or p.get("HostName") or "?"
            info = {"name": name, "host": p.get("HostName"), "os": p.get("OS"),
                    "direct": bool(p.get("CurAddr")), "relay": p.get("Relay")}
            for ip in p.get("TailscaleIPs") or []:
                peers[ip] = info
            addrs = list(p.get("Addrs") or [])
            if p.get("CurAddr"):
                addrs.append(p["CurAddr"])
            parsed = [split_hostport(a) for a in addrs]
            endpoints.update(parsed)
            # A peer whose advertised routes cover one of our LANs is a subnet
            # router; its LAN-side addresses are where SNAT'd traffic comes from.
            routes = []
            for r in p.get("PrimaryRoutes") or []:
                try:
                    routes.append(ipaddress.ip_network(r, strict=False))
                except ValueError:
                    pass
            if any(rt.overlaps(net) for rt in routes for net, _ in self.local_nets
                   if rt.version == net.version and rt.prefixlen > 0):
                for host, _port in parsed:
                    if self._in_lan(host):
                        routers.add(host)
        self.ts_peers, self.ts_endpoints, self.router_ips = peers, endpoints, routers

    # -- lookups -----------------------------------------------------------
    def _iface_for(self, ip):
        try:
            a = ipaddress.ip_address(ip)
        except ValueError:
            return None
        for net, ifname in self.local_nets:
            if a in net:
                return ifname
        return None

    def _in_lan(self, ip):
        ifname = self._iface_for(ip)
        return ifname is not None and not ifname.startswith(BRIDGE_PREFIXES)

    def is_broadcast(self, a):
        return a.version == 4 and any(
            a == net.broadcast_address for net, _ in self.local_nets
            if net.version == 4 and net.prefixlen < 31)

    def classify(self, ip):
        a = ipaddress.ip_address(ip)
        if a in TS_V4 or a in TS_V6:
            peer = self.ts_peers.get(ip)
            if not peer:
                return "tailnet"
            return "tailnet-direct" if peer["direct"] else "tailnet-relay"
        if ip in self.gateways:
            return "gateway"
        if ip in self.router_ips:
            return "subnet-router"
        ifname = self._iface_for(ip)
        if ifname:
            return "container" if ifname.startswith(BRIDGE_PREFIXES) else "lan"
        if a.is_link_local:
            return "link-local"
        if a.is_private:
            return "private"
        return "internet"

    def _refresh_owners(self, now):
        self.owners_at = now
        try:
            self.owners = socket_owners()
        except OSError:
            pass

    def owner(self, f):
        """Owning process of a flow's local socket. A brand-new socket may not
        be in the map yet, so a miss triggers a rescan (at most every 2s)."""
        key = (f.proto, f.lport)
        proc = self.owners.get(key)
        if proc is None and time.time() - self.owners_at > 2:
            self._refresh_owners(time.time())
            proc = self.owners.get(key)
        return proc

    def is_transport(self, f):
        """Tailscale's own plumbing: the WireGuard tunnel, STUN, DERP, control
        plane, and MagicDNS. Identified by the owning process, not the port."""
        if f.proc == "tailscaled" or f.remote == TS_SERVICE_IP:
            return True
        return f.proto == 17 and (f.lport == self.args.wg_port
                                  or (f.remote, f.rport) in self.ts_endpoints)

    def name_for(self, ip):
        # An alias is an explicit choice, so it beats every other name source.
        mac = self.arp.get(ip)
        for k in (mac, ip.lower()):
            if k and k in self.aliases:
                return self.aliases[k], "alias"
        peer = self.ts_peers.get(ip)
        if peer:
            return peer["name"], "tailscale"
        cached = self.rdns.get(ip)
        if cached is None or time.time() - cached[1] > 600:
            if cached is None:
                self.rdns[ip] = (None, time.time())  # placeholder, avoid requeue
            try:
                self.rdns_q.put_nowait(ip)
            except queue.Full:
                pass
        elif cached[0]:
            return cached[0], "rdns"
        return ip, "ip"

    def _rdns_worker(self):
        while True:
            ip = self.rdns_q.get()
            try:
                name = socket.gethostbyaddr(ip)[0]
            except (OSError, UnicodeError):
                name = None
            self.rdns[ip] = (name, time.time())

    def port_label(self, port):
        return self.sun.labels.get(port) or COMMON_PORTS.get(port, "")


# ---------------------------------------------------------------- tracker ---
class Device:
    def __init__(self, ip, since):
        self.ip = ip
        self.first_seen = since
        self.exact = True
        self.flows = {}
        self.empty_since = None
        self.closed_in = self.closed_out = 0
        self.stream_since = None
        self.stream_pkts = 0
        self.stream_change = 0.0
        self.rate_in = self.rate_out = 0.0     # bytes/s over the last interval
        self.rate_t = None
        self.rate_prev = (0, 0)

    def bytes_in(self):
        return self.closed_in + sum(f.ingress_bytes() for f in self.flows.values())

    def bytes_out(self):
        return self.closed_out + sum(f.egress_bytes() for f in self.flows.values())


class Tracker:
    DEVICE_GRACE = 30      # s with zero flows before a device counts as gone
    STREAM_IDLE = 15       # s of no stream packets before a Sunshine session ends
    STREAM_MIN = 20        # s after start before we're allowed to call it ended
    NOTIFY_COOLDOWN = 30   # s; a reconnect inside this window doesn't re-notify

    def __init__(self, env, args, notifier):
        self.env, self.args, self.notify = env, args, notifier
        self.lock = threading.Lock()
        self.devices = {}
        self.flow_dev = {}
        self.history = collections.deque(maxlen=30)
        self.events = collections.deque(maxlen=60)
        self.last_stream_end = {}
        self.tombstones = set()   # conntrack keys we've retired but the kernel still lists
        self.bootstrapping = True

    def log(self, text):
        now = time.time()
        self.events.append((now, text))
        # With the terminal screen up and no log file, a stderr line would
        # scribble over the screen, so events only go to the screen then.
        if self.args.no_tui or self.args.log_file:
            LOG.info(text)

    def _orient(self, f):
        local = self.env.local_ips
        s_local, d_local = f.osrc in local, f.odst in local
        if s_local and not d_local:
            f.direction, f.remote, f.lport, f.rport = "out", f.odst, f.osport, f.odport
        elif d_local and not s_local:
            f.direction, f.remote, f.lport, f.rport = "in", f.osrc, f.odport, f.osport
        else:
            return False
        a = ipaddress.ip_address(f.remote)
        if (a.is_multicast or a.is_loopback or f.remote == "255.255.255.255"
                or self.env.is_broadcast(a)):
            return False
        if (f.remote in self.env.gateways and not self.args.show_gateway
                and not (f.direction == "in" and f.lport in self.env.sun.labels)):
            # The router's own DNS / NAT-PMP / UPnP chatter isn't a device
            # connecting. Sunshine traffic from it is kept: with a port forward
            # and hairpin NAT, a real stream can arrive from the router's IP.
            return False
        f.proc = self.env.owner(f)
        if self.args.inbound_only and f.direction == "out":
            return False
        if not self.args.show_transport and self.env.is_transport(f):
            return False
        return True

    def upsert(self, f, now):
        if f.key in self.tombstones:
            return
        dev = self.flow_dev.get(f.key)
        if dev is not None:
            cur = dev.flows[f.key]
            if f.has_counters:
                cur.pkts_o, cur.pkts_r = f.pkts_o, f.pkts_r
                cur.bytes_o, cur.bytes_r = f.bytes_o, f.bytes_r
                cur.has_counters = True
            if f.start and not cur.start:
                cur.start = f.start
            if f.state is not None:
                cur.state = f.state
            if cur.proc is None:
                cur.proc = self.env.owner(cur)
                # Owner just became known; it may turn out to be Tailscale plumbing.
                if cur.proc and not self.args.show_transport and self.env.is_transport(cur):
                    self._retire(f.key, now, silent=True)
                    return
            if cur.proto == 6 and cur.state in TCP_CLOSED_STATES:
                self._retire(f.key, now)   # bytes roll into the device totals
                return
            cur.seen = now
            return
        if not self._orient(f):
            return
        if f.proto == 6 and f.state in TCP_CLOSED_STATES:
            self.tombstones.add(f.key)     # already dead when first seen
            return
        f.seen = now
        dev = self.devices.get(f.remote)
        if dev is None:
            dev = Device(f.remote, f.start or now)
            # Without a kernel timestamp, a flow found at startup only tells us
            # "connected at least since netwatch started".
            dev.exact = bool(f.start) or not self.bootstrapping
            self.devices[f.remote] = dev
            path = self.env.classify(f.remote)
            if path != "internet" and not self.bootstrapping:
                self.log(f"+ {self.env.name_for(f.remote)[0]} ({f.remote}, {path})")
        elif f.start and f.start < dev.first_seen:
            dev.first_seen = f.start
            dev.exact = True
        dev.flows[f.key] = f
        dev.empty_since = None
        self.flow_dev[f.key] = dev
        sun = self.env.sun
        if f.direction == "in" and dev.stream_since is None and (
                (f.proto == 6 and f.lport == sun.rtsp)
                or (f.proto == 17 and f.lport == sun.video)):
            self._stream_start(dev, now)

    def remove(self, key, now, final=None):
        dev = self.flow_dev.pop(key, None)
        if dev is None:
            return
        f = dev.flows.pop(key)
        if final is not None and final.has_counters:
            f.pkts_o, f.pkts_r, f.bytes_o, f.bytes_r = (final.pkts_o, final.pkts_r,
                                                        final.bytes_o, final.bytes_r)
        dev.closed_in += f.ingress_bytes()
        dev.closed_out += f.egress_bytes()
        if not dev.flows:
            dev.empty_since = now

    def _retire(self, key, now, silent=False):
        """Stop tracking a flow the kernel still lists. silent=True means it
        should never have been shown: discard it without counting its bytes."""
        self.tombstones.add(key)
        dev = self.flow_dev.get(key)
        if dev is None:
            return
        if not silent:
            self.remove(key, now)
            return
        del self.flow_dev[key]
        dev.flows.pop(key, None)
        if not dev.flows:
            if dev.closed_in == 0 and dev.closed_out == 0 and dev.stream_since is None:
                del self.devices[dev.ip]
            else:
                dev.empty_since = now

    def reconcile(self, dump, now):
        self.tombstones &= dump.keys()
        for f in dump.values():
            self.upsert(f, now)
        for key, dev in list(self.flow_dev.items()):
            if key not in dump and now - dev.flows[key].seen > 3:
                self.remove(key, now)

    def on_event(self, kind, f):
        now = time.time()
        with self.lock:
            if kind == "new":
                self.upsert(f, now)
            elif kind == "destroy":
                self.remove(f.key, now, f)
                self.tombstones.discard(f.key)
            elif kind == "overrun":
                self.log("! event buffer overrun; next dump will reconcile")

    # -- sunshine sessions -------------------------------------------------
    def _stream_flows(self, dev):
        return [f for f in dev.flows.values()
                if f.direction == "in" and f.lport in self.env.sun.stream]

    def _stream_start(self, dev, now):
        dev.stream_since = now
        dev.stream_change = now
        dev.stream_pkts = sum(f.packets() for f in self._stream_flows(dev))
        name = self.env.name_for(dev.ip)[0]
        if self.bootstrapping:
            self.log(f"~ Sunshine stream already active: {name}")
            return
        self.log(f"> Sunshine stream started: {name} ({dev.ip})")
        if now - self.last_stream_end.get(dev.ip, 0) > self.NOTIFY_COOLDOWN:
            self.notify(f"{name} has connected")

    def tick(self, now):
        for ip, dev in list(self.devices.items()):
            bi, bo = dev.bytes_in(), dev.bytes_out()
            if dev.rate_t is not None and now > dev.rate_t:
                dt = now - dev.rate_t
                dev.rate_in = max(0.0, (bi - dev.rate_prev[0]) / dt)
                dev.rate_out = max(0.0, (bo - dev.rate_prev[1]) / dt)
            dev.rate_t, dev.rate_prev = now, (bi, bo)
            if dev.stream_since is not None:
                flows = self._stream_flows(dev)
                pk = sum(f.packets() for f in flows)
                if pk != dev.stream_pkts:
                    dev.stream_pkts, dev.stream_change = pk, now
                counted = bool(flows) and all(f.has_counters for f in flows)
                idle = now - dev.stream_change
                if now - dev.stream_since > self.STREAM_MIN and (
                        (not flows and idle > self.STREAM_IDLE)
                        or (counted and idle > self.STREAM_IDLE)):
                    dur = dev.stream_change - dev.stream_since
                    self.log(f"< Sunshine stream ended: {self.env.name_for(ip)[0]}"
                             f" after {fmt_dur(dur)}")
                    self.last_stream_end[ip] = now
                    dev.stream_since = None
            if not dev.flows and dev.empty_since and now - dev.empty_since > self.DEVICE_GRACE:
                name, _ = self.env.name_for(ip)
                path = self.env.classify(ip)
                self.history.appendleft((now, name, ip, path, dev.empty_since - dev.first_seen,
                                         dev.bytes_in(), dev.bytes_out()))
                if path != "internet":
                    self.log(f"- {name} ({ip}) gone after {fmt_dur(dev.empty_since - dev.first_seen)}")
                del self.devices[ip]

    # -- view --------------------------------------------------------------
    def flow_groups(self, d):
        """Flows grouped by (protocol, direction, service port, process), with a
        connection count and the range of peer-side ephemeral ports."""
        groups = {}
        for f in d.flows.values():
            port = f.lport if f.direction == "in" else f.rport
            peer = f.rport if f.direction == "in" else f.lport
            g = groups.setdefault((f.proto, f.direction, port, f.proc or "-"),
                                  {"n": 0, "in": 0, "out": 0, "peers": []})
            g["n"] += 1
            g["in"] += f.ingress_bytes()
            g["out"] += f.egress_bytes()
            g["peers"].append(peer)
        result = []
        for (proto, direction, port, proc), g in sorted(groups.items(),
                                                        key=lambda kv: (kv[0][1], kv[0][2])):
            peers = g["peers"]
            result.append({
                "proto": PROTO_NAMES.get(proto, str(proto)), "dir": direction,
                "side": "local" if direction == "in" else "remote", "port": port,
                "service": self.env.port_label(port), "proc": proc, "count": g["n"],
                "peers": str(peers[0]) if len(peers) == 1 else f"{min(peers)}-{max(peers)}",
                "in": g["in"], "out": g["out"]})
        return result

    def _render_groups(self, d):
        lines = []
        for g in self.flow_groups(d):
            count = f"x{g['count']}" if g["count"] > 1 else ""
            lines.append(f"    {g['proto']:5} {g['dir']:3} {g['side']}:{g['port']:<5} "
                         f"{g['service']:16} {g['proc'][:12]:12} {count:5} "
                         f"peer:{g['peers']:12} in {fmt_bytes(g['in']):>7}  "
                         f"out {fmt_bytes(g['out']):>7}")
        return lines

    def snapshot(self, now):
        """Everything the web dashboard shows, as plain JSON-able data."""
        env = self.env
        devices = []
        for d in self.devices.values():
            name, src = env.name_for(d.ip)
            peer = env.ts_peers.get(d.ip) or {}
            devices.append({
                "ip": d.ip, "name": name, "name_source": src, "route": env.classify(d.ip),
                "mac": env.arp.get(d.ip), "os": peer.get("os"),
                "first_seen": d.first_seen, "exact": d.exact, "idle": not d.flows,
                "bytes_in": d.bytes_in(), "bytes_out": d.bytes_out(),
                "rate_in": round(d.rate_in), "rate_out": round(d.rate_out),
                "streaming_since": d.stream_since if d.stream_since is not None else None,
                "flows": self.flow_groups(d)})
        return {
            "now": now, "host": socket.gethostname(),
            "local_ips": sorted(ip for ip in env.local_ips if not ip.startswith(("127.", "::1"))),
            "sunshine_base": env.sun.base, "tailscale_error": env.ts_error,
            "counters": read_sysctl("nf_conntrack_acct") == "1",
            "devices": devices,
            "history": [{"t": t, "name": n, "ip": ip, "route": r, "duration": dur,
                         "bytes_in": bi, "bytes_out": bo}
                        for t, n, ip, r, dur, bi, bo in self.history],
            "events": [{"t": t, "text": text} for t, text in reversed(self.events)]}

    def render(self, now):
        env = self.env
        order = {"tailnet-direct": 0, "tailnet-relay": 0, "tailnet": 0, "subnet-router": 1,
                 "lan": 2, "gateway": 2, "container": 3, "private": 3, "link-local": 3, "internet": 4}
        devs = sorted(self.devices.values(),
                      key=lambda d: (d.stream_since is None, order.get(env.classify(d.ip), 5),
                                     d.first_seen))
        acct = read_sysctl("nf_conntrack_acct")
        out = [f"netwatch  {time.strftime('%H:%M:%S')}  devices={len(devs)} "
               f"flows={len(self.flow_dev)}  sunshine-base={env.sun.base}  "
               f"tailscale={'ok' if not env.ts_error else 'ERR ' + env.ts_error}  "
               f"acct={'on' if acct == '1' else 'OFF'}", ""]
        out.append(f"{'DEVICE':34} {'PATH':15} {'SINCE':9} {'DURATION':9} "
                   f"{'IN':>8} {'OUT':>8}  NOTE")
        for d in devs:
            name, _src = env.name_for(d.ip)
            if name == d.ip:
                label = d.ip
            else:
                room = max(8, 34 - len(d.ip) - 3)
                label = f"{name[:room]} ({d.ip})"
            note = f"STREAMING {fmt_dur(now - d.stream_since)}" if d.stream_since else ""
            if not d.flows:
                note = (note + " idle").strip()
            mark = "" if d.exact else ">"
            since = mark + time.strftime('%H:%M:%S', time.localtime(d.first_seen))
            out.append(f"{label[:34]:34} {env.classify(d.ip):15} {since:9} "
                       f"{mark + fmt_dur(now - d.first_seen):9} {fmt_bytes(d.bytes_in()):>8} "
                       f"{fmt_bytes(d.bytes_out()):>8}  {note}")
            if self.args.flows and not self.args.raw_flows:
                out += self._render_groups(d)
            elif self.args.flows:
                for f in sorted(d.flows.values(), key=lambda x: (x.direction, x.lport)):
                    arrow = "<-" if f.direction == "in" else "->"
                    svc = env.port_label(f.lport if f.direction == "in" else f.rport)
                    out.append(f"    {PROTO_NAMES.get(f.proto, f.proto):5} {f.direction:3} "
                               f"local:{f.lport:<5} {arrow} remote:{f.rport:<5} {svc:16} "
                               f"{(f.proc or '-')[:12]:12} "
                               f"in {fmt_bytes(f.ingress_bytes()):>7}  "
                               f"out {fmt_bytes(f.egress_bytes()):>7}")
        if any(not d.exact for d in devs):
            out += ["", "> = connected before netwatch started (true start unknown)"]
        if self.history:
            out += ["", "RECENTLY DISCONNECTED"]
            for t, name, ip, path, dur, bi, bo in list(self.history)[:5]:
                out.append(f"  {time.strftime('%H:%M:%S', time.localtime(t))}  "
                           f"{name[:30]:30} {path:15} {fmt_dur(dur)}  "
                           f"in {fmt_bytes(bi)} out {fmt_bytes(bo)}")
        if self.events:
            out += ["", "EVENTS"]
            for t, text in list(self.events)[-12:]:
                out.append(f"  {time.strftime('%H:%M:%S', time.localtime(t))}  {text}")
        return "\n".join(out)


# ------------------------------------------------------------------- web ---
class WebServer:
    """Serves dashboard.html, a JSON snapshot, and a Server-Sent Events stream
    that pushes a fresh snapshot every collection interval."""

    def __init__(self, args):
        self.args = args
        self.cond = threading.Condition()
        self.body = b"{}"
        self.version = 0
        self.auth = None
        creds = args.web_auth or os.environ.get("NETWATCH_WEB_AUTH")
        if creds:
            self.auth = "Basic " + base64.b64encode(creds.encode()).decode()

    def publish(self, snap):
        body = json.dumps(snap, separators=(",", ":")).encode()
        with self.cond:
            self.body, self.version = body, self.version + 1
            self.cond.notify_all()

    def start(self):
        web = self

        class Handler(BaseHTTPRequestHandler):
            server_version = "netwatch"

            def log_message(self, *_a):
                pass

            def _authorized(self):
                if web.auth is None:
                    return True
                if hmac.compare_digest(self.headers.get("Authorization", ""), web.auth):
                    return True
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Basic realm="netwatch"')
                self.end_headers()
                return False

            def _send(self, code, ctype, body):
                self.send_response(code)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                if not self._authorized():
                    return
                path = self.path.split("?", 1)[0]
                if path in ("/", "/index.html"):
                    try:
                        with open(DASHBOARD_FILE, "rb") as fh:
                            self._send(200, "text/html; charset=utf-8", fh.read())
                    except OSError:
                        self._send(500, "text/plain", b"dashboard.html is missing; "
                                   b"put it next to netwatch.py")
                elif path == "/api/state":
                    with web.cond:
                        body = web.body
                    self._send(200, "application/json", body)
                elif path == "/api/events":
                    self._stream()
                elif path == "/healthz":
                    self._send(200, "text/plain", b"ok")
                else:
                    self._send(404, "text/plain", b"not found")

            def _stream(self):
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Cache-Control", "no-store")
                self.send_header("X-Accel-Buffering", "no")
                self.end_headers()
                seen = -1
                try:
                    while True:
                        with web.cond:
                            if web.version == seen:
                                web.cond.wait(timeout=15)
                            version, body = web.version, web.body
                        if version == seen:
                            self.wfile.write(b": keepalive\n\n")
                        else:
                            seen = version
                            self.wfile.write(b"data: " + body + b"\n\n")
                        self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError, OSError):
                    return

        httpd = ThreadingHTTPServer((self.args.web_bind, self.args.web_port), Handler)
        httpd.daemon_threads = True
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        return httpd


# -------------------------------------------------------------- notifier ---
class Notifier:
    """overlay: X11 banner (overlay.py, own process), falling back to ES /notify
    if it can't start. es: ES popup only. print: log line only."""

    def __init__(self, args, tracker_log=None):
        self.mode = args.notify
        self.display = args.display
        self.duration = args.overlay_duration
        self.style = args.overlay_style
        self.scale = args.overlay_scale
        self.log = tracker_log or (lambda _t: None)

    def __call__(self, text):
        self.log(f"* NOTIFY: {text}")
        if self.mode == "es":
            threading.Thread(target=self._es, args=(text,), daemon=True).start()
        elif self.mode == "overlay":
            threading.Thread(target=self._overlay, args=(text,), daemon=True).start()

    def _overlay(self, text):
        if not os.path.exists(OVERLAY_SCRIPT):
            self.log(f"! overlay.py not found next to netwatch.py; using ES popup")
            return self._es(text)
        env = dict(os.environ, DISPLAY=self.display)
        try:
            proc = subprocess.Popen([sys.executable, OVERLAY_SCRIPT,
                                     "--duration", str(self.duration),
                                     "--style", self.style, "--scale", str(self.scale),
                                     text], env=env,
                                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        except OSError as e:
            self.log(f"! overlay failed to start: {e}; using ES popup")
            return self._es(text)
        try:
            _out, err = proc.communicate(timeout=self.duration + 10)
        except subprocess.TimeoutExpired:
            proc.kill()
            self.log("! overlay hung and was killed")
            return
        if proc.returncode != 0:
            msg = (err or b"").decode(errors="replace").strip().splitlines()
            self.log(f"! overlay exit {proc.returncode} ({msg[-1] if msg else 'no output'})"
                     "; using ES popup")
            self._es(text)

    def _es(self, text):
        try:
            c = http.client.HTTPConnection("127.0.0.1", 1234, timeout=3)
            c.request("POST", "/notify", body=text.encode(),
                      headers={"Content-Type": "application/x-www-form-urlencoded"})
            c.getresponse().read()
            c.close()
        except (OSError, http.client.HTTPException) as e:
            self.log(f"! ES notify failed: {e}")


# ------------------------------------------------------------------ setup ---
def read_sysctl(name):
    try:
        with open(f"/proc/sys/net/netfilter/{name}") as fh:
            return fh.read().strip()
    except OSError:
        return None


def prepare_kernel():
    if not os.path.isdir("/sys/module/nf_conntrack_netlink"):
        try:
            subprocess.run(["modprobe", "nf_conntrack_netlink"], capture_output=True, timeout=10)
        except (OSError, subprocess.SubprocessError) as e:
            LOG.warning(f"could not load nf_conntrack_netlink: {e}")
    for name in ("nf_conntrack_acct", "nf_conntrack_timestamp", "nf_conntrack_events"):
        if read_sysctl(name) == "1":
            continue
        try:
            with open(f"/proc/sys/net/netfilter/{name}", "w") as fh:
                fh.write("1")
            LOG.info(f"enabled {name}")
        except OSError as e:
            LOG.warning(f"could not enable {name}: {e}")


def setup_logging(args):
    """Log to a size-rotated file (--log-file) or, without one, to stderr.
    Uncaught exceptions in any thread are logged too, so a crash leaves its
    traceback in the rotated log rather than an unbounded service log."""
    LOG.setLevel(logging.INFO)
    LOG.propagate = False
    if args.log_file:
        os.makedirs(os.path.dirname(os.path.abspath(args.log_file)), exist_ok=True)
        # maxBytes=0 means never rotate; backupCount is >= 1 (checked in parse_args)
        handler = logging.handlers.RotatingFileHandler(
            args.log_file, maxBytes=args.log_max_bytes, backupCount=args.log_keep,
            encoding="utf-8")
    else:
        handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter("%(asctime)s %(message)s", "%Y-%m-%d %H:%M:%S"))
    LOG.addHandler(handler)

    def crash(exc_type, exc, tb):
        if issubclass(exc_type, KeyboardInterrupt):
            return sys.__excepthook__(exc_type, exc, tb)
        LOG.critical("netwatch crashed", exc_info=(exc_type, exc, tb))

    sys.excepthook = crash
    threading.excepthook = lambda a: LOG.error(
        f"thread {a.thread.name if a.thread else '?'} crashed",
        exc_info=(a.exc_type, a.exc_value, a.exc_traceback))


def parse_args():
    ap = argparse.ArgumentParser(description="Connection monitor for Batocera + Sunshine")
    ap.add_argument("--sunshine-conf",
                    default="/userdata/system/add-ons/sunshine/.config/sunshine/sunshine.conf")
    ap.add_argument("--ts-socket", default="/var/run/tailscale/tailscaled.sock")
    ap.add_argument("--aliases", default=os.path.join(NETWATCH_HOME, "aliases.conf"),
                    help="lines of 'mac-or-ip = friendly name'")
    ap.add_argument("--subnet-router", action="append", default=[],
                    help="LAN IP of a subnet router (repeatable; auto-detected when possible)")
    ap.add_argument("--wg-port", type=int, default=41641,
                    help="tailscaled's WireGuard UDP port (hidden as transport)")
    ap.add_argument("--notify", choices=("overlay", "es", "print"), default="overlay")
    ap.add_argument("--overlay-duration", type=float, default=5.0)
    ap.add_argument("--overlay-style", choices=("outline", "solid"), default="outline")
    ap.add_argument("--overlay-scale", type=float, default=1.1,
                    help="banner size multiplier (1.0 = 26px text at 1440p)")
    ap.add_argument("--web-port", type=int, default=8686, help="dashboard port; 0 disables it")
    ap.add_argument("--web-bind", default="0.0.0.0",
                    help="address to serve the dashboard on (e.g. your tailnet IP only)")
    ap.add_argument("--web-auth", default=None,
                    help="user:password for the dashboard (or env NETWATCH_WEB_AUTH)")
    ap.add_argument("--no-tui", action="store_true",
                    help="no terminal screen; print events as log lines (for the service)")
    ap.add_argument("--log-file", default=None,
                    help="write the log here, rotating by size (default: stderr)")
    ap.add_argument("--log-max-bytes", type=int, default=1048576,
                    help="rotate the log once it reaches this size; 0 never rotates")
    ap.add_argument("--log-keep", type=int, default=3,
                    help="rotated logs to keep (<log>.1 is newest); at least 1")
    ap.add_argument("--display", default=os.environ.get("DISPLAY") or ":0")
    ap.add_argument("--interval", type=float, default=2.0)
    ap.add_argument("--no-flows", dest="flows", action="store_false",
                    help="hide per-flow port detail")
    ap.add_argument("--raw-flows", action="store_true",
                    help="one line per connection instead of grouping by service")
    ap.add_argument("--inbound-only", action="store_true")
    ap.add_argument("--show-gateway", action="store_true",
                    help="show the router's own traffic (DNS, NAT-PMP, UPnP)")
    ap.add_argument("--show-transport", action="store_true",
                    help="show Tailscale's own plumbing (WireGuard, STUN, DERP, MagicDNS)")
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()
    if args.log_keep < 1:
        # RotatingFileHandler silently stops rotating when backupCount is 0,
        # which would let the log grow forever. Refuse rather than surprise.
        ap.error("--log-keep must be at least 1 (use --log-max-bytes 0 to disable rotation)")
    if args.log_max_bytes < 0:
        ap.error("--log-max-bytes can't be negative")
    return args


def main():
    args = parse_args()
    setup_logging(args)
    if os.geteuid() != 0:
        LOG.critical("netwatch must run as root (conntrack over netlink needs CAP_NET_ADMIN)")
        sys.exit(1)
    os.makedirs(NETWATCH_HOME, exist_ok=True)
    prepare_kernel()

    env = Env(args)
    env.refresh(force=True)
    tracker = Tracker(env, args, None)
    tracker.notify = Notifier(args, tracker.log)

    try:
        dump = ct_dump()
    except OSError as e:
        LOG.critical(f"conntrack dump failed: {e}")
        sys.exit(1)
    with tracker.lock:
        tracker.reconcile(dump, time.time())
        tracker.bootstrapping = False

    if args.once:
        time.sleep(0.5)  # give reverse DNS a moment
        print(tracker.render(time.time()))
        return

    def event_loop():
        while True:
            try:
                ct_events(tracker.on_event)
            except OSError as e:
                with tracker.lock:
                    tracker.log(f"! event socket error: {e}; retrying")
                time.sleep(5)

    threading.Thread(target=event_loop, daemon=True).start()
    web = None
    if args.web_port:
        web = WebServer(args)
        try:
            web.start()
            tracker.log(f"~ dashboard on http://{args.web_bind}:{args.web_port}/")
        except OSError as e:
            tracker.log(f"! dashboard could not start on port {args.web_port}: {e}")
            web = None
    tty = sys.stdout.isatty()
    while True:
        time.sleep(args.interval)
        env.refresh()
        try:
            dump = ct_dump()
        except OSError as e:
            with tracker.lock:
                tracker.log(f"! dump failed: {e}")
            continue
        now = time.time()
        with tracker.lock:
            tracker.reconcile(dump, now)
            tracker.tick(now)
            snap = tracker.snapshot(now) if web else None
            screen = None if args.no_tui else tracker.render(now)
        if web:
            web.publish(snap)
        if screen is not None:
            print(("\x1b[H\x1b[2J" if tty else "\n") + screen, flush=True)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass