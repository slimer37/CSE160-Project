interface LinkStateRouting {
    command void printRoutingTable();
    command void startTimer();

    command uint16_t getNextHop(uint16_t dest);
}
