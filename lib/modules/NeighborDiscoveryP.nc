#include "../../includes/neighborDiscovery.h"

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Packet;
    uses interface Timer<TMilli> as discoveryTimer;
}

#define REDISCOVERY_PERIOD 400

implementation {
    uint8_t neighborQualityTable[NEIGHBOR_TABLE_LENGTH];
    uint8_t distanceVectorTable[NEIGHBOR_TABLE_LENGTH];
    NeighborStats neighborStats[NEIGHBOR_TABLE_LENGTH];
    uint16_t seq = 0;

    command uint8_t* NeighborDiscovery.retrieveDistanceVectors() {
        return distanceVectorTable;
    }

    command void NeighborDiscovery.startDiscovery() {
        uint16_t id;
        uint8_t i;

        call discoveryTimer.startPeriodic(REDISCOVERY_PERIOD);
        dbg(NEIGHBOR_CHANNEL, "Neighbor discovery started\n");

        // Initialize neighbor statistics
        for (id = 0; id < NEIGHBOR_TABLE_LENGTH; id++) {
            neighborQualityTable[id] = 0;
            neighborStats[id].linkLifetime = 0;
            neighborStats[id].recentlyReplied = FALSE;
        }
    }

    #define EWMA_ALPHA 0.3
    
    // Calculates EWMA and resets/decrements statistics for next round of discovery
    void advanceLinkStats() {
        uint16_t id;

        for (id = 0; id < NEIGHBOR_TABLE_LENGTH; id++) {
            // EWMA
            neighborQualityTable[id] = EWMA_ALPHA * neighborStats[id].recentlyReplied * 100 + (1 - EWMA_ALPHA) * neighborQualityTable[id];
            
            // Calculate cost of node as inverse of link quality
            distanceVectorTable[id] = 101 - neighborQualityTable[id];

            // Reset flag
            neighborStats[id].recentlyReplied = FALSE;

            // Decrement link lifetimes
        
            if (neighborStats[id].linkLifetime > 0) {
                
                neighborStats[id].linkLifetime--;

                // Signal lost neighbor if the lifetime became zero

                if (neighborStats[id].linkLifetime == 0) {
                    signal NeighborDiscovery.neighborLost(id);
                }
            }
        }
    }

    void sendDiscoveryPackets() {
        pack msgPayload;

        advanceLinkStats();

        // Prepare the discovery packet
        msgPayload.src = TOS_NODE_ID;
        msgPayload.dest = AM_BROADCAST_ADDR;
        msgPayload.protocol = PROTOCOL_PING;
        msgPayload.seq = seq++;  // Sequence number for neighbor discovery

        if (call Sender.send(msgPayload, AM_BROADCAST_ADDR) == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Discovery packet scheduled to be sent\n");
        } 
        else {
            dbg(NEIGHBOR_CHANNEL, "Failed to schedule discovery packet\n");
        }
    }

    void sendDiscoveryReply(uint16_t dest) {
        pack msgPayload;
        error_t err;

        // Prepare the discovery reply packet
        msgPayload.src = TOS_NODE_ID;
        msgPayload.dest = dest;
        msgPayload.protocol = PROTOCOL_PINGREPLY;
        msgPayload.seq = 0;  // Sequence number for neighbor discovery

        err = call Sender.send(msgPayload, dest);

        if (err == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Reply scheduled to be sent to %u\n", dest);
        } 
        else {
            dbg(NEIGHBOR_CHANNEL, "Failed to schedule reply to discovery from %u: %u\n", dest, err);
        }
    }

    event void discoveryTimer.fired() {
        sendDiscoveryPackets();
    }

    command void NeighborDiscovery.printNeighbors() {
        uint16_t id;

        dbg(GENERAL_CHANNEL, "Neighbors of node %u:\n", TOS_NODE_ID);

        // Find active links
        for (id = 0; id < NEIGHBOR_TABLE_LENGTH; id++) {
            // Positive lifetime means active link
            if (neighborStats[id].linkLifetime > 0) {
                dbg(GENERAL_CHANNEL, "- Node %u : %u%% | %u\n", id, neighborQualityTable[id], neighborStats[id].linkLifetime);
            }
        }

        dbg(GENERAL_CHANNEL, "-- End of neighbors --\n");
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack *receivedPkt = (pack *) payload;
        uint16_t id;

        if (receivedPkt->protocol == PROTOCOL_PINGREPLY) {
            // If the lifetime was previously 0, this is a new neighbor.
            if (neighborStats[receivedPkt->src].linkLifetime == 0) {
                dbg(NEIGHBOR_CHANNEL, "Discovered neighbor: %u\n", receivedPkt->src);
                signal NeighborDiscovery.neighborDiscovered(receivedPkt->src);
            }

            // Reset lifetime of this link
            neighborStats[receivedPkt->src].linkLifetime = NEIGHBOR_LIFETIME;
            neighborStats[receivedPkt->src].recentlyReplied = TRUE;
        }
        else if (receivedPkt->protocol == PROTOCOL_PING) {
            sendDiscoveryReply(receivedPkt->src);
        }

        return msg;
    }
}
