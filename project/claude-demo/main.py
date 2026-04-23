# Demo application - Fibonacci calculator

import time
from functools import lru_cache


@lru_cache(maxsize=None)
def fibonacci(n: int) -> int:
    """Calculate the nth Fibonacci number."""
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)


def main():
    # First run — cache is cold
    fibonacci.cache_clear()
    start = time.perf_counter()
    for i in range(5000):
        fibonacci(i)
    cold = time.perf_counter() - start

    # Second run — fully cached
    start = time.perf_counter()
    for i in range(5000):
        fibonacci(i)
    warm = time.perf_counter() - start

    info = fibonacci.cache_info()
    print(f"Cache info: {info}")
    print(f"Cold run : {cold * 1000:.3f} ms")
    print(f"Warm run : {warm * 1000:.3f} ms")
    print(f"Speedup  : {cold / warm:.1f}x")
    print()
    for i in range(0, 2000, 50):
        print(f"fibonacci({i}) = {fibonacci(i)}")


if __name__ == "__main__":
    main()
