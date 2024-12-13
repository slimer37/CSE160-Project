module ChatAppServerP {
    provides interface ChatAppServer;

    uses interface TcpServer;
}

implementation {
    command error_t ChatAppServer.host(socket_port_t port) {
        call TcpServer.startServer(port);
    }

    event void TcpServer.processMessage(uint8_t* messageString) {
        uint8_t i;
        for (i = 0; i < 20; i++) {
            dbg(CHAT_CHANNEL, "%u: %c\n", i, messageString[i]);
        }
        dbg(CHAT_CHANNEL, "Received: \"%s\"\n", messageString);
    }
}
