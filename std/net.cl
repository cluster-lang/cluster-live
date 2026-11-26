// ==============================================================================
// Cluster Standard Library: Network (TCP Sockets)
// 100% Pure Cluster Language API wrapping native socket primitives
// ==============================================================================

fn tcp_listen(port: int) -> int:
    return net_listen(port)

fn tcp_accept(server_fd: int) -> int:
    return net_accept(server_fd)

fn tcp_read(client_fd: int, max_bytes: int) -> string:
    return net_read(client_fd, max_bytes)

fn tcp_write(client_fd: int, payload: string) -> int:
    return net_write(client_fd, payload)

fn tcp_close(fd: int) -> void:
    net_close(fd)

fn tcp_connect(host: string, port: int) -> int:
    return net_connect(host, port)
