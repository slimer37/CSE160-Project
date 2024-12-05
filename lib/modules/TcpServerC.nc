configuration TcpServerC {
    provides interface TcpServer;
}

implementation {
    components TcpServerP;
    TcpServer = TcpServerP;

    components TransportC;
    TcpServerP.Transport -> TransportC;

    components new TimerMilliC() as acceptConnectionTimer;
    TcpServerP.acceptConnectionTimer -> acceptConnectionTimer;
}