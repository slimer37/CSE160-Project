configuration ChatAppClientC {
    provides interface ChatAppClient;
}

implementation {
    components ChatAppClientP;

    ChatAppClient = ChatAppClientP;

    components TcpClientC;

    ChatAppClientP.TcpClient -> TcpClientC;
}
