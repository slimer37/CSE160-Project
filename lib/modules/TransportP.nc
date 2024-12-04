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
        socket_store_t *clientSocket;

        socket_store_t *socket = fdToSocket(fd);

        socket_t clientSocketFd = call Transport.socket();

        if (!clientSocketFd) {
            dbg(TRANSPORT_CHANNEL, "Failed to create new socket.\n");
            return clientSocketFd;
        }

        clientSocket = fdToSocket(clientSocketFd);

        if (socket->state == SYN_RCVD) {
            tcp_pack ackPack;

            // copy socket
            *clientSocket = *socket;

            clientSocket->state = SYN_RCVD;

            socket->dest.port = 0;
            socket->dest.addr = 0;
            socket->state = LISTEN;

            // form packet

            ackPack.flags = SYN | ACK;
            ackPack.sourcePort = clientSocket->src;
            ackPack.destPort = clientSocket->dest.port;

            call RoutedSend.send(clientSocket->dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

            dbg(TRANSPORT_CHANNEL, "Accepted connection from %u, SYN + ACK ing\n", clientSocket->dest.addr);
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
        uint16_t sender = package->src;

        fd = findClientSocket(packet->destPort, packet->sourcePort, sender);

        // Try to find client socket first
        if (!fd) {
            fd = findSocketBoundToPort(packet->destPort);

            if (!fd) {
                dbg(TRANSPORT_CHANNEL, "Received on closed port %u.\n", packet->destPort);
                return FAIL;
            }
        }

        socket = fdToSocket(fd);

        dbg(TRANSPORT_CHANNEL, "%u is state %s\n", fd, getStateAsString(socket->state));

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
                }
            }
            else if (socket->state == LISTEN) {
                socket->state = SYN_RCVD;
                socket->dest.addr = sender;
                socket->dest.port = packet->sourcePort;

                dbg(TRANSPORT_CHANNEL, "SYN_RCVD from %u\n", sender);
            }

            return SUCCESS;
        }

        // ACK
        
        if (packet->flags & ACK) {
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

        if (packet->flags & FIN) {
            if (socket->state == ESTABLISHED) {
                // skipping CLOSE_WAIT to go to LAST_ACK
                socket->state = LAST_ACK;

                // send back FIN
                ackPack.flags = FIN;
                call RoutedSend.send(sender, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);
                dbg(TRANSPORT_CHANNEL, "Responding to FIN with FIN, to LAST_ACK\n");

                return SUCCESS;
            }
            else if (socket->state == FIN_WAIT_1 || socket->state == FIN_WAIT_2) {

                // send back FIN
                ackPack.flags = FIN;
                call RoutedSend.send(sender, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

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
            
            dbg(TRANSPORT_CHANNEL, "TCP received from %u with flags: %s\n", src, getTcpFlagsAsString(packet->flags));

            call Transport.receive(package);
        }
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t* addr) {
        socket_store_t *socket = fdToSocket(fd);
        tcp_pack packet;
        uint16_t endpoint = addr->addr;

        if (socket->state != LISTEN) {
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

        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd) {

    }
}