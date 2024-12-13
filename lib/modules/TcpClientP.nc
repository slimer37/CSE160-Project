module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as readyTimer;
}

implementation {
    socket_t clientSocket;
    socket_addr_t serverAddress;
    socket_port_t port;

    uint8_t buff[128];
    uint8_t lastRead;

    bool ready;

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

    command uint8_t TcpClient.writeString(uint8_t* string) {
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

    command uint8_t TcpClient.write(uint8_t* buff, uint8_t len) {
        return call Transport.write(clientSocket, buff, len);
    }

    event void readyTimer.fired() {
        if (call Transport.checkSocketState(clientSocket) == CLOSED) {
            dbg(TRANSPORT_CHANNEL, "Can't write now, socket is closed. Reconnecting...\n");
            call Transport.connect(clientSocket, &serverAddress);
            call readyTimer.startOneShot(3000);
            return;
        } else {
            if (!ready) {
                signal TcpClient.ready();

                call readyTimer.startPeriodic(1000);

                ready = TRUE;
            } else {
                uint8_t readNum;
                uint8_t j;
                bool empty = FALSE;
                
                readNum = call Transport.read(clientSocket, buff + lastRead, sizeof(buff) - lastRead);

                if (readNum == 0) {
                    return;
                }

                dbg(TRANSPORT_CHANNEL, "\n");
                dbg(TRANSPORT_CHANNEL, "[CLIENT APPLICATION]\n");
                dbg(TRANSPORT_CHANNEL, "Read %u bytes from client into %u\n", readNum, lastRead);
                dbg(TRANSPORT_CHANNEL, ">>> \"%s\"\n", buff);

                for (j = lastRead; j < lastRead + readNum - 1; j++) {
                    // Check for message termination with \r\n
                    if (buff[j] == '\r' && buff[j + 1] == '\n') {

                        // null-terminate the completed message by replacing \r
                        // and process it directly from the buffer
                        buff[j] = '\0';
                        dbg(TRANSPORT_CHANNEL, ">>> Full message: %s\n", buff);
                        signal TcpClient.processMessage(clientSocket, buff);

                        empty = TRUE;
                        break;
                    }
                }

                lastRead += readNum;

                if (!empty) return;

                if (j < lastRead) {
                    memmove(buff, buff + j + 2, sizeof(buff) - lastRead);
                    dbg(TRANSPORT_CHANNEL, ">>> %u into %u, %u bytes Now: \"%s\"\n", j + 2, 0, sizeof(buff) - lastRead, buff);
                    lastRead -= j + 2;

                    dbg(TRANSPORT_CHANNEL, ">>> [Whole message processed, buffer emptied]\n");
                }
            }
        }
    }
}