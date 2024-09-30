/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node 
{
    uses interface Boot;

    uses interface SplitControl as AMControl;
    uses interface Receive;

    uses interface SimpleSend as Sender;

    uses interface Flooding;
    uses interface NeighborDiscovery;

    uses interface CommandHandler;
}

implementation 
{
    pack sendPackage;

    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    uint16_t neighborList[256]; 

    event void Boot.booted() 
    {
        call AMControl.start();
    }

    event void AMControl.startDone(error_t err) 
    {
        if (err == SUCCESS) 
        {
            dbg(GENERAL_CHANNEL, "Radio On\n");
            call NeighborDiscovery.startDiscovery();
        } 
        else 
        {
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) 
    {
        // Handle stop done event if needed
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) 
    {
        dbg(GENERAL_CHANNEL, "Packet Received\n");
        if (len == sizeof(pack)) 
        {
            pack* myMsg = (pack*) payload;
            dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
            return msg;
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }

    event void Flooding.receivedFlooding(uint16_t src, uint8_t *payload, uint8_t len) 
    {
        dbg(GENERAL_CHANNEL, "Flooding packet received from %u\n", src);
    }

    event void NeighborDiscovery.neighborDiscovered(uint16_t neighborAddr) 
    {
        dbg(NEIGHBOR_CHANNEL, "Neighbor discovered: %u\n", neighborAddr);
    }

    event void CommandHandler.ping(uint16_t destination, uint8_t *payload) 
    {
        error_t result;
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
        result = call Sender.send(sendPackage, destination);
        if (result != SUCCESS) 
        {
            dbg(GENERAL_CHANNEL, "Failed to send ping, error %d\n", result);
        }
    }

    event void CommandHandler.flood(uint16_t destination, uint8_t *payload)
    {
        dbg(GENERAL_CHANNEL, "FLOODING EVENT \n");
        call Flooding.floodSend(destination, payload, strlen(payload));
    }

    event void CommandHandler.printNeighbors() {
        uint8_t neighborCount;
        uint8_t i;

        // Get the neighbor list from NeighborDiscovery
        neighborCount = call NeighborDiscovery.getNeighbors(neighborList);

        dbg(GENERAL_CHANNEL, "Neighbors of node %u:\n", TOS_NODE_ID);

        if (neighborCount == 0) {
            dbg(GENERAL_CHANNEL, "No neighbors.\n");
        } 
        else {
            for (i = 0; i < neighborCount; i++) {
                dbg(GENERAL_CHANNEL, "- Node %u\n", neighborList[i]);
            }
        }
    }
    
    event void CommandHandler.printRouteTable() {}
    event void CommandHandler.printLinkState() {}
    event void CommandHandler.printDistanceVector() {}
    event void CommandHandler.setTestServer() {}
    event void CommandHandler.setTestClient() {}
    event void CommandHandler.setAppServer() {}
    event void CommandHandler.setAppClient() {}

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) 
    {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
}
