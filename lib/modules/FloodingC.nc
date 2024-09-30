configuration FloodingC 
{
    provides interface Flooding;
}

implementation 
{
    components FloodingP;
    components new AMSenderC(AM_PACK) as AMSender;
    components new AMReceiverC(AM_PACK) as AMReceiver;
    components ActiveMessageC;

    Flooding = FloodingP;

    FloodingP.AMSend -> AMSender;
    FloodingP.AMPacket -> AMSender;
    FloodingP.Receive -> AMReceiver;
    FloodingP.Packet -> ActiveMessageC.Packet;
}
