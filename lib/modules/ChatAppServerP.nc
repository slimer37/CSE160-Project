module ChatAppServerP {
    provides interface ChatAppServer;

    uses interface TcpServer;

    uses interface List<chatroom_user> as users;
}

implementation {
    command error_t ChatAppServer.host(socket_port_t port) {
        call TcpServer.startServer(port);
    }

    bool findUserByName(const uint8_t* match, chatroom_user* outUser) {
        uint8_t i;

        for (i = 0; i < call users.size(); i++) {
            chatroom_user user = call users.get(i);

            if (strcmp(user.name, match) == 0) {
                *outUser = user;
                return TRUE;
            }
        }

        return FALSE;
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

        else if (strncmp(messageString, "msg", 3) == 0) {
            dbg(CHAT_CHANNEL, "Broadcasting \"%s\"\n", messageString);
            call TcpServer.writeBroadcast(messageString, strlen(messageString));
            call TcpServer.writeBroadcast("\r\n", 2);
        }

        else if (strncmp(messageString, "whisper", 7) == 0) {
            uint8_t name[USERNAME_LIMIT];
            chatroom_user user;

            if (sscanf(messageString, "whisper %s %*s", name) < 1) {
                dbg(CHAT_CHANNEL, "Invalid 'whisper'.\n");
                return;
            }

            if (!findUserByName(name, &user)) {
                dbg(CHAT_CHANNEL, "No user \"%s\" was found.", name);
                return;
            }

            dbg(CHAT_CHANNEL, "Unicasting \"%s\" to \"%s\"\n", messageString, name);

            call TcpServer.writeUnicast(user.socket, messageString, strlen(messageString));
            call TcpServer.writeUnicast(user.socket, "\r\n", 2);
        }
    }
}
