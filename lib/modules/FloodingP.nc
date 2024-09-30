module FloodingP {
    provides interface Flooding;
    
    uses interface AMSend;
    uses interface AMPacket;
    uses interface Receive;
    uses interface Packet;
}

implementation {
    bool busy = FALSE;
    message_t pkt;
    uint16_t floodSeq = 0;
    uint16_t lastFloodSeq[256];

    command void Flooding.floodSend(uint16_t dest, uint8_t *payload, uint8_t len) {
        uint8_t *msgPayload;
        pack *myPkt;

        if (busy == TRUE) {
            dbg(FLOODING_CHANNEL, "Already flooding\n");
            return;
        }

        msgPayload = (uint8_t *) call Packet.getPayload(&pkt, sizeof(pack));
        memcpy(msgPayload, payload, len);

        myPkt = (pack *) msgPayload;

        myPkt->src = TOS_NODE_ID;
        myPkt->dest = dest;
        myPkt->seq = floodSeq++;
        myPkt->TTL = 10;  // Set initial TTL

        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flooding started from node %u to dest %u\n", TOS_NODE_ID, dest);
            busy = TRUE;
        } 
        else {
            dbg(FLOODING_CHANNEL, "Failed to start flooding\n");
        }
    }

    event void AMSend.sendDone(message_t *msg, error_t error) {
        busy = FALSE;
        if (error == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flood successful\n");
        } 
        else {
            dbg(FLOODING_CHANNEL, "Flood failed\n");
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack *receivedPkt = (pack *) payload;
        uint8_t payloadLen = len - PACKET_HEADER_LENGTH;

        //Duplicate packet checking
        if (lastFloodSeq[receivedPkt->src] >= receivedPkt->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate packet from %u, ignored.\n", receivedPkt->src);
            return msg;
        }

        lastFloodSeq[receivedPkt->src] = receivedPkt->seq;

        signal Flooding.receivedFlooding(receivedPkt->src, (uint8_t *)receivedPkt->payload, payloadLen);

        if (receivedPkt->TTL > 0) {
            receivedPkt->TTL--;
            memcpy(call Packet.getPayload(&pkt, sizeof(pack)), receivedPkt, sizeof(pack));

            if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
                dbg(FLOODING_CHANNEL, "Rebroadcasting from node %u\n", TOS_NODE_ID);
            }
        }

        return msg;
    }
}
