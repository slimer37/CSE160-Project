module LinkStateRoutingP {
    provides interface LinkStateRouting;

    uses interface Flooding;
    uses interface NeighborDiscovery;

    uses interface List<ProbableHop> as Confirmed;
    uses interface List<ProbableHop> as Tentative;

    uses interface Timer<TMilli> as refloodTimer;
}

#define MAX_NODE_ID NEIGHBOR_TABLE_LENGTH

implementation {
    uint8_t linkQualityTable[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t costs[MAX_NODE_ID][MAX_NODE_ID];
    uint16_t nextHopTable[MAX_NODE_ID];

    bool floodRequested = FALSE;

    command uint16_t LinkStateRouting.getNextHop(uint16_t dest) {
        return nextHopTable[dest];
    }

    command void LinkStateRouting.startTimer() {
        call refloodTimer.startPeriodic(500);
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

    command void LinkStateRouting.printRoutingTable() {
        uint16_t i;
        ProbableHop hop;

        dbg(GENERAL_CHANNEL, "Routing table for %u:\n", TOS_NODE_ID);

        for (i = 0; i < MAX_NODE_ID; i++) {
            if (nextHopTable[i] == 0) continue;
            
            dbg(GENERAL_CHANNEL, "%u %u \n", i, nextHopTable[i]);
        }
    }

    // dijkstra
    void doForwardSearch() {
        ProbableHop hop;
        uint16_t next = TOS_NODE_ID;
        uint16_t id;
        uint16_t i;
        uint8_t cost;
        uint16_t tentativeListLocation;

        while (call Confirmed.size() > 0) {
            call Confirmed.popback();
        }
        while (call Tentative.size() > 0) {
            call Tentative.popback();
        }

        // 1. initialization

        for (id = 0; id < MAX_NODE_ID; id++) {
            nextHopTable[id] = 0;
        }

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
                // else if (TOS_NODE_ID==2) dbg(GENERAL_CHANNEL, "%u -> %u: len: %u\n", next, id, edgeLength(next, id));

                cost = costs[TOS_NODE_ID][next] + costs[next][id];

                hop.dest = id;
                hop.cost = cost;

                if (next == TOS_NODE_ID) {
                    hop.nextHop = id;
                } else {
                    hop.nextHop = next;
                    // While the next hop for this node is not a neighbor of the source,
                    // move through the confirmed routing table (of shortest path hops)
                    // until we reach a neighbor of the source
                    while (edgeLength(TOS_NODE_ID, hop.nextHop) > 100) {
                        hop.nextHop = nextHopTable[hop.nextHop];
                    }
                }

                if (isTentative(id, &tentativeListLocation)) {
                    if (cost < costs[TOS_NODE_ID][id]) {
                        call Tentative.set(tentativeListLocation, hop);
                        continue;
                    }
                }

                if (!isConfirmed(id)) {
                    call Tentative.pushback(hop);
                    // if (TOS_NODE_ID == 2) dbg(GENERAL_CHANNEL, "pushback %u %u %u\n", hop.dest, hop.cost, hop.nextHop);
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

            // Move the minimum cost hop to the confirmed list
            hop = call Tentative.pop(tentativeListLocation);
            call Confirmed.pushback(hop);

            nextHopTable[hop.dest] = hop.nextHop;

            next = hop.dest;
        }
    }

    void floodLinkState() {
        uint16_t i;
        uint8_t *linkState = call NeighborDiscovery.retrieveLinkState();

        // if (TOS_NODE_ID >= 0 && TOS_NODE_ID <= 4) {
        //     dbg(GENERAL_CHANNEL, "SENDING LSP FROM %u\n:", TOS_NODE_ID);
        //     for (i = 0; i < 5; i++) {
        //         dbg(GENERAL_CHANNEL, "%u - c %u\n", i, linkState[i]);
        //     }
        // }

        memcpy(linkQualityTable[TOS_NODE_ID], linkState, NEIGHBOR_TABLE_LENGTH);

        call Flooding.floodSend(AM_BROADCAST_ADDR, linkState, NEIGHBOR_TABLE_LENGTH);

        doForwardSearch();
    }
    
    event void NeighborDiscovery.neighborDiscovered(uint16_t neighborAddr) {
        floodRequested = TRUE;
        //floodLinkState();
    }

    event void refloodTimer.fired() {
        if (!floodRequested) return;

        floodLinkState();
        floodRequested = FALSE;
    }

    event void Flooding.receivedFlooding(uint16_t src, uint8_t *payload, uint8_t len) {
        uint16_t i;

        // copy the link qualities into appropriate row
        memcpy(linkQualityTable[src], payload, len);

        // if (TOS_NODE_ID == 2) {
        //     dbg(GENERAL_CHANNEL, "GOT LSP FROM %u\n:", src);
        //     for (i = 0; i < MAX_NODE_ID; i++) {
        //         if (payload[i] != 0) dbg(GENERAL_CHANNEL, "%u - c %u\n", i, payload[i]);
        //     }
        // }

        doForwardSearch();
    }
}