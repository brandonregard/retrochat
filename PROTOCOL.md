# RetroChat protocol version 1

Transport is TCP. Each record is one LF-terminated line:

```text
COMMAND hex(field1) hex(field2) ...
```

Commands:

- `HELLO nickname version`
- `CHAT nickname message`
- `FILE_BEGIN transfer-id filename byte-count nickname`
- `FILE_CHUNK transfer-id bytes`
- `FILE_END transfer-id`

Every field is hexadecimal with no prefix. The server validates record syntax and
relays recognized records to all clients, including the sender. A transfer ID is
opaque and needs to be unique only for the duration of connected sessions.

Version 1 is a trusted-LAN protocol. It does not authenticate claimed nicknames or
bind file records to the client that started a transfer.
