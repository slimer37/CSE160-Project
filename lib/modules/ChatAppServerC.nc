configuration ChatAppServerC {
    provides interface ChatAppServer;
}

implementation {
    components ChatAppServerP;

    ChatAppServer = ChatAppServerP;
}
