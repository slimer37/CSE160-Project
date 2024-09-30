#include "../../includes/am_types.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP;
    Flooding = FloodingP;

    components new AMSenderC(AM_FLOODING);
    components new AMReceiverC(AM_FLOODING);

    FloodingP.AMSend -> AMSenderC;
    FloodingP.AMPacket -> AMSenderC;
    FloodingP.Receive -> AMReceiverC;
    FloodingP.Packet -> AMSenderC;
}
