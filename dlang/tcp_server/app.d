import vibe.d;
import std.stdio;

void handleTCP(TCPConnection conn) @safe {
    scope(exit) { logInfo("conn close"); conn.close(); }
    while (!conn.empty()) {
        ubyte[1] dst;
        conn.read(dst);
        logInfo("read one bytes: %s", dst);
    }
}

void main() {
    auto listeners = listenTCP(8080, ( TCPConnection conn ) @safe nothrow {
        try { 
            handleTCP(conn);
        } catch (Exception e) {
            logError("Error %s %s", conn.remoteAddress(), e.msg);
            try conn.close();
            catch (Exception e) logError("Error at conn close %s", e.msg);
        }
    });

    foreach(ref lis; listeners) {
        logInfo("Start TCP listeners %s", lis.bindAddress());
    }

    scope(exit) { 
        foreach(ref lis; listeners) {
            logInfo("Stop Listeners %s", lis.bindAddress()); 
            lis.stopListening();
        }
    }

    runEventLoop();
}

