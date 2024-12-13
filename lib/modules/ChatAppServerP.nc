module ChatAppServerP {
    provides interface ChatAppServer;

    uses interface TcpServer;

    uses interface List<chatroom_user> as users;
}

implementation {
    command error_t ChatAppServer.host(socket_port_t port) {
        call TcpServer.startServer(port);
    }

    event void TcpServer.disconnected(socket_t clientSocket) {
        uint8_t i;

        for (i = 0; i < call users.size(); i++) {
            chatroom_user user = call users.get(i);
            if (user.socket == clientSocket) {
                call users.pop(i);

                dbg(CHAT_CHANNEL, "[%s] disconnected. (%u/%u)\n",
                    user.name,
                    call users.size(), MAX_ROOM_SIZE);

                break;
            }
        }
    }

    event void TcpServer.processMessage(socket_t clientSocket, uint8_t* messageString) {
        dbg(CHAT_CHANNEL, "Processing: \"%s\"\n", messageString);

        // If "hello"...
        if (strncmp(messageString, "hello", 5) == 0) {
            chatroom_user user;
            uint8_t i;
            uint8_t name[USERNAME_LIMIT];

            if (sscanf(messageString, "hello %s", name) < 1) {
                dbg(CHAT_CHANNEL, "Invalid 'hello'.\n");
                return;
            }
            
            strncpy(user.name, name, USERNAME_LIMIT);

            user.socket = clientSocket;
            
            call users.pushback(user);

            dbg(CHAT_CHANNEL, "[%s] has joined the room. (%u/%u)\n",
                user.name,
                call users.size(), MAX_ROOM_SIZE);
        }
    }
}
