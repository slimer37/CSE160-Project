#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module FloodingP {
    provides interface Flooding;
    
    uses interface AMSend;
    uses interface AMPacket;
    uses interface Receive;
    uses interface Packet;
    uses interface Timer<TMilli> as resendTimer;
}

implementation {
    bool busy = FALSE;
    message_t pkt;
    message_t ackPkt;
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
        pack *ackPacket;
        ackPacket = call Packet.getPayload(&ackPkt, sizeof(pack));
        
        // Put the sequence number of the original message as the payload
        makePack(ackPacket, TOS_NODE_ID, dest, 10, PROTOCOL_FLOODREPLY, floodSeq++, (uint8_t*)&seq, 2);

        dbg(FLOODING_CHANNEL, "Formed ack pack with seq: %u\n", *(uint16_t*)ackPacket->payload);

        if (call AMSend.send(AM_BROADCAST_ADDR, &ackPkt, sizeof(pack)) == SUCCESS) {
            dbg(FLOODING_CHANNEL, "Sending ACK to %u\n", dest);
        } else {
            dbg(FLOODING_CHANNEL, "Failed to send ACK to %u\n", dest);
        }
    }

    command void Flooding.floodSend(uint16_t dest, uint8_t *payload, uint8_t len) {
        pack *packet;

        if (busy == TRUE) {
            dbg(FLOODING_CHANNEL, "Already flooding\n");
            return;
        }

        if (len > PACKET_MAX_PAYLOAD_SIZE) {
            dbg(FLOODING_CHANNEL, "Payload too large, max size is %u\n", PACKET_MAX_PAYLOAD_SIZE);
            return;
        }

        packet = call Packet.getPayload(&pkt, sizeof(pack));

        makePack(packet, TOS_NODE_ID, dest, 10, PROTOCOL_FLOOD, floodSeq++, payload, len);

        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
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
            pack *packet;
            packet = call Packet.getPayload(&pkt, sizeof(pack));
            packet->seq = floodSeq++;
            if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
                dbg(FLOODING_CHANNEL, "Retransmitting flood from node %u to dest %u\n", TOS_NODE_ID, packet->dest);
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

    event void AMSend.sendDone(message_t *msg, error_t error) {
        if (msg == &pkt) {
            // Flood message send done
            if (error == SUCCESS) {
                dbg(FLOODING_CHANNEL, "Flood message sent\n");
            } else {
                dbg(FLOODING_CHANNEL, "Flood message failed to send\n");
            }
        } else if (msg == &ackPkt) {
            // ACK message send done
            if (error == SUCCESS) {
                dbg(FLOODING_CHANNEL, "ACK message sent\n");
            } else {
                dbg(FLOODING_CHANNEL, "ACK message failed to send\n");
            }
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

                    signal Flooding.receivedFlooding(receivedPkt->src, (uint8_t*)receivedPkt->payload, len);
                }

                return msg;
            }

            // Rebroadcast if TTL > 0
            if (receivedPkt->TTL > 0) {
                receivedPkt->TTL--;

                memcpy(call Packet.getPayload(&pkt, sizeof(pack)), receivedPkt, sizeof(pack));

                if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(pack)) == SUCCESS) {
                    dbg(FLOODING_CHANNEL, "Rebroadcasting flood started by %u from node %u\n", receivedPkt->src, TOS_NODE_ID);
                }
            } else {
                dbg(FLOODING_CHANNEL, "TTL 0, packet from %u died.\n", receivedPkt->src);
            }
        }

        return msg;
    }
}
