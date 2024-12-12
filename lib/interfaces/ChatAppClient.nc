interface ChatAppClient {
    command error_t join(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t* username);
}
