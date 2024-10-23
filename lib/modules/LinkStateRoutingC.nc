configuration LinkStateRoutingC {
    provides interface LinkStateRouting;
}

typedef struct {
    uint16_t dest;
    uint8_t cost;
    uint16_t nextHop;
} ProbableHop

implementation {
    components LinkStateRoutingP;

    components new NeighborDiscoveryC;
    LinkStateRoutingP.NeighborDiscovery -> NeighborDiscoveryC;

    components new FloodingC;
    LinkStateRoutingP.Flooding -> FloodingC;

    components new List<ProbableHop>(256) as Tentative;
    LinkStateRoutingP.Tentative-> Tentative;
    components new List<ProbableHop>(256) as Confirmed;
    LinkStateRoutingP.Confirmed -> Confirmed;
}