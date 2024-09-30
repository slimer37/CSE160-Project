interface NeighborDiscovery {
    command void startDiscovery();
    event void neighborDiscovered(uint16_t neighborAddr);
    command uint8_t getNeighbors(uint16_t *neighborList);
}
