interface LinkStateRouting {
    command void initialize();
    command void send(uint16_t dest, uint8_t *payload, uint8_t len);
    event void received(uint16_t src, uint8_t *payload, uint8_t len);
}
