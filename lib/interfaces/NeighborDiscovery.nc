interface NeighborDiscovery {
    command void startDiscovery();
    event void neighborDiscovered(uint16_t neighborAddr);
    event void neighborLost(uint16_t neighborAddr);
    command void printNeighbors();
    command uint8_t* retrieveLinkState();
}
