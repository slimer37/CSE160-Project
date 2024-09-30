configuration FloodingC {
    provides interface Flooding;
}

implementation {
    components FloodingP;
    Flooding = FloodingP;

    components new AMSenderC(AM_PACK);
    components new AMReceiverC(AM_PACK);

    FloodingP.AMSend -> AMSenderC;
    FloodingP.AMPacket -> AMSenderC;
    FloodingP.Receive -> AMReceiverC;
    FloodingP.Packet -> AMSenderC;
}
