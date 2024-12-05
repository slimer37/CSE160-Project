#include "../../includes/socket.h"

interface TcpClient {
    command error_t startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint16_t transfer);
}