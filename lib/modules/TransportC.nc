configuration TransportC {
    provides interface Transport;
}

implementation {
    components TransportP;
    Transport = TransportP;

    components RoutedSendC;
    TransportP.RoutedSend -> RoutedSendC;
}