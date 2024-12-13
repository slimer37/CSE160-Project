#include "../../includes/socket.h"

interface TcpServer {
    command error_t startServer(socket_port_t port);

    command error_t writeBroadcast(uint8_t* buff, uint8_t len);
    command uint8_t writeUnicast(socket_t clientSocket, uint8_t* buff, uint8_t len);

    event void processMessage(socket_t sourceSocket, uint8_t* messageString);
    event void disconnected(socket_t clientSocket);
}