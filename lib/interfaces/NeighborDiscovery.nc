interface NeighborDiscovery {
    command void startDiscovery();
    event void neighborDiscovered(uint16_t neighborAddr);
    event void neighborLost(uint16_t neighborAddr);
    command void printNeighbors();
    command void printLinkState();
    command void printDistanceVector();
    command uint8_t* retrieveDistanceVectors();
}
