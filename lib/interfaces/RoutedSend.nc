interface RoutedSend {
    command void send(uint16_t dest, uint8_t *payload, uint8_t len);
    event void received(uint16_t src, pack *package, uint8_t len);
}