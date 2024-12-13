module ChatAppServerP {
    provides interface ChatAppServer;

    uses interface TcpServer;

    uses interface List<chatroom_user> as users;
}

implementation {
    command error_t ChatAppServer.host(socket_port_t port) {
        call TcpServer.startServer(port);
    }

    event void TcpServer.processMessage(uint8_t* messageString) {
        dbg(CHAT_CHANNEL, "Processing: \"%s\"\n", messageString);

        // If "hello"...
        if (strncmp(messageString, "hello", 5) == 0) {
            chatroom_user user;
            socket_port_t port;
            uint8_t i;
            uint8_t name[USERNAME_LIMIT];

            if (sscanf(messageString, "hello %s %u", name, &port) < 2) {
                dbg(CHAT_CHANNEL, "Invalid 'hello'.\n");
                return;
            }
            
            strncpy(user.name, name, USERNAME_LIMIT);
            
            call users.pushback(user);

            dbg(CHAT_CHANNEL, "[%s] has joined the room. (source: %u) (%u/%u)\n",
                user.name, port,
                call users.size(), MAX_ROOM_SIZE);
        }
    }
}
