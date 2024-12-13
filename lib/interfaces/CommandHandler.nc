interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t port);
   event void setTestClient(uint8_t srcPort, uint8_t dest, uint8_t destPort, uint8_t* username);
   event void closeSocket(uint8_t srcPort, uint8_t dest, uint8_t destPort);
   event void sendChatCommand(uint8_t* com);
   event void setAppServer();
   event void setAppClient();

   // Custom events
   event void flood(uint16_t destination, uint8_t *payload);
}
