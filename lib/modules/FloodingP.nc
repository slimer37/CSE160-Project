#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module FloodingP {
    provides interface Flooding;
    
    uses interface SimpleSend;
    uses interface Receive;
    uses interface Packet;
    uses interface Timer<TMilli> as resendTimer;
}

implementation {
    bool busy = FALSE;
    pack packet;
    pack ackPacket;
    uint16_t floodSeq = 1; // Start at 1
    uint16_t lastFloodSeq[256];
    uint8_t maxRetransmissions = 3;
    uint8_t retransmissionCount = 0;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint8_t TTL, uint8_t protocol, uint16_t seq, uint8_t *payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    void sendAck(uint16_t dest, uint16_t seq) {
        // Put the sequence number of the original message as the payload
        makePack(&ackPacket, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_FLOODREPLY, floodSeq++, (uint8_t*)&seq, 2);

        dbg(FLOODING_CHANNEL, "Formed ack pack with seq: %u\n", *(uint16_t*)ackPacket.payload);

        if (call SimpleSend.send(ackPacket, AM_BROADCAST_ADDR) == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Sending ACK to %u\n", dest);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send ACK to %u\n", dest);
        }
    }

    command void Flooding.floodSend(uint16_t dest, uint8_t *payload, uint8_t len) {
        if (busy) {
            dbg(GENERAL_CHANNEL, "Already flooding\n");
            return;
        }

        if (len > PACKET_MAX_PAYLOAD_SIZE) {
            dbg(GENERAL_CHANNEL, "Payload too large, max size is %u\n", PACKET_MAX_PAYLOAD_SIZE);
            return;
        }

        makePack(&packet, TOS_NODE_ID, dest, 10, PROTOCOL_FLOOD, floodSeq++, payload, len);

        if (call SimpleSend.send(packet, AM_BROADCAST_ADDR) == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Flooding started from node %u to dest %u\n", TOS_NODE_ID, dest);
            busy = TRUE;
            // Start the timer for retransmission
            retransmissionCount = 0;
            call resendTimer.startOneShot(1000); // 1 second timer
        } 
        else {
            dbg(FLOODING_CHANNEL, "Failed to start flooding\n");
        }
    }

    event void resendTimer.fired() {
        if (retransmissionCount < maxRetransmissions) {
            packet.seq = floodSeq++;
            if (call SimpleSend.send(packet, AM_BROADCAST_ADDR) == SUCCESS) {
                dbg(FLOODING_CHANNEL, "Retransmitting flood from node %u to dest %u\n", TOS_NODE_ID, packet.dest);
                retransmissionCount++;
                call resendTimer.startOneShot(1000); // Restart timer
            } else {
                dbg(FLOODING_CHANNEL, "Failed to retransmit flood\n");
            }
        } else {
            dbg(FLOODING_CHANNEL, "Max retransmissions reached\n");
            busy = FALSE;
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack *receivedPkt = (pack *) payload;

        // Propagate all floods/flood replies
        if (receivedPkt->protocol == PROTOCOL_FLOOD || receivedPkt->protocol == PROTOCOL_FLOODREPLY) {
            // Source check
            if (receivedPkt->src == TOS_NODE_ID) {
                return msg;
            }

            // Duplicate packet checking
            if (lastFloodSeq[receivedPkt->src] >= receivedPkt->seq) {
                dbg(FLOODING_CHANNEL, "Duplicate flood packet from %u, ignored.\n", receivedPkt->src);
                return msg;
            }

            lastFloodSeq[receivedPkt->src] = receivedPkt->seq;

            // If we are the destination node, send ACK and signal event
            // AND support total intentional flooding through AM_BROADCAST_ADDR
            if (receivedPkt->dest == TOS_NODE_ID || receivedPkt->dest == AM_BROADCAST_ADDR) {
                if (receivedPkt->protocol == PROTOCOL_FLOODREPLY) {
                    // Handle ACK packet
                    if (*(uint16_t*)receivedPkt->payload == floodSeq - 1) {
                        dbg(FLOODING_CHANNEL, "Received ACK from %u\n", receivedPkt->src);
                        // Stop retransmission timer
                        call resendTimer.stop();
                        busy = FALSE;
                    }
                }
                else {
                    // Send ACK back to source
                    sendAck(receivedPkt->src, receivedPkt->seq);

                    // fix len
                    signal Flooding.receivedFlooding(receivedPkt->src, receivedPkt->payload, len);
                }

                return msg;
            }

            // Rebroadcast if TTL > 0
            if (receivedPkt->TTL > 0) {
                receivedPkt->TTL--;

                if (call SimpleSend.send(*receivedPkt, AM_BROADCAST_ADDR) == SUCCESS) {
                    dbg(FLOODING_CHANNEL, "Rebroadcasting flood started by %u\n", receivedPkt->src, TOS_NODE_ID);
                } else {
                    dbg(FLOODING_CHANNEL, "Failed to rebroadcast flood started by %u\n", receivedPkt->src);
                }
            } else {
                dbg(FLOODING_CHANNEL, "TTL 0, packet from %u died.\n", receivedPkt->src);
            }
        }

        return msg;
    }
}
