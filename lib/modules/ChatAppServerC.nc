configuration ChatAppServerC {
    provides interface ChatAppServer;
}

implementation {
    components ChatAppServerP;

    ChatAppServer = ChatAppServerP;

    components TcpServerC;

    ChatAppServerP.TcpServer -> TcpServerC;
}
