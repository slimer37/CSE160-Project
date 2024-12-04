module TcpServerP {
    provides interface TcpServer;

    uses interface Transport;

    uses interface Timer<TMilli> as acceptConnectionTimer;
}

implementation {
    socket_t serverSocket;
    socket_t clientSocket;

    command error_t TcpServer.startServer(socket_port_t port) {
        socket_addr_t socket_address;

        serverSocket = call Transport.socket();

        if (!serverSocket) {
            dbg(TRANSPORT_CHANNEL, "No socket available.\n");
            return;
        }

        socket_address.port = port;
        socket_address.addr = TOS_NODE_ID;

        if (call Transport.bind(serverSocket, &socket_address) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Bound server to port %u.\n", port);
        } else {
            dbg(TRANSPORT_CHANNEL, "Failed to bind to port %u.\n", port);
            return FAIL;
        }

        if (call Transport.listen(serverSocket) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Listening on %u.\n", port);
        } else {
            dbg(TRANSPORT_CHANNEL, "Couldn't set %u to listen.\n", port);
            return FAIL;
        }

        call acceptConnectionTimer.startPeriodic(ATTEMPT_CONNECTION_TIME);

        return SUCCESS;
    }

    event void acceptConnectionTimer.fired() {
        socket_t socket = call Transport.accept(serverSocket);
    }
}