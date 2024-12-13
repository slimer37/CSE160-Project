enum {
    USERNAME_LIMIT = 16,
    MAX_ROOM_SIZE = MAX_NUM_OF_SOCKETS - 1
};

typedef struct chatroom_user {
    socket_t socket;
    uint8_t name[USERNAME_LIMIT];
} chatroom_user;