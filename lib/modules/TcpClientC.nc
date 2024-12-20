configuration TcpClientC {
    provides interface TcpClient;
}

implementation {
    components TcpClientP;
    TcpClient = TcpClientP;

    components TransportC;
    TcpClientP.Transport -> TransportC;

    components new TimerMilliC() as writeTimer;
    TcpClientP.writeTimer -> writeTimer;
}