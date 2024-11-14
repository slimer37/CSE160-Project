#ifndef TCP_PACKET_H
#define TCP_PACKET_H

typedef nx_struct tcp_pack {
    nx_uint8_t flags;
    nx_uint8_t sequenceNum;
    nx_uint8_t acknowledgement;
    nx_uint8_t advertisedWindow;
    nx_uint16_t data;
}

#endif