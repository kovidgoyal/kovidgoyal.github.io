#!/usr/bin/env -S kitty +launch
# License: GPLv3 Copyright: 2024, Kovid Goyal <kovid at kovidgoyal.net>

import gc
import os
from base64 import standard_b64encode
from time import perf_counter_ns
from multiprocessing import Pool, set_start_method, sharedctypes

from kitty.fast_data_types import base64_encode  # type: ignore

base64_chars = b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'


def naive(input_bytes: bytes) -> bytes:
    i = 0
    while len(input_bytes) > 2:
        triple = (input_bytes[0] << 16) + (input_bytes[1] << 8) + input_bytes[2]
        input_bytes = input_bytes[3:]

        output[i] = base64_chars[(triple >> 18) & 63]
        output[i+1] = base64_chars[(triple >> 12) & 63]
        output[i+2] = base64_chars[(triple >> 6) & 63]
        output[i+3] = base64_chars[triple & 63]
        i += 4
    return bytes(output)


def noslice_part(input_bytes: memoryview, output: memoryview) -> None:
    i = 0
    for j in range(0, len(input_bytes), 3):
        triple = (input_bytes[j] << 16) + (input_bytes[j+1] << 8) + input_bytes[j+2]

        output[i] = base64_chars[(triple >> 18) & 63]
        output[i+1] = base64_chars[(triple >> 12) & 63]
        output[i+2] = base64_chars[(triple >> 6) & 63]
        output[i+3] = base64_chars[triple & 63]
        i += 4


def noslice(input_bytes: bytes) -> bytes:
    noslice_part(memoryview(input_bytes), memoryview(output))
    return bytes(output)


def do_chunk(func, i: int) -> None:
    input_buffer = memoryview(input_data)
    chunk_size = len(input_buffer) // num_workers
    input_chunk = input_buffer[i * chunk_size:(i + 1) * chunk_size]
    chunk_size = len(output) // num_workers
    output_chunk = output[i * chunk_size:(i + 1) * chunk_size]
    func(input_chunk, output_chunk)


def parallel(input_bytes: bytes, func = noslice_part) -> bytes:
    if len(input_bytes) < 3 * num_workers:
        return func(input_bytes)
    pool.starmap(do_chunk, ((func, i) for i in range(num_workers)))
    return bytes(output)


def memview(input_bytes: bytes) -> bytes:
    input_bytes = memoryview(input_bytes)
    o = memoryview(output)
    while len(input_bytes) > 2:
        triple = (input_bytes[0] << 16) + (input_bytes[1] << 8) + input_bytes[2]
        input_bytes = input_bytes[3:]

        o[0] = base64_chars[(triple >> 18) & 63]
        o[1] = base64_chars[(triple >> 12) & 63]
        o[2] = base64_chars[(triple >> 6) & 63]
        o[3] = base64_chars[triple & 63]
        o = o[4:]
    return bytes(output)


def parallel_noslice(input_bytes: bytes) -> bytes:
    return parallel(input_bytes, noslice_part)


def time_func(func, *args, number):
    st = perf_counter_ns()
    for i in range(number):
        func(*args)
    return (perf_counter_ns() - st) / (number * 1e9)


def rate_of(f, input_data, number=1024):
    t = time_func(f, input_data, number=number)
    rate = len(input_data) / t
    KB = 1024
    MB = KB * KB
    GB = KB * MB
    if rate >= GB:
        rate = f'{rate / GB:8.1f} GB/s'
    elif rate >= MB:
        rate = f'{rate / MB:8.1f} MB/s'
    else:
        rate = f'{rate / KB:8.1f} KB/s'
    print(f'Rate of {f.__name__:22s}: {rate}')


gc.disable()
set_start_method('fork')
num_workers = os.cpu_count() or 1
print(f'Number of workers: {num_workers}')
input_data = os.urandom(3 * (4 * num_workers) * 1024)  # must be multiple of 3 as the python implementation assumes that for simplicity
buffer = sharedctypes.RawArray('B', 4 * len(input_data) // 3)
output = memoryview(buffer).cast('B')
pool = Pool(num_workers)
try:
    for f in (base64_encode, standard_b64encode, parallel_noslice, noslice, memview, naive):
        assert f(b'abcdef' * num_workers) == standard_b64encode(b'abcdef' * num_workers)
        rate_of(f, input_data)
except KeyboardInterrupt:
    raise SystemExit(1)
