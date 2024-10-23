interface LinkStateRouting {
    // command void send(uint16_t dest, uint8_t *payload, uint8_t len);
    event void received(uint16_t src, uint8_t *payload, uint8_t len);
    command void printRoutingTable();
    command void startTimer();
}
