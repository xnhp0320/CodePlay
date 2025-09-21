import std::net::tcp;
import std::net::os;
import std::io;
import libc;

extern fn CInt inet_ntop(AIFamily af, SockAddrPtr src, char* dst, Socklen_t dstlen);

struct SockAddr_in {
    ushort       sin_family;
    ushort       sin_port;       // Port number (network byte order)
    uint         sin_addr;
}

struct SockAddr_in6 {
    ushort    sin6_family;
    ushort    sin6_port;
    uint      sin6_flowinfo;
    char[16]  sin6_addr;
    uint      sin6_scope_id;
}


macro ntohs(ushort v) @if(!env::BIG_ENDIAN) {
    return (ushort)(v << 8) | (v >> 8);
}

macro htons(ushort v) @if(!env::BIG_ENDIAN) {
    return (ushort)(v << 8) | (v >> 8);
}

macro ntohl(uint v) @if(!env::BIG_ENDIAN) {
    char a = (char)(v & 0x000000ff);
    char b = (char)((v & 0x0000ff00) >> 8);
    char c = (char)((v & 0x00ff0000) >> 16);
    char d = (char)((v & 0xff000000) >> 24);
    return (a << 24) | (b << 16) | (c << 8) | d;
}

macro htonl(uint v) @if(!env::BIG_ENDIAN) {
    return ntohl(v);
}

macro hton128(char[16] v) @if(!env::BIG_ENDIAN) {
    return ($typefrom(InetAddress.ipv6.typeid))(v);
}

fn ZString inet_n2str(AIFamily af, SockAddrPtr src) {
    tlocal char[32] str;
    inet_ntop(af, (SockAddrPtr)src, &str, 32);
    return (ZString)&str;
}

fn void main() {
    TcpServerSocket server_sock = tcp::listen("::1", 8081, 64,
                                              net::SocketOption.KEEPALIVE,
                                              net::SocketOption.REUSEADDR,
                                              ip_protocol : net::IpProtocol.IPV6)!!;
    SockAddr_in6 *addr_in = (SockAddr_in6*)&server_sock.ai_addr_storage;
    ZString addr = inet_n2str(os::AF_INET6, (SockAddrPtr)&addr_in.sin6_addr);
    io::printfn("listen addr: %s:%d", addr, ntohs(addr_in.sin6_port));

    while(1) {
        TcpSocket newsock = tcp::accept(&server_sock)!!;
        addr_in = (SockAddr_in6*)&newsock.ai_addr_storage;
        addr = inet_n2str(os::AF_INET6, (SockAddrPtr)&addr_in.sin6_addr);
        io::printfn("connected from %s:%d", addr, ntohs(addr_in.sin6_port));
        String str = "Hello\r\n";
        newsock.write(str)!!;
        newsock.close()!!;
    }
}
