configuration ChatAppServerC {
    provides interface ChatAppServer;
}

implementation {
    components ChatAppServerP;

    ChatAppServer = ChatAppServerP;

    components TcpServerC;

    ChatAppServerP.TcpServer -> TcpServerC;

    components new ListC(chatroom_user, MAX_ROOM_SIZE) as userList;

    ChatAppServerP.users -> userList;
}
