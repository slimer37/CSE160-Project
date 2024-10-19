#include "../../includes/am_types.h"

configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;

    NeighborDiscovery = NeighborDiscoveryP;

    components new AMReceiverC(AM_NEIGHBOR_DISCOVERY);
    components new TimerMilliC() as discoveryTimer;
    components new SimpleSendC(AM_NEIGHBOR_DISCOVERY) as SimpleSender;

    NeighborDiscoveryP.Sender -> SimpleSender.SimpleSend;
    NeighborDiscoveryP.Receive -> AMReceiverC;
    NeighborDiscoveryP.discoveryTimer -> discoveryTimer;

    // List up to 256
    components new ListC(uint16_t, 256);

    NeighborDiscoveryP.NeighborList -> ListC;
}
