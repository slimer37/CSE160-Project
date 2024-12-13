module ChatAppClientP {
    provides interface ChatAppClient;

    uses interface TcpClient;
}

implementation {
    uint8_t clientUsername[16];

    command error_t ChatAppClient.join(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t* username) {
        strcpy(clientUsername, username);

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

        if (sscanf(messageString, "%*s %s %s") < 2) {
            dbg(CHAT_CHANNEL, "Couldn't parse: \"%s\"\n", messageString);
            return;
        }

        if (strncmp(messageString, "whisper", 7)) {
            dbg(CHAT_CHANNEL, "* <%s> %s\n", name, message);
        } else {
            dbg(CHAT_CHANNEL, "<%s> %s\n", name, message);
        }
    }
}
