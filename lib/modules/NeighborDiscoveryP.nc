// File: NeighborDiscoveryP.nc

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface Packet;
    uses interface Timer<TMilli> as discoveryTimer;
}

implementation {
    uint16_t neighbors[256];
    uint8_t neighborCount = 0;

    command void NeighborDiscovery.startDiscovery() {
        call discoveryTimer.startPeriodic(2000);
        dbg(NEIGHBOR_CHANNEL, "Neighbor discovery started\n");
    }

    void sendDiscoveryPackets() {
        pack msgPayload;

        // When rediscovering, reset neighbor count
        neighborCount = 0;

        // Prepare the discovery packet
        msgPayload.src = TOS_NODE_ID;
        msgPayload.dest = AM_BROADCAST_ADDR;
        msgPayload.protocol = PROTOCOL_PING;
        msgPayload.seq = 0;  // Sequence number for neighbor discovery

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

    command uint8_t NeighborDiscovery.getNeighbors(uint16_t *neighborList) {
        uint8_t i;
        for (i = 0; i < neighborCount; i++) {
            neighborList[i] = neighbors[i];
        }
        return neighborCount;
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack *receivedPkt = (pack *) payload;
        uint8_t i;

        if (receivedPkt->protocol == PROTOCOL_PINGREPLY) {
            // Check if neighbor is already in the list
            for (i = 0; i < neighborCount; i++) {
                if (neighbors[i] == receivedPkt->src) {
                    return msg;  // Neighbor already discovered
                }
            }

            // Add the new neighbor
            neighbors[neighborCount++] = receivedPkt->src;
            dbg(NEIGHBOR_CHANNEL, "Discovered neighbor: %u\n", receivedPkt->src);
            signal NeighborDiscovery.neighborDiscovered(receivedPkt->src);
        }
        else if (receivedPkt->protocol == PROTOCOL_PING) {
            sendDiscoveryReply(receivedPkt->src);
        }

        return msg;
    }
}
