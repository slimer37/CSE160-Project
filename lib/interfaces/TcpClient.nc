#include "../../includes/socket.h"

interface TcpClient {
    command void startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort);
}