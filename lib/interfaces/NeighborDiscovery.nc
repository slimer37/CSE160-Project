interface NeighborDiscovery {
    command void startDiscovery();
    event void neighborDiscovered(uint16_t neighborAddr);
    command void printNeighbors();
}
