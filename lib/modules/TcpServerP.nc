module TcpServerP {
    provides interface TcpServer;

    uses interface Transport;

    uses interface Timer<TMilli> as acceptConnectionTimer;
}

#define MAX_CONNECTIONS 3

implementation {
    socket_t serverSocket;
    socket_t clientSockets[MAX_CONNECTIONS];
    uint8_t numConnections;

    command error_t TcpServer.startServer(socket_port_t port) {
        socket_addr_t socket_address;

        serverSocket = call Transport.socket();

        if (!serverSocket) {
            dbg(TRANSPORT_CHANNEL, "No socket available.\n");
            return FAIL;
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
        uint8_t i;
        uint8_t buff[3]; // null-term
        socket_t socket = call Transport.accept(serverSocket);

        if (socket) {
            dbg(TRANSPORT_CHANNEL, "Gained client.\n");
            clientSockets[numConnections] = socket;
            numConnections++;
        }

        for (i = 0; i < numConnections; i++) {
            socket_t client = clientSockets[i];
            uint8_t readNum;

            if (call Transport.checkSocketState(client) == CLOSED) {
                uint8_t j;

                dbg(TRANSPORT_CHANNEL, "Lost client.\n");

                for (j = i; j < numConnections; j++) {
                    clientSockets[j] = clientSockets[j + 1];
                }

                numConnections--;
                continue;
            }

            readNum = call Transport.read(client, buff, 2);

            buff[readNum] = '\0';

            if (readNum == 0) {
                continue;
            }

            dbg(GENERAL_CHANNEL, "Read %u bytes from client #%u: \"%s\"\n", readNum, i, buff);
        }
    }
}