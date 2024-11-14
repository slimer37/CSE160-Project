module TransportP {
    provides interface Transport;
}

implementation {
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];
    
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
        socket_store_t socket = sockets[fd - 1];

        // Check if already bound
        if (socket.src != 0) {
            return FAIL;
        }
        
        socket.src = addr->port;

        return SUCCESS;
    }

    command socket_t Transport.accept(socket_t fd) {

    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.receive(pack* package) {

    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen) {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {

    }

    command error_t Transport.close(socket_t fd) {

    }

    command error_t Transport.release(socket_t fd) {

    }

    command error_t Transport.listen(socket_t fd) {

    }
}