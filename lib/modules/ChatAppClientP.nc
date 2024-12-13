module ChatAppClientP {
    provides interface ChatAppClient;

    uses interface TcpClient;
}

implementation {
    uint8_t clientUsername[16];
    socket_port_t port;

    command error_t ChatAppClient.join(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t* username) {
        strcpy(clientUsername, username);
        
        port = destPort;

        call TcpClient.startClient(srcPort, dest, destPort);
    }

    event void TcpClient.ready() {
        uint8_t msg[32];

        sprintf(msg, "hello %s %u\r\n", clientUsername, port);

        call TcpClient.write(msg);

        dbg(CHAT_CHANNEL, "Joined the room.\n");
    }
}
