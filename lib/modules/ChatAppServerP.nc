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

    bool findUserBySocket(socket_t match, chatroom_user* outUser) {
        uint8_t i;

        for (i = 0; i < call users.size(); i++) {
            chatroom_user user = call users.get(i);

            if (user.socket == match) {
                *outUser = user;
                return TRUE;
            }
        }

        return FALSE;
    }

    event void TcpServer.disconnected(socket_t clientSocket) {
        uint8_t i;

        chatroom_user user;

        if (!findUserBySocket(clientSocket, &user)) {
            dbg(CHAT_CHANNEL, "Unknown user disconnected.\n");
            return;
        }

        dbg(CHAT_CHANNEL, "[%s] disconnected. (%u/%u)\n",
            user.name,
            call users.size(), MAX_ROOM_SIZE);
    }

    event void TcpServer.processMessage(socket_t clientSocket, uint8_t* messageString) {
        chatroom_user user;
        uint8_t reply[64];

        dbg(CHAT_CHANNEL, "Processing: \"%s\"\n", messageString);

        // If "hello"...
        if (strncmp(messageString, "hello", 5) == 0) {
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
            uint8_t message[32];

            findUserBySocket(clientSocket, &user);

            if (sscanf(messageString, "msg %s", message) < 1) {
                dbg(CHAT_CHANNEL, "Invalid 'msg'.\n");
                return;
            }

            sprintf(reply, "msg %s %s", user.name, message);

            dbg(CHAT_CHANNEL, "Broadcasting \"%s\"\n", reply);
            call TcpServer.writeBroadcast(reply, strlen(reply));
            call TcpServer.writeBroadcast("\r\n", 2);
        }

        else if (strncmp(messageString, "whisper", 7) == 0) {
            uint8_t name[USERNAME_LIMIT];
            uint8_t message[32];
            chatroom_user targetUser;

            if (sscanf(messageString, "whisper %s %s", name, message) < 1) {
                dbg(CHAT_CHANNEL, "Invalid 'whisper'.\n");
                return;
            }

            if (!findUserByName(name, &targetUser)) {
                dbg(CHAT_CHANNEL, "No user \"%s\" was found.\n", name);
                return;
            }

            findUserBySocket(clientSocket, &user);

            sprintf(reply, "whisper %s %s", user.name, message);

            dbg(CHAT_CHANNEL, "Unicasting \"%s\" to \"%s\"\n", reply, name);

            call TcpServer.writeUnicast(targetUser.socket, reply, strlen(reply));
            call TcpServer.writeUnicast(targetUser.socket, "\r\n", 2);
        }

        else if (strcmp(messageString, "listusr") == 0) {
            uint8_t i;
            uint8_t numUsers = call users.size();

            // Create string of list of users starting with "listUsrReply"

            strcpy(reply, "listUsrReply ");

            for (i = 0; i < numUsers; i++) {
                chatroom_user user = call users.get(i);

                strcat(reply, user.name);

                if (i < numUsers - 1) {
                    strcat(reply, "\n");
                }
            }

            dbg(CHAT_CHANNEL, "Responding to listusr.\n");

            // Respond with list
            call TcpServer.writeUnicast(clientSocket, reply, strlen(reply));
            call TcpServer.writeUnicast(clientSocket, "\r\n", 2);
        }
    }
}
