// Cluster Standard Library: Zero-Cost Error Handling (std::result)
// Result[T, E] construction, inspection & error propagation primitives

fn ok(val: int) -> Result:
    return Ok(val)

fn err(msg: string) -> Result:
    return Err(msg, 1)

fn err_with_code(msg: string, code: int) -> Result:
    return Err(msg, code)

fn is_ok(r: Result) -> bool:
    return r.is_ok() == 1

fn is_err(r: Result) -> bool:
    return r.is_err() == 1

fn unwrap(r: Result) -> int:
    return r.unwrap()

fn unwrap_err(r: Result) -> string:
    return r.unwrap_err()

fn unwrap_or(r: Result, default_val: int) -> int:
    return r.unwrap_or(default_val)

fn err_code(r: Result) -> int:
    return r.err_code()
