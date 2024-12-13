#include "../../includes/socket.h"

interface TcpServer {
    command error_t startServer(socket_port_t port);
    event void processMessage(socket_t sourceSocket, uint8_t* messageString);
    event void disconnected(socket_t clientSocket);
}