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

            call RoutedSend.send(socket->dest.addr, (uint8_t*)&packet, sizeof(packet));
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
            // + ACK
            if (packet->flags & 0x40) {
                if (socket->state == SYN_SENT) {
                    // ACK back
                    ackPack.source = packet->dest;
                    ackPack.dest = packet->source;
                    ackPack.flags = packet->flags = 0x40;

                    call RoutedSend.send(packet->source.addr, (uint8_t*)packet, sizeof(packet));
                }
            }
            else if (socket->state == LISTEN) {
                socket->state = SYN_RCVD;
                socket->dest = packet->source;
            }
        }
        // ACK
        else if (packet->flags & 0x40) {
            socket->state = ESTABLISHED;
            dbg(GENERAL_CHANNEL, "established");
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
        packet.dest.port = addr->port;

        socket->state = SYN_SENT;

        call RoutedSend.send(addr->addr, (uint8_t*)&packet, sizeof(packet));

        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd) {

    }

    command error_t Transport.release(socket_t fd) {

    }

    command error_t Transport.listen(socket_t fd) {

    }
}