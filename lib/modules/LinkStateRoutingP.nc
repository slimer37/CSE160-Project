module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface Flooding;
    uses interface NeighborDiscovery;

    uses interface List<ProbableHop> as Confirmed;
    uses interface List<ProbableHop> as Tentative;
}

#define MAX_NODE_ID NEIGHBOR_TABLE_LENGTH

implementation {
    uint8_t linkQualityTable[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t costs[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t nextHopTable[MAX_NODE_ID];

    void floodLinkState() {
        uint8_t linkState = call NeighborDiscovery.retrieveLinkState();

        call Flooding.floodSend(AM_BROADCAST_ADDR, linkState, MAX_NODE_ID);
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

    bool isTentative(uint16_t node, uint16_t *outIndex) {
        uint16_t i;

        for (i = 0; i < call Tentative.size(); i++) {
            if (node == (call Tentative.get(i)).dest) {
                if (outIndex) *outIndex = i;
                return TRUE;
            }
        }

        return FALSE;
    }

    bool isConfirmed(uint16_t node) {
        uint16_t i;

        for (i = 0; i < call Confirmed.size(); i++) {
            if (node == (call Confirmed.get(i)).dest) {
                return TRUE;
            }
        }

        return FALSE;
    }

    void printRoutingTable() {
        uint16_t i;
        ProbableHop hop;

        dbg(GENERAL_CHANNEL, "Routing table for %u:\n", TOS_NODE_ID);

        for (i = 0; i < call Confirmed.size(); i++) {
            hop = call Confirmed.get(i);
            dbg(GENERAL_CHANNEL, "%u %u %u\n", hop.dest, hop.cost, hop.nextHop);
        }
    }

    // dijkstra
    void doForwardSearch() {
        ProbableHop hop;
        uint16_t next = TOS_NODE_ID;
        uint16_t id;
        uint8_t i;
        uint8_t cost;
        uint16_t tentativeListLocation;

        while (call Confirmed.size() > 0) {
            call Confirmed.popback();
        }
        while (call Tentative.size() > 0) {
            call Tentative.popback();
        }

        // 1. initialization

        hop.dest = next;
        hop.cost = 0;
        hop.nextHop = next;

        call Confirmed.pushback(hop);

        // 2.

        // 3.

        while (TRUE) {
            for (id = 0; id < MAX_NODE_ID; id++) {
                // Iterate through neighbors
                if (edgeLength(next, id) > 100) continue;

                cost = costs[TOS_NODE_ID][next] + costs[next][id];

                hop.dest = id;
                hop.cost = cost;
                hop.nextHop = next;

                if (isTentative(id, &tentativeListLocation)) {
                    if (cost < costs[TOS_NODE_ID][id]) {
                        call Tentative.set(tentativeListLocation, hop);
                        continue;
                    }
                }

                if (!isConfirmed(id)) {
                    call Tentative.pushback(hop);
                }
            }

            if (call Tentative.isEmpty()) break;

            // Now using cost and next to track minimum
            cost = (call Tentative.get(0)).cost;
            tentativeListLocation = 0; // its index

            for (i = 1; i < call Tentative.size(); i++) {
                hop = call Tentative.get(i);
                if (hop.cost < cost) {
                    tentativeListLocation = i;
                    cost = hop.cost;
                }
            }

            hop = call Tentative.get(tentativeListLocation);

            next = hop.dest;

            // Move the minimum cost hop to the confirmed list
            call Confirmed.pushback(hop);
            call Tentative.pop(tentativeListLocation);
        }

        printRoutingTable();
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