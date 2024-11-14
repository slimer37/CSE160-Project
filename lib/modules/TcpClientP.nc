module TcpClientP {
    provides interface TcpClient;

    uses interface Transport;

    uses interface Timer<TMilli> as writeTimer;
}

implementation {
    socket_t clientSocket;

    command void TcpClient.startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort) {
        socket_addr_t socketAddress;
        socket_addr_t serverAddress;

        clientSocket = call Transport.socket();

        socketAddress.port = srcPort;
        socketAddress.addr = TOS_NODE_ID;

        serverAddress.port = destPort;
        serverAddress.addr = dest;

        call Transport.bind(clientSocket, &socketAddress);

        call Transport.connect(clientSocket, &serverAddress);
    }

    event void writeTimer.fired() {

    }
}