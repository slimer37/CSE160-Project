module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as writeTimer;
}

implementation {
    socket_t clientSocket;

    command error_t TcpClient.startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort) {
        socket_addr_t socketAddress;
        socket_addr_t serverAddress;

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

        dbg(TRANSPORT_CHANNEL, "Will close in 5...\n");

        // Close in 5
        call writeTimer.startOneShot(5000);

        return SUCCESS;
    }

    event void writeTimer.fired() {
        // Just using this to close for the sake of mid-review

        dbg(TRANSPORT_CHANNEL, "Commencing close...\n");

        call Transport.close(clientSocket);
    }
}