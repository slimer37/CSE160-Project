// File: FloodingC.nc

#include "../../includes/am_types.h"

configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP;
    Flooding = FloodingP;

    components new AMReceiverC(AM_FLOODING);
    components new TimerMilliC();

    components new SimpleSendC(AM_FLOODING) as SimpleSend;

    FloodingP.SimpleSend -> SimpleSend;

    FloodingP.Receive -> AMReceiverC;

    FloodingP.resendTimer -> TimerMilliC;
}
