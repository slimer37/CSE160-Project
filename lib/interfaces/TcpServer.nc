#include "../../includes/socket.h"

interface TcpServer {
    command error_t startServer(socket_port_t port);
    event void processMessage(uint8_t* messageString);
}