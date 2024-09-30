interface Flooding {
    command void floodSend(uint16_t dest, uint8_t *payload, uint8_t len);
    event void receivedFlooding(uint16_t src, uint8_t *payload, uint8_t len);
}
