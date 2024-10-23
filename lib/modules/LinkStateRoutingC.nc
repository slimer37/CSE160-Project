configuration LinkStateRoutingC {
    provides interface LinkStateRouting;
}

implementation {
    components LinkStateRoutingP;

    LinkStateRouting = LinkStateRoutingP;

    components NeighborDiscoveryC;
    LinkStateRoutingP.NeighborDiscovery -> NeighborDiscoveryC;

    components FloodingC;
    LinkStateRoutingP.Flooding -> FloodingC;

    components new ListC(ProbableHop, 256) as Tentative;
    LinkStateRoutingP.Tentative-> Tentative;
    components new ListC(ProbableHop, 256) as Confirmed;
    LinkStateRoutingP.Confirmed -> Confirmed;

    components new TimerMilliC() as ft;
    LinkStateRoutingP.refloodTimer -> ft;
}