module TransportP {
    provides interface Transport;

    uses interface RoutedSend;
}

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

    socket_t findClientSocket(socket_port_t port, socket_addr_t clientAddr) {
        socket_t id;

        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            if (sockets[id].src == port
            && sockets[id].dest.port == clientAddr.port
            && sockets[id].dest.addr == clientAddr.addr) {
                return id + 1;
            }
        }

        return (socket_t)NULL;
    }
    
    command socket_t Transport.socket() {
        socket_t id;

        for (id = 0; id < MAX_NUM_OF_SOCKETS; id++) {
            // If port is unassigned this socket is not in use
            if (sockets[id].src == 0) {
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
        
        socket->state = LISTEN;
        socket->src = addr->port;

        return SUCCESS;
    }

    command socket_t Transport.accept(socket_t fd) {
        tcp_pack ackPack;
        socket_t clientSocketFd = call Transport.socket();
        socket_store_t *socket = fdToSocket(fd);
        socket_store_t *clientSocket;

        if (!clientSocketFd) {
            dbg(TRANSPORT_CHANNEL, "Failed to create new socket.\n");
            return clientSocketFd;
        }

        clientSocket = fdToSocket(clientSocketFd);

        if (socket->state == SYN_RCVD) {
            // form pack

            // copy socket
            *clientSocket = *socket;

            clientSocket->state = SYN_RCVD;

            socket->dest.port = 0;
            socket->dest.addr = 0;
            socket->state = LISTEN;

            // SYN + ACK
            ackPack.flags = 0x80 | 0x40;
            ackPack.source.port = clientSocket->src;
            ackPack.source.addr = TOS_NODE_ID;
            ackPack.dest = clientSocket->dest;

            call RoutedSend.send(ackPack.dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

            dbg(TRANSPORT_CHANNEL, "Accepted connection from %u, SYN + ACK ing\n", ackPack.dest.addr);
        }

        return clientSocketFd;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.receive(pack* package) {
        socket_store_t *socket;
        socket_t fd;
        tcp_pack ackPack;
        tcp_pack *packet = (tcp_pack*)package->payload;

        fd = findSocketBoundToPort(packet->dest.port);

        if (!fd) {
            dbg(TRANSPORT_CHANNEL, "Received on closed port %u.\n", packet->dest.port);
            return FAIL;
        }

        socket = fdToSocket(fd);

        // if SYN
        if (packet->flags & 0x80) {

            ackPack.source = packet->dest;
            ackPack.dest = packet->source;

            // + ACK
            if (packet->flags & 0x40) {
                if (socket->state == SYN_SENT) {
                    // ACK back
                    ackPack.flags = 0x40;

                    socket->state = ESTABLISHED;

                    call RoutedSend.send(ackPack.dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

                    dbg(TRANSPORT_CHANNEL, "CLIENT ESTABLISHED! Got SYN + ACK, ACK to %u\n", ackPack.dest.addr);
                }
            }
            else if (socket->state == LISTEN) {
                socket->state = SYN_RCVD;
                socket->dest = packet->source;

                dbg(TRANSPORT_CHANNEL, "SYN_RCVD from %u\n", ackPack.dest.addr);
            }

            return SUCCESS;
        }

        // ACK

        socket = fdToSocket(findClientSocket(packet->dest.port, packet->source));
        
        if (packet->flags & 0x40) {
            if (socket->state == SYN_RCVD) {
                socket->state = ESTABLISHED;
                dbg(TRANSPORT_CHANNEL, "SERVER ESTABLISHED! Got final ACK.\n");
            }

            return SUCCESS;
        }

        dbg(TRANSPORT_CHANNEL, "Unrecognized TCP type.\n");

        return FAIL;
    }

    event void RoutedSend.received(uint16_t src, pack *package, uint8_t len) {
        call Transport.receive(package);
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
        socket_store_t *socket = fdToSocket(fd);
        tcp_pack packet;

        if (socket->state != LISTEN) {
            return FAIL;
        }

        // SYN
        packet.flags = 0x80;

        packet.source.port = socket->src;
        packet.source.addr = TOS_NODE_ID;
        packet.dest = *addr;

        socket->state = SYN_SENT;

        dbg(TRANSPORT_CHANNEL, "Active open, SYN to %u\n", addr->addr);

        call RoutedSend.send(addr->addr, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);

        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {

    }

    command error_t Transport.release(socket_t fd) {

    }

    command error_t Transport.listen(socket_t fd) {

    }
}