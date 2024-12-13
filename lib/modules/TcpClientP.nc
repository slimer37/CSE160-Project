module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as readyTimer;
}

implementation {
    socket_t clientSocket;
    socket_addr_t serverAddress;
    socket_port_t port;

    command error_t TcpClient.startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort) {
        socket_addr_t socketAddress;

        clientSocket = call Transport.socket();

        port = srcPort;

        socketAddress.port = srcPort;
        socketAddress.addr = TOS_NODE_ID;

        serverAddress.port = destPort;
        serverAddress.addr = dest;

        if (call Transport.bind(clientSocket, &socketAddress) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Bound client to port %u.\n", srcPort);
        }
        else {
            dbg(TRANSPORT_CHANNEL, "Failed to bind client.\n");
            return FAIL;
        }

        if (call Transport.connect(clientSocket, &serverAddress) == SUCCESS) {
            dbg(TRANSPORT_CHANNEL, "Starting connection to %u:%u.\n", dest, destPort);
        }
        else {
            dbg(TRANSPORT_CHANNEL, "Couldn't start connecting.\n");
            return FAIL;
        }

        call readyTimer.startOneShot(3000);

        return SUCCESS;
    }

    command uint8_t TcpClient.write(uint8_t* string) {
        uint8_t writtenLength;
        uint8_t len = strlen(string);

        if (len == 0 || len > SOCKET_BUFFER_SIZE) {
            dbg(TRANSPORT_CHANNEL, "Invalid string length! (was %u)", len);
            return 0;
        }

        writtenLength = call Transport.write(clientSocket, string, len);

        dbg(TRANSPORT_CHANNEL, "\n");
        dbg(TRANSPORT_CHANNEL, "[CLIENT] Writing characters to transfer: %s\n", string);

        return writtenLength;
    }

    event void readyTimer.fired() {
        if (call Transport.checkSocketState(clientSocket) == CLOSED) {
            dbg(TRANSPORT_CHANNEL, "Can't write now, socket is closed. Reconnecting...\n");
            call Transport.connect(clientSocket, &serverAddress);
            call readyTimer.startOneShot(3000);
            return;
        }

        signal TcpClient.ready();
    }
}