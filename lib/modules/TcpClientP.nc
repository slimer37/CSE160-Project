module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as writeTimer;
}

implementation {
    socket_t clientSocket;
    socket_addr_t serverAddress;

    uint16_t transferMax;
    uint16_t progress;

    command error_t TcpClient.startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint16_t transfer) {
        socket_addr_t socketAddress;

        clientSocket = call Transport.socket();

        transferMax = transfer;

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

        call writeTimer.startPeriodic(2000);

        return SUCCESS;
    }

    event void writeTimer.fired() {
        uint8_t buff[128];
        uint8_t i;

        if (call Transport.checkSocketState(clientSocket) != ESTABLISHED) {
            dbg(TRANSPORT_CHANNEL, "Can't write now, not established\n");
            // call Transport.connect(clientSocket, &serverAddress);
            return;
        }

        if (progress >= transferMax) {
            call writeTimer.stop();
            return;
        }

        dbg(TRANSPORT_CHANNEL, "\n");
        dbg(TRANSPORT_CHANNEL, "[CLIENT] Writing numbers to transfer:\n");

        for (i = 0; i < transferMax && i < 64; i++) {
            buff[i * 2] = (i + 1) & 0xff;
            buff[i * 2 + 1] = ((i + 1) >> 8);
            dbg(TRANSPORT_CHANNEL, "- %u [= %u | %u]\n", *(uint16_t*)(buff + i * 2), buff[i * 2], buff[i * 2 + 1]);
        }

        dbg(TRANSPORT_CHANNEL, "\n", i);
        
        progress += call Transport.write(clientSocket, buff, i * 2) / 2;
    }
}