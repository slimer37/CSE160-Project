module RoutedSendP {
    provides interface RoutedSend;

    uses interface SimpleSend;

    uses interface Receive;

    uses interface LinkStateRouting;

    uses interface Timer<TMilli> as resendTimer;
}

#define DISABLE_ACKS FALSE
#define MAX_RETRIES 10
#define MAX_UNACKED 10

implementation {
    pack packet;
    uint16_t sequenceNum;

    pack unackedPacks[MAX_UNACKED];
    uint8_t retries[MAX_UNACKED];
    uint8_t numUnacked = 0;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint8_t TTL, uint8_t protocol, uint16_t seq, uint8_t *payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
    
    command void RoutedSend.send(uint16_t dest, uint8_t *payload, uint8_t len, uint8_t protocol) {
        uint16_t nextHop;

        makePack(&packet, TOS_NODE_ID, dest, MAX_TTL, protocol, sequenceNum++, payload, len);

        nextHop = call LinkStateRouting.getNextHop(dest);

        if (nextHop == 0) {
            dbg(ROUTING_CHANNEL, "Destination %u currently unreachable from %u\n", dest, TOS_NODE_ID);
            return;
        }

        if (call SimpleSend.send(packet, nextHop) == SUCCESS) {
            dbg(ROUTING_CHANNEL, "Routing \"%s\" from %u to %u through %u (%u unacked)\n", payload, TOS_NODE_ID, dest, nextHop, numUnacked);

            if (protocol == PROTOCOL_PINGREPLY) return;

            if (numUnacked == MAX_UNACKED - 1) {
                dbg(ROUTING_CHANNEL, "(Too many unacked)\n");
            } else {
                memcpy(unackedPacks + numUnacked, &packet, sizeof(pack));
                numUnacked++;
            }
        } else {
            dbg(ROUTING_CHANNEL, "Failed to send\n");
        }

        if (DISABLE_ACKS) return;

        if (!call resendTimer.isRunning()) {
            call resendTimer.startPeriodic(1000);
        }
    }

    event void resendTimer.fired() {
        uint16_t nextHop;
        pack *resentPack;
        uint8_t i = 0;

        if (numUnacked == 0) return;

        retries[i]++;

        if (retries[i] > MAX_RETRIES) {
            numUnacked--;

            for (; i < numUnacked - 1; i++) {
                unackedPacks[i] = unackedPacks[i + 1];
                retries[i] = retries[i + 1];
            }

            retries[numUnacked - 1] = 0;

            return;
        }

        resentPack = &unackedPacks[i];
        resentPack->seq = sequenceNum++;
        nextHop = call LinkStateRouting.getNextHop(resentPack->dest);

        if (call SimpleSend.send(*resentPack, nextHop) == SUCCESS) {
            dbg(GENERAL_CHANNEL, "[An unacked message is being resent to %u]\n", resentPack->dest);
            dbg(ROUTING_CHANNEL, "(Unacked repeat [%u]) Routing \"%s\" from %u to %u through %u\n", numUnacked, resentPack->payload, TOS_NODE_ID, resentPack->dest, nextHop);
        } else {
            dbg(ROUTING_CHANNEL, "Failed to resend\n");
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        uint16_t nextHop;
        pack *receivedPacket = (pack*)payload;

        if (receivedPacket->dest == TOS_NODE_ID) {

            if (receivedPacket->protocol == PROTOCOL_PINGREPLY) {
                uint8_t i;
                bool found;
                uint8_t firstResolved;
                uint16_t ackedSeq = *(uint16_t*)receivedPacket->payload;

                if (numUnacked == 0) return msg;

                for (i = 0; i < numUnacked; i++) {
                    if (unackedPacks[i].seq <= ackedSeq) {
                        numUnacked--;
                        found = TRUE;
                    }

                    if (unackedPacks[i].seq == ackedSeq) {
                        break;
                    }
                }

                if (!found) {
                    dbg(ROUTING_CHANNEL, "Failed to match ack packet from %u for seq %u\n", receivedPacket->src, ackedSeq);
                } else {
                    dbg(ROUTING_CHANNEL, "Received ack packet from %u matching %u/%u (seq %u)\n", receivedPacket->src, i, numUnacked, ackedSeq);
                }

                for (i = firstResolved; i < numUnacked - 1; i++) {
                    unackedPacks[i] = unackedPacks[i + 1];
                    retries[i] = retries[i + 1];
                }
            }
            else {
                pack ack;
                uint8_t array[2];
                array[0] = receivedPacket->seq & 0xff;
                array[1] = (receivedPacket->seq >> 8);

                signal RoutedSend.received(receivedPacket->src, receivedPacket, len);

                dbg(ROUTING_CHANNEL, "Acking packet from %u, seq %u\n", receivedPacket->src, receivedPacket->seq);

                call RoutedSend.send(receivedPacket->src, array, 2, PROTOCOL_PINGREPLY);
            }
            
            return msg;
        }

        nextHop = call LinkStateRouting.getNextHop(receivedPacket->dest);

        if (call SimpleSend.send(*receivedPacket, nextHop) == SUCCESS) {
            dbg(ROUTING_CHANNEL, "Fwd packet for %u from %u to %u\n", receivedPacket->dest, TOS_NODE_ID, nextHop);
        } else {
            dbg(ROUTING_CHANNEL, "Failed to forward packet from %u\n", receivedPacket->src);
        }

        return msg;
    }
}