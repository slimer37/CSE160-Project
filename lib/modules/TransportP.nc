module TransportP {
    provides interface Transport;

    uses interface RoutedSend;

    uses interface Timer<TMilli> as sendTimer;
}

#define SEND_TIMER_PERIOD 2000

implementation {
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];

    socket_store_t* fdToSocket(socket_t fd) {
        return &sockets[fd - 1];
    }

    socket_t findSocketBoundToPort(socket_port_t port) {
        socket_t id;

        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            if (sockets[id].src == port) {
                return id + 1;
            }
        }

        return (socket_t)NULL;
    }

    socket_t findClientSocket(socket_port_t localPort, socket_port_t clientPort, uint16_t clientAddr) {
        socket_t id;

        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            if (sockets[id].src == localPort
            && sockets[id].dest.port == clientPort
            && sockets[id].dest.addr == clientAddr) {
                return id + 1;
            }
        }

        return (socket_t)NULL;
    }

    command socket_t Transport.findSocket(socket_port_t src, socket_addr_t dest) {
        return findClientSocket(src, dest.port, dest.addr);
    }
    
    command socket_t Transport.socket() {
        socket_t id;

        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            // If port is unassigned this socket is not in use
            if (sockets[id].src == 0) {

                // Initialize empty addressing
                sockets[id].dest.addr = 0;
                sockets[id].dest.port = 0;

                // Start with max window
                sockets[id].effectiveWindow = SOCKET_BUFFER_SIZE;

                sockets[id].lastWritten = sockets[id].lastAck = sockets[id].lastSent = 0;
                sockets[id].lastRead = sockets[id].lastRcvd = sockets[id].nextExpected = 0;

                return id + 1;
            }
        }

        return (socket_t)NULL;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {
        socket_store_t *socket = fdToSocket(fd);

        // Check if already bound
        if (socket->src != 0) {
            return FAIL;
        }
        
        socket->state = CLOSED;
        socket->src = addr->port;
        
        socket->dest.port = 0;
        socket->dest.addr = 0;

        return SUCCESS;
    }

    command socket_t Transport.accept(socket_t fd) {
        socket_store_t *clientSocket = NULL;

        socket_store_t *listenSocket = fdToSocket(fd);

        uint8_t id;

        // Find the first socket that has received a SYN for this port
        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            if (sockets[id].src == listenSocket->src && sockets[id].state == LISTEN && sockets[id].dest.addr != 0) {
                clientSocket = &sockets[id];
                break;
            }
        }

        if (clientSocket)
        {
            tcp_pack ackPack;
            fd = id + 1;

            // form packet

            ackPack.flags = SYN | ACK;
            ackPack.sourcePort = clientSocket->src;
            ackPack.destPort = clientSocket->dest.port;

            call RoutedSend.send(clientSocket->dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

            dbg(TRANSPORT_CHANNEL, "Accepted connection socket %u, sending SYN + ACK\n", fd);

            clientSocket->state = SYN_RCVD;

            return fd;
        }
        else {
            return (socket_t)NULL;
        }
    }

    socket_t passiveOpenNewSocket(socket_store_t *listenSocket, uint16_t destAddr, socket_port_t destPort) {
        socket_store_t *clientSocket;

        socket_t clientSocketFd;

        if (listenSocket->state != LISTEN) {
            dbg(TRANSPORT_CHANNEL, "Can't passive open using a non-LISTEN socket.\n");
            return 0;
        }

        // Try to get a new socket

        clientSocketFd = call Transport.socket();

        if (!clientSocketFd) {
            dbg(TRANSPORT_CHANNEL, "Failed to create new socket.\n");
            return clientSocketFd;
        }

        clientSocket = fdToSocket(clientSocketFd);

        // Copy details from listen socket
        
        *clientSocket = *listenSocket;

        clientSocket->state = LISTEN;

        clientSocket->dest.port = destPort;
        clientSocket->dest.addr = destAddr;

        dbg(TRANSPORT_CHANNEL, "Passively opened new socket (FD#%u -> %u:%u).\n", clientSocketFd, destAddr, destPort);

        return clientSocketFd;
    }

    socket_t getTargetedSocket(uint16_t sender, tcp_pack *packet) {
        socket_t fd = findClientSocket(packet->destPort, packet->sourcePort, sender);

        // Try to find client socket first
        if (!fd) {
            fd = findSocketBoundToPort(packet->destPort);

            if (!fd) {
                dbg(TRANSPORT_CHANNEL, "Received on unbound port %u.\n", packet->destPort);
                return 0;
            }
        }

        return fd;
    }

    command error_t Transport.receive(pack* package) {
        socket_store_t *socket;
        socket_t fd;
        tcp_pack ackPack;
        tcp_pack *packet = (tcp_pack*)package->payload;
        uint16_t sender = package->src;
        
        fd = getTargetedSocket(sender, packet);

        if (!fd) {
            return FAIL;
        }

        socket = fdToSocket(fd);

        if (socket->state == CLOSED) {
            dbg(TRANSPORT_CHANNEL, "Received on CLOSED port %u.\n", packet->destPort);
        }

        dbg(TRANSPORT_CHANNEL, "> Socket %u (Port %u to %u:%u): %s\n", fd, socket->src, socket->dest.addr, socket->dest.port, getStateAsString(socket->state));

        ackPack.sourcePort = packet->destPort;
        ackPack.destPort = packet->sourcePort;

        // if SYN
        if (packet->flags & SYN) {
            // + ACK
            if (packet->flags & ACK) {
                if (socket->state == SYN_SENT) {
                    // ACK back
                    ackPack.flags = ACK;

                    socket->state = ESTABLISHED;

                    call RoutedSend.send(sender, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

                    dbg(TRANSPORT_CHANNEL, "CLIENT ESTABLISHED! Got SYN + ACK, ACK to %u\n", sender);

                    return SUCCESS;
                }
            }
            else if (socket->state == LISTEN) {
                dbg(TRANSPORT_CHANNEL, "SYN_RCVD from %u\n", sender);

                passiveOpenNewSocket(socket, sender, packet->sourcePort);

                return SUCCESS;
            }

            dbg(TRANSPORT_CHANNEL, "Can't respond to SYN from %u\n", sender);

            return FAIL;
        }

        // ACK
        
        if (packet->flags & ACK) {
            if (socket->state == SYN_RCVD) {
                socket->state = ESTABLISHED;
                dbg(TRANSPORT_CHANNEL, "SERVER ESTABLISHED! Got final ACK.\n");

                return SUCCESS;
            }
            else if (socket->state == FIN_WAIT_1) {
                socket->state = FIN_WAIT_2;

                return SUCCESS;
            }
            else if (socket->state == LAST_ACK) {
                socket->state = CLOSED;

                call Transport.release(fd);

                dbg(TRANSPORT_CHANNEL, "Final FIN was ACKed, now CLOSED\n");

                return SUCCESS;
            }
            else if (socket->state == ESTABLISHED) {

                // Invalid packets
                if (packet->acknowledgement < socket->lastAck || packet->advertisedWindow > SOCKET_BUFFER_SIZE) return SUCCESS;

                // Set effective window from advertised window
                if (packet->advertisedWindow == 0) {
                    socket->effectiveWindow = 0;
                } else {
                    socket->lastAck = packet->acknowledgement;
                    socket->effectiveWindow = packet->advertisedWindow - (socket->lastSent - socket->lastAck);
                }

                dbg(TRANSPORT_CHANNEL, "Byte %u was ACKed by %u advertising W=%u, EW=%u\n",
                    socket->lastAck, socket->dest.addr,
                    packet->advertisedWindow, socket->effectiveWindow);

                return SUCCESS;
            }
        }

        // FIN

        if (packet->flags & FIN) {
            if (socket->state == ESTABLISHED) {
                // skipping CLOSE_WAIT to go to LAST_ACK
                socket->state = LAST_ACK;

                // send back FIN
                ackPack.flags = FIN;
                call RoutedSend.send(sender, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);
                dbg(TRANSPORT_CHANNEL, "Responding to FIN with FIN (skipping CLOSE_WAIT), to LAST_ACK\n");

                return SUCCESS;
            }
            else if (socket->state == FIN_WAIT_1) {

                // send back ACK
                ackPack.flags = ACK;
                call RoutedSend.send(sender, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

                // Skipping TIME_WAIT and FIN_WAIT_2

                socket->state = CLOSED;
                
                dbg(TRANSPORT_CHANNEL, "Responding to FIN with ACK, now CLOSED\n");

                socket->state = CLOSED;

                call Transport.release(fd);

                return SUCCESS;
            }
        }

        dbg(TRANSPORT_CHANNEL, "Can't respond to %s right now.\n", getTcpFlagsAsString(packet->flags));

        return FAIL;
    }

    void receiveData(uint16_t sender, tcp_pack *packet);

    event void RoutedSend.received(uint16_t src, pack *package, uint8_t len) {
        if (package->protocol == PROTOCOL_TCP) {
            tcp_pack *packet = (tcp_pack*)package->payload;
            
            dbg(TRANSPORT_CHANNEL, "\n");
            dbg(TRANSPORT_CHANNEL, "=== TCP packet received (%u:%u -> %u:%u) with flags [%s] ===\n",
                src, packet->sourcePort,
                TOS_NODE_ID, packet->destPort,
                getTcpFlagsAsString(packet->flags));

            if (packet->flags == 0) {
                receiveData(src, packet);
            } else {
                call Transport.receive(package);
            }
        }
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t* addr) {
        socket_store_t *socket = fdToSocket(fd);
        tcp_pack packet;
        uint16_t endpoint = addr->addr;

        if (socket->state != CLOSED) {
            return FAIL;
        }

        socket->dest = *addr;

        packet.flags = SYN;

        packet.sourcePort = socket->src;
        packet.destPort = addr->port;

        socket->state = SYN_SENT;

        dbg(TRANSPORT_CHANNEL, "Active open, SYN to %u\n", endpoint);

        call RoutedSend.send(endpoint, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);

        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {
        tcp_pack packet;
        socket_store_t *socket = fdToSocket(fd);
        uint16_t partner = socket->dest.addr;

        // send FIN
        packet.flags = FIN;

        packet.sourcePort = socket->src;
        packet.destPort = socket->dest.port;
        
        call RoutedSend.send(partner, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);

        dbg(TRANSPORT_CHANNEL, "Closing - FIN_WAIT_1, sent FIN to %u\n", partner);
        
        socket->state = FIN_WAIT_1;

        return SUCCESS;
    }

    command error_t Transport.release(socket_t fd) {
        socket_store_t *socket = fdToSocket(fd);
        socket->src = 0;
        socket->dest.port = 0;
        socket->dest.addr = 0;
        socket->state = CLOSED;

        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd) {
        socket_store_t *socket = fdToSocket(fd);

        if (socket->state != CLOSED) {
            return FAIL;
        }

        socket->state = LISTEN;

        return SUCCESS;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t *socket = fdToSocket(fd);
        uint16_t fullLen = bufflen;

        // You can write into the buffer as long as there's empty space besides
        // any un-acked/unsent data
        uint16_t maxWritableBytes = SOCKET_BUFFER_SIZE - (socket->lastWritten - socket->lastAck);

        if (bufflen > maxWritableBytes) {
            bufflen = maxWritableBytes;
        }

        // Copy bufflen bytes from buff into the socket's send buffer
        memcpy((socket->sendBuff + socket->lastWritten), buff, bufflen);

        dbg(TRANSPORT_CHANNEL, "%u/%u bytes were written to the send buffer [i=%u].\n", bufflen, fullLen, socket->lastWritten);
        
        socket->lastWritten += bufflen;

        if (!call sendTimer.isRunning()) {
            call sendTimer.startPeriodic(SEND_TIMER_PERIOD);
        }

        return bufflen;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {
        socket_store_t *socket = fdToSocket(fd);

        // You can read as many bytes as have been continuously received
        uint16_t maxReadableBytes = socket->nextExpected - socket->lastRead;

        if (socket->nextExpected == 0) {
            return 0;
        }

        if (bufflen > maxReadableBytes) {
            bufflen = maxReadableBytes;
        }

        // Copy bufflen bytes from the socket's receive buffer into buff
        memcpy(buff, (socket->rcvdBuff + socket->lastRead), bufflen);

        socket->lastRead += bufflen;

        return bufflen;
    }

    command enum socket_state Transport.checkSocketState(socket_t fd) {
        return fdToSocket(fd)->state;
    }

    void sendBufferedData(socket_t fd) {
        tcp_pack dataPacket;
        uint8_t datalen;
        socket_store_t *sock = fdToSocket(fd);

        // At end of buffer, nothing to send
        if (sock->lastWritten <= sock->lastAck) {
            return;
        }

        dataPacket.destPort = sock->dest.port;
        dataPacket.sourcePort = sock->src;
        dataPacket.flags = 0;
        dataPacket.sequenceNum = sock->lastAck;

        datalen = sock->lastWritten - sock->lastAck;

        if (datalen > sock->effectiveWindow) {
            datalen = sock->effectiveWindow;
        }

        if (datalen > TCP_MAX_PAYLOAD_SIZE) {
            datalen = TCP_MAX_PAYLOAD_SIZE;
        }

        if (datalen == 0 && sock->effectiveWindow > 0) {
            return;
        }

        dataPacket.length = datalen;

        memcpy(dataPacket.payload, sock->sendBuff + sock->lastAck, datalen);

        sock->lastSent = sock->lastAck + datalen;

        call RoutedSend.send(sock->dest.addr, (uint8_t*)&dataPacket, sizeof(dataPacket), PROTOCOL_TCP);

        dbg(TRANSPORT_CHANNEL, "\n", datalen);
        dbg(TRANSPORT_CHANNEL, ">>> Sent %u bytes of data from buffer [lastAck=%u].\n", datalen, sock->lastAck);
    }

    void receiveData(uint16_t sender, tcp_pack *packet) {
        tcp_pack ack;
        socket_store_t *sock;
        uint8_t i;
        uint8_t datalen = packet->length;

        socket_t fd = getTargetedSocket(sender, packet);

        if (!fd) return;

        sock = fdToSocket(fd);

        if (packet->sequenceNum >= sock->nextExpected) {

            // Copy into buffer as much as possible

            if (sock->nextExpected + datalen > SOCKET_BUFFER_SIZE) {
                datalen = SOCKET_BUFFER_SIZE - sock->nextExpected;
            }

            memcpy(sock->rcvdBuff + packet->sequenceNum, packet->payload, datalen);

            dbg(TRANSPORT_CHANNEL, ">>> Received: [l=%u/%u @ s=%u]\n", datalen, packet->length, packet->sequenceNum);

            for (i = 0; i < datalen; i++) {
                dbg(TRANSPORT_CHANNEL, "- %u\n", packet->payload[i]);
            }

        }

        ack.flags = ACK;
        ack.destPort = packet->sourcePort;
        ack.sourcePort = packet->destPort;

        // Acknowledge with the sequence number of the next expected byte

        // Expected byte only moves forward if the stream is continuous
        if (sock->nextExpected == packet->sequenceNum) {
            sock->nextExpected += datalen;
        }

        dbg(TRANSPORT_CHANNEL, ">>> [next=%u]\n", sock->nextExpected);

        ack.acknowledgement = sock->nextExpected;

        // + advertised window as in book (0-based nextExpected)
        ack.advertisedWindow = SOCKET_BUFFER_SIZE - (sock->nextExpected - sock->lastRead);
        
        call RoutedSend.send(sender, (uint8_t*)&ack, sizeof(ack), PROTOCOL_TCP);
    }

    event void sendTimer.fired() {
        uint8_t i;

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            if (sockets[i].state == ESTABLISHED && sockets[i].lastWritten > 0) {
                sendBufferedData(i + 1);
            }
        }
    }
}