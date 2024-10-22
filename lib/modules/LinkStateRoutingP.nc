module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface Flooding;
    uses interface NeighborDiscovery;
}

implementation {
    event void NeighborDiscovery.neighborDiscovered(uint16_t neighborAddr) {

    }

    event void Flooding.receivedFlooding(uint16_t src, uint8_t *payload, uint8_t len) {

    }
}