#include "../../includes/socket.h"

interface TcpClient {
    command error_t startClient(uint8_t srcPort, uint16_t dest, uint8_t destPort);
    event void ready();

    // Use null-terminated string!
    command uint8_t writeString(uint8_t* string);

    event void processMessage(socket_t sourceSocket, uint8_t* messageString);

    command uint8_t write(uint8_t* buff, uint8_t len);
}