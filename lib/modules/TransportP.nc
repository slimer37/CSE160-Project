module TransportP {
    provides interface Transport;
}

implementation {
    socket_store_t socket_store;
    
    command socket_t Transport.socket() {

    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {

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