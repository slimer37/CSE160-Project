module RoutedSendP {
    provides interface RoutedSend;

    uses interface SimpleSend;

    uses interface Receive;

    uses interface LinkStateRouting;
}

implementation {
    pack packet;
    uint8_t floodSeq;

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

        makePack(&packet, TOS_NODE_ID, dest, MAX_TTL, protocol, floodSeq++, payload, len);

        nextHop = call LinkStateRouting.getNextHop(dest);

        if (nextHop == 0) {
            dbg(ROUTING_CHANNEL, "Destination %u currently unreachable from %u\n", dest, TOS_NODE_ID);
            return;
        }

        if (call SimpleSend.send(packet, nextHop) == SUCCESS) {
            dbg(ROUTING_CHANNEL, "Routing \"%s\" from %u to %u through %u\n", payload, TOS_NODE_ID, dest, nextHop);
        } else {
            dbg(ROUTING_CHANNEL, "Failed to send\n");
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        uint16_t nextHop;
        pack *receivedPacket = (pack*)payload;

        if (receivedPacket->dest == TOS_NODE_ID) {
            signal RoutedSend.received(receivedPacket->src, receivedPacket, len);
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