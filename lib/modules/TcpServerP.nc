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

    uint8_t buff[128];
    uint8_t lastRead;

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
        uint8_t i, j;
        socket_t socket = call Transport.accept(serverSocket);

        if (socket) {
            dbg(TRANSPORT_CHANNEL, "Gained client.\n");
            clientSockets[numConnections] = socket;
            numConnections++;
        }

        for (i = 0; i < numConnections; i++) {
            socket_t client = clientSockets[i];

            if (call Transport.checkSocketState(client) == CLOSED) {

                dbg(TRANSPORT_CHANNEL, "Lost client.\n");

                for (j = i; j < numConnections; j++) {
                    clientSockets[j] = clientSockets[j + 1];
                }

                numConnections--;
                continue;
            } else {
                uint8_t readNum;
                bool empty;
                
                readNum = call Transport.read(client, buff + lastRead, sizeof(buff) - lastRead);

                if (readNum == 0) {
                    continue;
                }

                dbg(TRANSPORT_CHANNEL, "\n");
                dbg(TRANSPORT_CHANNEL, "[SERVER APPLICATION]\n");
                dbg(TRANSPORT_CHANNEL, "Read %u bytes from client into %u\n", readNum, lastRead);
                dbg(TRANSPORT_CHANNEL, ">>> \"%s\"\n", buff);

                for (j = lastRead; j < lastRead + readNum - 1; j++) {
                    // Check for message termination with \r\n
                    if (buff[j] == '\r' && buff[j + 1] == '\n') {
                        dbg(TRANSPORT_CHANNEL, ">>> [Whole message processed, buffer emptied]\n");
                        empty = TRUE;
                        break;
                    }
                }

                lastRead += readNum;

                if (!empty) continue;

                if (j < lastRead) {
                    memmove(buff, buff + j + 1, sizeof(buff) - lastRead);
                    dbg(TRANSPORT_CHANNEL, ">>> %u into %u, %u bytes Now: \"%s\"\n", j + 1, 0, sizeof(buff) - lastRead, buff);
                    lastRead -= j + 1;
                }
            }
        }
    }
}