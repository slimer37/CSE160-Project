configuration NeighborDiscoveryC 
{
    provides interface NeighborDiscovery;
}

implementation 
{
    components NeighborDiscoveryP;
    components new AMSenderC(AM_PACK) as AMSender;
    components new AMReceiverC(AM_PACK) as AMReceiver;
    components new TimerMilliC() as Timer0;
    components ActiveMessageC;

    NeighborDiscovery = NeighborDiscoveryP;

    NeighborDiscoveryP.AMSend -> AMSender;
    NeighborDiscoveryP.AMPacket -> AMSender;
    NeighborDiscoveryP.Receive -> AMReceiver;
    NeighborDiscoveryP.discoveryTimer -> Timer0;
    NeighborDiscoveryP.Packet -> ActiveMessageC.Packet;
}
