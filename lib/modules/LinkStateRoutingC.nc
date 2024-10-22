configuration LinkStateRoutingC {
    provides interface LinkStateRouting;
}

implementation {
    components LinkStateRoutingP;

    components new NeighborDiscoveryC;
    LinkStateRoutingP.NeighborDiscovery -> NeighborDiscoveryC;
    
    components new FloodingC;
    LinkStateRoutingP.Flooding -> FloodingC;
}