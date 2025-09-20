import std::net::tcp;
import std::net::os;
import std::io;

struct SockAddr_in {
    ushort       sin_family;
    ushort       sin_port;       // Port number (network byte order)
    uint         sin_addr;
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

fn void main() {
    TcpServerSocket server_sock = tcp::listen("127.0.0.1", 8081, 64, net::SocketOption.KEEPALIVE, net::SocketOption.REUSEADDR)!!;
    SockAddr_in *addr_in = (SockAddr_in*)&server_sock.ai_addr_storage;
    InetAddress in_addr = { .ip4.val = htonl(addr_in.sin_addr) };
    io::printfn("listen addr: %s:%d", in_addr, ntohs(addr_in.sin_port));

    while(1) {
        TcpSocket newsock = tcp::accept(&server_sock)!!;
        addr_in = (SockAddr_in*)&newsock.ai_addr_storage;
        in_addr = { .ip4.val = htonl(addr_in.sin_addr) };
        io::printfn("connected from %s:%d", in_addr, ntohs(addr_in.sin_port));
        String str = "Hello\r\n";
        newsock.write(str)!!;
        newsock.close()!!;
    }
}
