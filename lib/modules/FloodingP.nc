#include "../../includes/protocol.h"

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

    // Start at 1 to pass check, since cache starts at 0
    uint16_t floodSeq = 1;

    uint16_t lastFloodSeq[256];

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) 
    {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    command void Flooding.floodSend(uint16_t dest, uint8_t *payload, uint8_t len) {
        pack *packet;

        if (busy == TRUE) {
            dbg(FLOODING_CHANNEL, "Already flooding\n");
            return;
        }

        packet = call Packet.getPayload(&pkt, sizeof(pack));

        makePack(packet, TOS_NODE_ID, dest, 10, PROTOCOL_FLOOD, floodSeq++, payload, len);

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

        // Duplicate packet checking
        if (lastFloodSeq[receivedPkt->src] >= receivedPkt->seq) {
            dbg(FLOODING_CHANNEL, "Duplicate packet from %u, ignored.\n", receivedPkt->src);
            return msg;
        }

        lastFloodSeq[receivedPkt->src] = receivedPkt->seq;

        // If we are the destination node, signal recieved event, do not rebroadcast
        if (receivedPkt->dest == TOS_NODE_ID) {
            signal Flooding.receivedFlooding(receivedPkt->src, receivedPkt->payload, payloadLen);
            return msg;
        }

        // Rebroadcast if TTL > 0
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
