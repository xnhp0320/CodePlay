import std::net::tcp;
import std::net::os;
import std::io;

struct SockAddr_in (Printable) {
    char         addr_len;
    char         family;
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

extern fn CInt inet_ntop(AIFamily af, void* src, char* dst, Socklen_t dstlen);
extern fn CInt getsockname(CInt socket, void *sockaddr, Socklen_t *len); 

fn ZString inet_n2str(AIFamily af, void* src) {
    tlocal char[32] str;
    inet_ntop(af, src, &str, 32);
    return (ZString)&str;
}

fn usz? SockAddr_in.to_format(&self, Formatter *formatter) @dynamic {
    ZString zstr = inet_n2str(os::AF_INET, (void*)&self.sin_addr);
    return formatter.printf("%s:%d family %d", zstr.str_view(), htons(self.sin_port), self.family);
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

fn void main() {
    TcpServerSocket server_sock = tcp::listen("127.0.0.1", 0, 64,
                                              net::SocketOption.KEEPALIVE,
                                              net::SocketOption.REUSEADDR)!!;

    SockAddr_in *addr_in = (SockAddr_in*)&server_sock.ai_addr_storage;
    io::printfn("listen addr: %s", addr_in);
    io::printfn("fd is %d", server_sock.sock);
    SockAddr_in localaddr;
    Socklen_t len;
    getsockname(server_sock.sock, &localaddr, &len);
    io::printfn("listen addr: %s %d %d", localaddr, len, localaddr.family);
    io::printfn("af_inet %d", os::AF_INET);

    while(1) {
        TcpSocket newsock = tcp::accept(&server_sock)!!;
        addr_in = (SockAddr_in*)&newsock.ai_addr_storage;
        io::printfn("connected from %s", addr_in);
        String str = "Hello\r\n";
        newsock.write(str)!!;
        newsock.close()!!;
    }
}
