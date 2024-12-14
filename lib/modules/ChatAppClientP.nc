module ChatAppClientP {
    provides interface ChatAppClient;

    uses interface TcpClient;
}

implementation {
    uint8_t clientUsername[USERNAME_LIMIT];

    command error_t ChatAppClient.join(uint8_t srcPort, uint16_t dest, uint8_t destPort, uint8_t* username) {
        strncpy(clientUsername, username, USERNAME_LIMIT); //copy username into clientUserame array

        if (strlen(username) > USERNAME_LIMIT) { //check username against length limit and trim if necessary
            dbg(CHAT_CHANNEL, "Username \"%s\" is too long; trimmed to \"%s\".", username, clientUsername);
        }

        call TcpClient.startClient(srcPort, dest, destPort);
    }

    event void TcpClient.ready() { //called when connection to server is ready
        uint8_t msg[32];

        sprintf(msg, "hello %s\r\n", clientUsername); //create initial hello message

        call TcpClient.writeString(msg); //write to TcpClient to send msg to server

        dbg(CHAT_CHANNEL, "Joined the room.\n");
    }

    command void ChatAppClient.sendCommand(uint8_t* com) {
        call TcpClient.write(com, strlen(com)); //send msg to server
    }

    event void TcpClient.processMessage(socket_t sourceSocket, uint8_t* messageString) {
        uint8_t name[USERNAME_LIMIT];
        uint8_t message[32];

        if (strncmp(messageString, "listUsrReply", 12) == 0) { //if message is list of users
            dbg(CHAT_CHANNEL, "User list:\n%s\n", messageString + 12); //pring list of users
            return;
        }

        if (sscanf(messageString, "%*s %s %s", name, message) < 2) { //ignore first word (msg type specifier), get second word as name, get rest of message as message
            dbg(CHAT_CHANNEL, "Couldn't parse: \"%s\"\n", messageString); //if name and message not filled out
            return;
        }

        dbg(CHAT_CHANNEL, "%s chatlog:\n", clientUsername);

        if (strncmp(messageString, "whisper", 7) == 0) { //if message type is whisper
            dbg(CHAT_CHANNEL, "    %s whispers to you: %s\n", name, message);
        } else { //if message type is msg
            dbg(CHAT_CHANNEL, "    <%s> %s\n", name, message);
        }

        dbg(CHAT_CHANNEL, "\n");
    }
}
