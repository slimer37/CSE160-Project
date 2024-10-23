module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface Flooding;
    uses interface NeighborDiscovery;

    uses interface List<uint16_t> as Confirmed;
    uses interface List<uint16_t> as Tentative;
}

#define MAX_NODE_ID NEIGHBOR_TABLE_LENGTH
#define INFINITY 101

implementation {
    uint8_t linkQualityTable[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t costs[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t nextHopTable[MAX_NODE_ID];

    void floodLinkState() {
        uint8_t linkState = NeighborDiscovery.retrieveLinkState();

        Flooding.floodSend(AM_BROADCAST_ADDR, linkState, MAX_NODE_ID);
    }

    // l(s, n) as in textbook
    uint8_t edgeLength(uint16_t s, uint16_t n) {
        // cost based on link quality
        // 100% gives 1 cost
        // 0% gives 101 cost (over 100 considered infinity)
        return 101 - linkQualityTable[s][n];
    }

    uint8_t min(uint8_t a, uint8_t b) {
        return a < b ? a : b;
    }

    bool isTentative(uint16_t node) {
        uint16_t i;

        for (i = 0; i < Tentative.size(); i++) {
            if (node == Tentative.get(i)) {
                return TRUE;
            }
        }

        return FALSE;
    }

    bool isConfirmed(uint16_t node) {
        uint16_t i;

        for (i = 0; i < Confirmed.size(); i++) {
            if (node == Confirmed.get(i)) {
                return TRUE;
            }
        }

        return FALSE;
    }

    // dijkstra
    void doForwardSearch() {
        ProbableHop hop;
        uint16_t next = TOS_NODE_ID;
        uint16_t id;
        uint8_t cost;
        uint8_t i;

        while (Confirmed.size() > 0) {
            Confirmed.popback();
        }
        while (Tentative.size() > 0) {
            Tentative.popback();
        }

        // 1. initialization

        hop.dest = next;
        hop.cost = 0;
        hop.nextHop = next;

        Confirmed.pushback(hop);

        // 2.

        // 3.

        for (id = 0; id < MAX_NODE_ID; id++) {
            if (edgeLength(next, id) > 100) continue;

            cost = costs[TOS_NODE_ID][next] + costs[next][id];

            hop.dest = id;
            hop.nextHop = next;

            if (!isConfirmed(id) && !isTentative(id)) {
                Tentative.pushback(hop);
            }
        } 
    }
    
    // redistribute link state whenever neighbor list changes
    event void NeighborDiscovery.neighborDiscovered(uint16_t neighborAddr) {
        floodLinkState();
    }

    event void Flooding.receivedFlooding(uint16_t src, uint8_t *payload, uint8_t len) {
        // copy the link qualities into appropriate row
        memcpy(linkQualityTable[src], payload, MAX_NODE_ID);

        doForwardSearch();
    }
}