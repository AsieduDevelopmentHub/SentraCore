"""Tests for engine runtime / port selection."""

import socket

from engine.runtime_info import find_first_free_tcp_port


def test_find_first_free_tcp_port_returns_bindable():
    host = "127.0.0.1"
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as b0:
        b0.bind((host, 0))
        start = b0.getsockname()[1]

    found = find_first_free_tcp_port(host, start)
    assert found >= start
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as verify:
        verify.bind((host, found))
