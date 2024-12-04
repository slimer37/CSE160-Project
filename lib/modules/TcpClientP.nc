module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as writeTimer;
}

implementation {
    socket_t clientSocket;
    socket_addr_t serverAddress;

    command error_t TcpClient.startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort) {
        socket_addr_t socketAddress;

        clientSocket = call Transport.socket();

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

        call writeTimer.startOneShot(8000);

        return SUCCESS;
    }

    event void writeTimer.fired() {

        if (call Transport.checkSocketState(clientSocket) != ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Can't write now, not established\n");
            // call Transport.connect(clientSocket, &serverAddress);
            return;
        }
    }
}