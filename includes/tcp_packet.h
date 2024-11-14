#ifndef TCP_PACKET_H
#define TCP_PACKET_H

#define ATTEMPT_CONNECTION_TIME 500

typedef nx_struct tcp_pack {
    socket_addr_t source;
    socket_addr_t dest;
    nx_uint8_t flags;
    nx_uint8_t sequenceNum;
    nx_uint8_t acknowledgement;
    nx_uint8_t advertisedWindow;
    nx_uint16_t data;
} tcp_pack;

#endif