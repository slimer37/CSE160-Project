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
        
        socket->src = addr->port;

        return SUCCESS;
    }

    command socket_t Transport.accept(socket_t fd) {
        tcp_pack packet;
        socket_store_t *socket = fdToSocket(fd);

        if (socket->state == SYN_RCVD) {
            // form pack

            socket->state = SYN_RCVD;

            // SYN + ACK
            packet.flags = 0x80 | 0x40;
            packet.source.port = socket->src;
            packet.dest.port = socket->dest.port;

            call RoutedSend.send(socket->dest.addr, (uint8_t*)&packet, sizeof(packet), PROTOCOL_TCP);
        }
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.receive(pack* package) {
        socket_store_t *socket;
        tcp_pack ackPack;
        tcp_pack *packet = (tcp_pack*)package->payload;

        socket = fdToSocket(findSocketBoundToPort(packet->dest.port));

        // if SYN
        if (packet->flags & 0x80) {

            ackPack.source = packet->dest;
            ackPack.dest = packet->source;

            // + ACK
            if (packet->flags & 0x40) {
                if (socket->state == SYN_SENT) {
                    // ACK back
                    ackPack.flags = 0x40;

                    call RoutedSend.send(ackPack.dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);
                }
            }
            else if (socket->state == CLOSED) {
                socket->state = LISTEN;
                socket->dest = packet->source;

                // SYN + ACK back
                ackPack.flags = 0x40 | 0x80;

                call RoutedSend.send(ackPack.dest.addr, (uint8_t*)&ackPack, sizeof(ackPack), PROTOCOL_TCP);

                dbg(TRANSPORT_CHANNEL, "Got SYN, went to LISTEN; SYN + ACK ing to %u\n", ackPack.dest.addr);
            }
        }
        // ACK
        else if (packet->flags & 0x40) {
            socket->state = ESTABLISHED;
            dbg(TRANSPORT_CHANNEL, "Established\n");
        }
    }

    event void RoutedSend.received(uint16_t src, pack *package, uint8_t len) {
        call Transport.receive(package);
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
        socket_store_t *socket = fdToSocket(fd);
        tcp_pack packet;

        if (socket->state != CLOSED) {
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