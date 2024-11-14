module TcpServerP {
    provides interface TcpServer;

    uses interface Transport;
}

implementation {
    command void TcpServer.startServer(socket_port_t port) {
        socket_t socket;
        socket_addr_t socket_address;

        socket = call Transport.socket();

        if (!socket) {
            dbg(TRANSPORT_CHANNEL, "No socket available.\n");
            return;
        }

        socket_address.port = port;
        socket_address.addr = TOS_NODE_ID;

        if (call Transport.bind(socket, &socket_address) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Bound socket to port %u.\n", port);
        } else {
            dbg(TRANSPORT_CHANNEL, "Failed to bind to port %u.\n", port);
        }
    }
}