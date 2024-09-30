configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;

    NeighborDiscovery = NeighborDiscoveryP;

    components new AMSenderC(AM_PACK);
    components new AMReceiverC(AM_PACK);
    components new TimerMilliC();

    NeighborDiscoveryP.AMSend -> AMSenderC;
    NeighborDiscoveryP.AMPacket -> AMSenderC;
    NeighborDiscoveryP.Receive -> AMReceiverC;
    NeighborDiscoveryP.discoveryTimer -> TimerMilliC;
    NeighborDiscoveryP.Packet -> AMSenderC; 
}
