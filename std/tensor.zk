// Cluster Standard Library: High-Performance Multi-Dimensional Tensors (std::tensor)
// SIMD Cache-Optimized Linear Algebra & Matrix Math

fn zeros(rows: int, cols: int) -> tensor:
    return tensor_zeros(rows, cols)

fn ones(rows: int, cols: int) -> tensor:
    return tensor_ones(rows, cols)

fn fill(rows: int, cols: int, val: float) -> tensor:
    return tensor_fill(rows, cols, val)

fn eye(n: int) -> tensor:
    t := tensor_zeros(n, n)
    i := 0
    while i < n:
        t.set(i, i, 1.0)
        i = i + 1
    return t

fn from_vector(rows: int, cols: int, &v: vector[float]) -> tensor:
    t := tensor_zeros(rows, cols)
    r := 0
    idx := 0
    total := rows * cols
    while r < rows:
        c := 0
        while c < cols:
            if idx < list_size(v):
                t.set(r, c, v[idx])
                idx = idx + 1
            c = c + 1
        r = r + 1
    return t

fn to_vector(t: tensor) -> vector[float]:
    v: vector[float] = []
    r := 0
    rows := t.rows()
    cols := t.cols()
    while r < rows:
        c := 0
        while c < cols:
            list_push(v, t.get(r, c))
            c = c + 1
        r = r + 1
    return v

fn matmul(a: tensor, b: tensor) -> tensor:
    return a @ b

fn transpose(t: tensor) -> tensor:
    return t.transpose()

fn sum(t: tensor) -> float:
    return t.sum()

fn dot(a: tensor, b: tensor) -> float:
    return a.dot(b)
