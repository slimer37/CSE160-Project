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
        socket_store_t *clientSocket;

        socket_store_t *socket = fdToSocket(fd);

        socket_t clientSocketFd = call Transport.socket();

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

        fd = findClientSocket(packet->dest.port, packet->source);

        // Try to find client socket first
        if (!fd) {
            fd = findSocketBoundToPort(packet->dest.port);

            if (!fd) {
                dbg(TRANSPORT_CHANNEL, "Received on closed port %u.\n", packet->dest.port);
                return FAIL;
            }
        }

        dbg(TRANSPORT_CHANNEL, "%u is state %x\n", fd, socket->state);

        socket = fdToSocket(fd);

        ackPack.source = packet->dest;
        ackPack.dest = packet->source;

        // if SYN
        if (packet->flags & 0x80) {
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
        
        if (packet->flags & 0x40) {
            if (socket->state == SYN_RCVD) {
                socket->state = ESTABLISHED;
                dbg(TRANSPORT_CHANNEL, "SERVER ESTABLISHED! Got final ACK.\n");
            }
            else if (socket->state == FIN_WAIT_1) {
                socket->state = FIN_WAIT_2;
            }
            else if (socket->state == LAST_ACK) {
                socket->state = CLOSED;

                call Transport.release(fd);
            }

            return SUCCESS;
        }

        // FIN

        if (packet->flags & 0x20) {
            if (socket->state == ESTABLISHED) {
                // skipping CLOSE_WAIT to go to LAST_ACK
                socket->state = LAST_ACK;

                // send back FIN
                ackPack.flags = 0x20;
                call RoutedSend.send(socket->dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);
                dbg(TRANSPORT_CHANNEL, "Responding to FIN with FIN, to LAST_ACK\n");

                return SUCCESS;
            }
            else if (socket->state == FIN_WAIT_1 || socket->state == FIN_WAIT_2) {

                // send back FIN
                ackPack.flags = 0x20;
                call RoutedSend.send(socket->dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

                if (socket->state == FIN_WAIT_1) {
                    socket->state = CLOSING;
                    dbg(TRANSPORT_CHANNEL, "Responding to FIN with FIN, now CLOSING\n");
                } else {
                    // Skipping TIME_WAIT for now

                    // socket->state = TIME_WAIT;
                    dbg(TRANSPORT_CHANNEL, "Responding to FIN with FIN, now CLOSED\n");

                    socket->state = CLOSED;

                    call Transport.release(fd);
                }

                return SUCCESS;
            }
        }

        dbg(TRANSPORT_CHANNEL, "Unrecognized TCP type.\n");

        return FAIL;
    }

    event void RoutedSend.received(uint16_t src, pack *package, uint8_t len) {
        if (package->protocol == PROTOCOL_TCP) {
            tcp_pack *packet = (tcp_pack*)package->payload;
            
            dbg(TRANSPORT_CHANNEL, "TCP packet received via LSR from %u with flags: %p\n", src, packet->flags);
            
            if (packet->flags & 0x80) dbg(TRANSPORT_CHANNEL, "SYN\n", src);
            if (packet->flags & 0x40) dbg(TRANSPORT_CHANNEL, "ACK\n", src);
            if (packet->flags & 0x20) dbg(TRANSPORT_CHANNEL, "FIN\n", src);

            call Transport.receive(package);
        }
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
        socket_store_t *socket = fdToSocket(fd);
        tcp_pack packet;

        if (socket->state != LISTEN) {
            return FAIL;
        }

        socket->dest = *addr;

        // SYN
        packet.flags = 0x80;

        packet.source.port = socket->src;
        packet.source.addr = TOS_NODE_ID;
        packet.dest = *addr;

        socket->state = SYN_SENT;

        dbg(TRANSPORT_CHANNEL, "Active open, SYN to %u\n", packet.dest.addr);

        call RoutedSend.send(packet.dest.addr, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);

        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {
        tcp_pack packet;
        socket_store_t *socket = fdToSocket(fd);

        // send FIN
        packet.flags = 0x20;

        packet.source.port = TOS_NODE_ID;
        packet.source.addr = socket->src;
        packet.dest = socket->dest;
        
        call RoutedSend.send(socket->dest.addr, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);

        dbg(TRANSPORT_CHANNEL, "Closing - FIN_WAIT_1, sent FIN to %u\n", socket->dest.addr);
        
        socket->state = FIN_WAIT_1;

        return SUCCESS;
    }

    command error_t Transport.release(socket_t fd) {
        socket_store_t *socket = fdToSocket(fd);
        socket->src = 0;

        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd) {

    }
}