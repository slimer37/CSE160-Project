configuration RoutedSendC {
    provides interface RoutedSend;
}

implementation {
    components RoutedSendP;
    RoutedSend = RoutedSendP;

    components new SimpleSendC(AM_ROUTING);
    RoutedSendP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    RoutedSendP.Receive -> AMReceiverC;

    components LinkStateRoutingC;
    RoutedSendP.LinkStateRouting -> LinkStateRoutingC;

    components new TimerMilliC() as resendTimer;
    RoutedSendP.resendTimer -> resendTimer;
}