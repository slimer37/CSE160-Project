/**
 * ANDES Lab - University of California, Merced
 *
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC 
{
}

implementation 
{
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node.Boot -> MainC.Boot;
    Node.Receive -> GeneralReceive.Receive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC.SplitControl;

    components new SimpleSendC(AM_PACK) as SimpleSender;
    Node.Sender -> SimpleSender;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components FloodingC;
    components NeighborDiscoveryC;

    Node.Flooding -> FloodingC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;

    components LinkStateRoutingC;
    components RoutedSendC;

    Node.LinkStateRouting -> LinkStateRoutingC;
    Node.RoutedSend -> RoutedSendC;


    components TransportC;
    Node.Transport -> TransportC;

    components ChatAppServerC;
    Node.ChatAppServer -> ChatAppServerC;
    
    components ChatAppClientC;
    Node.ChatAppClient -> ChatAppClientC;
}
