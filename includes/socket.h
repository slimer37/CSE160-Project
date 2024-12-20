#ifndef __SOCKET_H__
#define __SOCKET_H__

enum{
    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,
};

enum socket_state{
    CLOSED = 1,
    LISTEN = 2,
    ESTABLISHED = 3,
    SYN_SENT = 4,
    SYN_RCVD = 5,
    FIN_WAIT_1 = 6,
    FIN_WAIT_2 = 7,
    CLOSE_WAIT = 8,
    LAST_ACK = 9,
    CLOSING = 10
};

// helper func by Alfred
const char* getStateAsString(uint8_t state) {

    const char* stateLabels[] = {
        "CLOSED",
        "LISTEN",
        "ESTABLISHED",
        "SYN_SENT",
        "SYN_RCVD",
        "FIN_WAIT_1",
        "FIN_WAIT_2",
        "CLOSE_WAIT",
        "LAST_ACK",
        "CLOSING"
    };

    if (state == 0) {
        return "NULL";
    }

    if (state > 10) {
        return "UNKNOWN";
    }
    
    return stateLabels[state - 1];
}

typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;

// socket_addr_t is a simplified version of an IP connection.
typedef nx_struct socket_addr_t{
    nx_socket_port_t port;
    nx_uint16_t addr;
}socket_addr_t;


// File descripter id. Each id is associated with a socket_store_t
typedef uint8_t socket_t;

// State of a socket. 
typedef struct socket_store_t{
    uint8_t flag;
    enum socket_state state;
    socket_port_t src;
    socket_addr_t dest;

    // This is the sender portion.
    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastWritten;
    uint8_t lastAck;
    uint8_t lastSent;

    // This is the receiver portion
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastRead;
    uint8_t lastRcvd;
    uint8_t nextExpected;

    uint16_t RTT;
    uint8_t effectiveWindow;
}socket_store_t;

#endif
