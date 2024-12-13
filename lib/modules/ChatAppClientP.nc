module ChatAppClientP {
    provides interface ChatAppClient;

    uses interface TcpClient;
}

implementation {
    uint8_t clientUsername[USERNAME_LIMIT];

    command error_t ChatAppClient.join(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t* username) {
        strncpy(clientUsername, username, USERNAME_LIMIT);

        if (strlen(username) > USERNAME_LIMIT) {
            dbg(CHAT_CHANNEL, "Username \"%s\" is too long; trimmed to \"%s\".", username, clientUsername);
        }

        call TcpClient.startClient(srcPort, dest, destPort);
    }

    event void TcpClient.ready() {
        uint8_t msg[32];

        sprintf(msg, "hello %s\r\n", clientUsername);

        call TcpClient.writeString(msg);

        dbg(CHAT_CHANNEL, "Joined the room.\n");
    }

    command void ChatAppClient.sendCommand(uint8_t* com) {
        call TcpClient.write(com, strlen(com));
    }

    event void TcpClient.processMessage(socket_t sourceSocket, uint8_t* messageString) {
        uint8_t name[USERNAME_LIMIT];
        uint8_t message[32];

        if (sscanf(messageString, "%*s %s %s", name, message) < 2) {
            dbg(CHAT_CHANNEL, "Couldn't parse: \"%s\"\n", messageString);
            return;
        }

        dbg(CHAT_CHANNEL, "%s chatlog:\n", clientUsername);

        if (strncmp(messageString, "whisper", 7) == 0) {
            dbg(CHAT_CHANNEL, "    %s whispers to you: %s\n", name, message);
        } else {
            dbg(CHAT_CHANNEL, "    <%s> %s\n", name, message);
        }

        dbg(CHAT_CHANNEL, "\n");
    }
}
