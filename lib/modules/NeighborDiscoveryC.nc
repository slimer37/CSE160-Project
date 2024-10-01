#include "../../includes/am_types.h"

configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;

    NeighborDiscovery = NeighborDiscoveryP;

    components new AMSenderC(AM_NEIGHBOR_DISCOVERY);
    components new AMReceiverC(AM_NEIGHBOR_DISCOVERY);
    components new TimerMilliC() as discoveryTimer;
    components new TimerMilliC() as sendTimer;

    NeighborDiscoveryP.AMSend -> AMSenderC;
    NeighborDiscoveryP.AMPacket -> AMSenderC;
    NeighborDiscoveryP.Receive -> AMReceiverC;
    NeighborDiscoveryP.discoveryTimer -> discoveryTimer;
    NeighborDiscoveryP.sendTimer -> sendTimer;
    NeighborDiscoveryP.Packet -> AMSenderC; 
}
