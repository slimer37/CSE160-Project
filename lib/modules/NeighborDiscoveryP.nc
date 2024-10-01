module NeighborDiscoveryP  {
    provides interface NeighborDiscovery;

    uses interface AMSend;
    uses interface AMPacket;
    uses interface Receive;
    uses interface Packet;
    uses interface Timer<TMilli> as discoveryTimer;
    uses interface Timer<TMilli> as sendTimer;

    uses interface Random;
}

implementation {
    message_t pkt;
    uint16_t neighbors[256];
    uint8_t neighborCount = 0;
    bool busy = FALSE;

    command void NeighborDiscovery.startDiscovery() {
        call discoveryTimer.startPeriodic(5000);  // Run every 5 seconds
        dbg(NEIGHBOR_CHANNEL, "Neighbor discovery started\n");
    }

    void sendDiscoveryPackets() {
        pack *msgPayload;

        // When rediscovering, reset neighbor count
        neighborCount = 0;

        msgPayload = (pack *) call Packet.getPayload(&pkt, sizeof(pack));

        // Prepare the discovery packet
        msgPayload->src = TOS_NODE_ID;
        msgPayload->protocol = PROTOCOL_PING;
        msgPayload->seq = 0;  // Sequence number for neighbor discovery

        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
            busy = TRUE;
            dbg(NEIGHBOR_CHANNEL, "Discovery packet sent\n");
        } 
        else {
            dbg(NEIGHBOR_CHANNEL, "Failed to send discovery packet\n");
        }
    }

    void sendDiscoveryReply(uint16_t dest) {
        pack *msgPayload;
        error_t err;

        msgPayload = (pack *) call Packet.getPayload(&pkt, sizeof(pack));

        // Prepare the discovery packet
        msgPayload->src = TOS_NODE_ID;
        msgPayload->dest = dest;
        msgPayload->protocol = PROTOCOL_PINGREPLY;
        msgPayload->seq = 0;  // Sequence number for neighbor discovery

        err = call AMSend.send(dest, &pkt, sizeof(pack));

        if (err == SUCCESS) {
            sendTimer.startOneShot()
            busy = TRUE;
            dbg(NEIGHBOR_CHANNEL, "Reply sent\n");
        } 
        else {
            dbg(NEIGHBOR_CHANNEL, "Failed to reply to discovery from %u: %u\n", dest, err);
        }
    }

    event void discoveryTimer.fired() {
        if (busy) {
            dbg(NEIGHBOR_CHANNEL, "Discovery busy\n");
            return;
        }

        sendDiscoveryPackets();
    }

    event void AMSend.sendDone(message_t *msg, error_t error) {
        busy = FALSE;
        if (error == SUCCESS) {
            dbg(NEIGHBOR_CHANNEL, "Discovery packet sent successfully\n");
        } 
        else {
            dbg(NEIGHBOR_CHANNEL, "Failed to send discovery packet\n");
        }
    }

    command uint8_t NeighborDiscovery.getNeighbors(uint16_t *neighborList){
        uint8_t i;
        for (i = 0; i < neighborCount; i++){
            neighborList[i] = neighbors[i];
        }
        return neighborCount;
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack *receivedPkt = (pack *) payload;
        uint8_t i;

        if (receivedPkt->protocol == PROTOCOL_PINGREPLY) {
            // Checking if neighbor is already in the list
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
