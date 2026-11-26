// ==============================================================================
// Cluster World Chunk & 3D Spatial Physics Grid (.clw) - Standard Pure Cluster Module
// Universal spatial document format for voxels, rigidbodies, collision, and physics engines
// ==============================================================================

model ClwMaterial:
    id: int
    name: string
    solid: int
    friction: float
    restitution: float
    density: float

model ClwChunk:
    cx: int
    cy: int
    cz: int
    size: int
    blocks: vector[int]

model ClwWorld:
    name: string
    cell_size: float
    chunk_size: int
    gravity_x: float
    gravity_y: float
    gravity_z: float
    materials: vector[ClwMaterial]
    chunks: vector[ClwChunk]

fn clw_div_floor(a: int, b: int) -> int:
    let mut q: int = a / b
    let mut r: int = a % b
    if r != 0:
        if a < 0 and b > 0:
            q = q - 1
        elif a > 0 and b < 0:
            q = q - 1
    return q

fn clw_mod_floor(a: int, b: int) -> int:
    let mut r: int = a % b
    if r < 0:
        r = r + b
    return r

fn clw_world_new(name: string, cell_size: float, chunk_size: int, grav_y: float) -> ClwWorld:
    let mats: vector[ClwMaterial] = []
    let chs: vector[ClwChunk] = []
    w := ClwWorld(name, cell_size, chunk_size, 0.0, grav_y, 0.0, mats, chs)
    
    // Add default material 0: Air (non-solid)
    air := ClwMaterial(0, "air", 0, 0.0, 0.0, 0.0)
    w.materials.push(air)
    return w

fn clw_add_material(w: ClwWorld, id: int, name: string, solid: int, friction: float, restitution: float, density: float) -> void:
    mat := ClwMaterial(id, name, solid, friction, restitution, density)
    w.materials.push(mat)

fn clw_get_material(w: ClwWorld, id: int) -> ClwMaterial:
    let mut i: int = 0
    while i < len(w.materials):
        let m: ClwMaterial = w.materials[i]
        if m.id == id:
            return m
        i = i + 1
    let default_air: ClwMaterial = w.materials[0]
    return default_air

fn clw_chunk_new(cx: int, cy: int, cz: int, size: int) -> ClwChunk:
    let blks: vector[int] = []
    total_voxels := size * size * size
    let mut i: int = 0
    while i < total_voxels:
        blks.push(0)
        i = i + 1
    return ClwChunk(cx, cy, cz, size, blks)

fn clw_get_chunk(w: ClwWorld, cx: int, cy: int, cz: int) -> ClwChunk:
    let mut i: int = 0
    while i < len(w.chunks):
        let c: ClwChunk = w.chunks[i]
        if c.cx == cx and c.cy == cy and c.cz == cz:
            return c
        i = i + 1
    let empty_chunk: ClwChunk = ClwChunk(cx, cy, cz, 0, [])
    return empty_chunk

fn clw_has_chunk(w: ClwWorld, cx: int, cy: int, cz: int) -> int:
    let mut i: int = 0
    while i < len(w.chunks):
        let c: ClwChunk = w.chunks[i]
        if c.cx == cx and c.cy == cy and c.cz == cz:
            return 1
        i = i + 1
    return 0

fn clw_get_or_create_chunk(w: ClwWorld, cx: int, cy: int, cz: int) -> ClwChunk:
    let mut i: int = 0
    while i < len(w.chunks):
        let c: ClwChunk = w.chunks[i]
        if c.cx == cx and c.cy == cy and c.cz == cz:
            return c
        i = i + 1
    new_c := clw_chunk_new(cx, cy, cz, w.chunk_size)
    w.chunks.push(new_c)
    return new_c

fn clw_chunk_set_block(chunk: ClwChunk, lx: int, ly: int, lz: int, mat_id: int) -> void:
    if lx < 0 or lx >= chunk.size or ly < 0 or ly >= chunk.size or lz < 0 or lz >= chunk.size:
        return
    idx := lx + (ly * chunk.size) + (lz * chunk.size * chunk.size)
    if idx >= 0 and idx < len(chunk.blocks):
        chunk.blocks[idx] = mat_id

fn clw_chunk_get_block(chunk: ClwChunk, lx: int, ly: int, lz: int) -> int:
    if lx < 0 or lx >= chunk.size or ly < 0 or ly >= chunk.size or lz < 0 or lz >= chunk.size:
        return 0
    idx := lx + (ly * chunk.size) + (lz * chunk.size * chunk.size)
    if idx >= 0 and idx < len(chunk.blocks):
        return chunk.blocks[idx]
    return 0

fn clw_set_block(w: ClwWorld, gx: int, gy: int, gz: int, mat_id: int) -> void:
    cx := clw_div_floor(gx, w.chunk_size)
    cy := clw_div_floor(gy, w.chunk_size)
    cz := clw_div_floor(gz, w.chunk_size)
    lx := clw_mod_floor(gx, w.chunk_size)
    ly := clw_mod_floor(gy, w.chunk_size)
    lz := clw_mod_floor(gz, w.chunk_size)
    c := clw_get_or_create_chunk(w, cx, cy, cz)
    clw_chunk_set_block(c, lx, ly, lz, mat_id)

fn clw_get_block(w: ClwWorld, gx: int, gy: int, gz: int) -> int:
    cx := clw_div_floor(gx, w.chunk_size)
    cy := clw_div_floor(gy, w.chunk_size)
    cz := clw_div_floor(gz, w.chunk_size)
    lx := clw_mod_floor(gx, w.chunk_size)
    ly := clw_mod_floor(gy, w.chunk_size)
    lz := clw_mod_floor(gz, w.chunk_size)
    if clw_has_chunk(w, cx, cy, cz) == 0:
        return 0
    c := clw_get_chunk(w, cx, cy, cz)
    return clw_chunk_get_block(c, lx, ly, lz)

// ------------------------------------------------------------------------------
// 3D Spatial Physics: AABB Box Collision Check
// Returns 1 if the given bounding box intersects any solid block in the world
// ------------------------------------------------------------------------------
fn clw_check_box_collision(w: ClwWorld, min_x: float, min_y: float, min_z: float, max_x: float, max_y: float, max_z: float) -> int:
    bx0 := to_int(min_x / w.cell_size)
    bx1 := to_int(max_x / w.cell_size)
    by0 := to_int(min_y / w.cell_size)
    by1 := to_int(max_y / w.cell_size)
    bz0 := to_int(min_z / w.cell_size)
    bz1 := to_int(max_z / w.cell_size)

    let mut z: int = bz0
    while z <= bz1:
        let mut y: int = by0
        while y <= by1:
            let mut x: int = bx0
            while x <= bx1:
                b := clw_get_block(w, x, y, z)
                if b > 0:
                    mat := clw_get_material(w, b)
                    if mat.solid == 1:
                        return 1
                x = x + 1
            y = y + 1
        z = z + 1
    return 0

// ------------------------------------------------------------------------------
// 3D Spatial Physics: Fast Raycasting (Ray Marching)
// Returns material ID of hit solid block, or 0 if ray hits empty space
// ------------------------------------------------------------------------------
fn clw_raycast(w: ClwWorld, ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, max_dist: float) -> int:
    let step: float = w.cell_size * 0.4
    let mut dist: float = 0.0
    
    while dist <= max_dist:
        rx := ox + (dx * dist)
        ry := oy + (dy * dist)
        rz := oz + (dz * dist)
        
        gx := to_int(rx / w.cell_size)
        gy := to_int(ry / w.cell_size)
        gz := to_int(rz / w.cell_size)
        
        b := clw_get_block(w, gx, gy, gz)
        if b > 0:
            mat := clw_get_material(w, b)
            if mat.solid == 1:
                return b
        dist = dist + step
    return 0

// ------------------------------------------------------------------------------
// Serialization & RLE Compression for .clw
// ------------------------------------------------------------------------------
fn clw_save(filepath: string, w: ClwWorld) -> int:
    let mut out: string = "CLW/1.0\n"
    out = out + "WORLD|" + w.name + "|" + str(w.cell_size) + "|" + str(w.chunk_size) + "|" + str(w.gravity_x) + "|" + str(w.gravity_y) + "|" + str(w.gravity_z) + "\n"
    
    out = out + "MATERIALS\n"
    let mut m_i: int = 0
    while m_i < len(w.materials):
        let m: ClwMaterial = w.materials[m_i]
        out = out + "MAT|" + str(m.id) + "|" + m.name + "|" + str(m.solid) + "|" + str(m.friction) + "|" + str(m.restitution) + "|" + str(m.density) + "\n"
        m_i = m_i + 1
        
    out = out + "CHUNKS\n"
    let mut c_i: int = 0
    while c_i < len(w.chunks):
        let c: ClwChunk = w.chunks[c_i]
        
        // RLE compression on blocks
        let mut rle_str: string = ""
        let total_vox: int = len(c.blocks)
        if total_vox > 0:
            let mut cur_mat: int = c.blocks[0]
            let mut cur_count: int = 1
            let mut b_idx: int = 1
            while b_idx < total_vox:
                val := c.blocks[b_idx]
                if val == cur_mat:
                    cur_count = cur_count + 1
                else:
                    if len(rle_str) > 0:
                        rle_str = rle_str + ","
                    rle_str = rle_str + str(cur_mat) + ":" + str(cur_count)
                    cur_mat = val
                    cur_count = 1
                b_idx = b_idx + 1
            if len(rle_str) > 0:
                rle_str = rle_str + ","
            rle_str = rle_str + str(cur_mat) + ":" + str(cur_count)
            
        out = out + "CHUNK|" + str(c.cx) + "|" + str(c.cy) + "|" + str(c.cz) + "|" + str(c.size) + "|" + rle_str + "\n"
        c_i = c_i + 1
        
    return file_write(filepath, out)

fn clw_load(filepath: string) -> ClwWorld:
    let mats: vector[ClwMaterial] = []
    let chs: vector[ClwChunk] = []
    w := ClwWorld("world", 1.0, 16, 0.0, -9.81, 0.0, mats, chs)
    
    if file_exists(filepath) == 0:
        return w
    raw := file_read(filepath)
    if len(raw) == 0:
        return w
        
    let mut section: string = "HEADER"
    let mut line: string = ""
    let mut i: int = 0
    while i < len(raw):
        ch := char_at(raw, i)
        if ch == "\n":
            if line == "MATERIALS":
                section = "MATERIALS"
            elif line == "CHUNKS":
                section = "CHUNKS"
            elif section == "HEADER":
                if len(line) >= 6 and substring(line, 0, 6) == "WORLD|":
                    sub := substring(line, 6, len(line) - 6)
                    let mut parts: vector[string] = []
                    let mut buf: string = ""
                    let mut j: int = 0
                    while j < len(sub):
                        c := char_at(sub, j)
                        if c == "|":
                            parts.push(buf)
                            buf = ""
                        else:
                            buf = buf + c
                        j = j + 1
                    parts.push(buf)
                    if len(parts) >= 6:
                        w.name = parts[0]
                        w.cell_size = to_float(parts[1])
                        w.chunk_size = to_int(parts[2])
                        w.gravity_x = to_float(parts[3])
                        w.gravity_y = to_float(parts[4])
                        w.gravity_z = to_float(parts[5])
            elif section == "MATERIALS":
                if len(line) >= 4 and substring(line, 0, 4) == "MAT|":
                    sub := substring(line, 4, len(line) - 4)
                    let mut parts: vector[string] = []
                    let mut buf: string = ""
                    let mut j: int = 0
                    while j < len(sub):
                        c := char_at(sub, j)
                        if c == "|":
                            parts.push(buf)
                            buf = ""
                        else:
                            buf = buf + c
                        j = j + 1
                    parts.push(buf)
                    if len(parts) >= 6:
                        m_id := to_int(parts[0])
                        m_name := parts[1]
                        m_solid := to_int(parts[2])
                        m_fric := to_float(parts[3])
                        m_rest := to_float(parts[4])
                        m_dens := to_float(parts[5])
                        clw_add_material(w, m_id, m_name, m_solid, m_fric, m_rest, m_dens)
            elif section == "CHUNKS":
                if len(line) >= 6 and substring(line, 0, 6) == "CHUNK|":
                    sub := substring(line, 6, len(line) - 6)
                    let mut parts: vector[string] = []
                    let mut buf: string = ""
                    let mut j: int = 0
                    while j < len(sub):
                        c := char_at(sub, j)
                        if c == "|":
                            parts.push(buf)
                            buf = ""
                        else:
                            buf = buf + c
                        j = j + 1
                    parts.push(buf)
                    if len(parts) >= 5:
                        cx := to_int(parts[0])
                        cy := to_int(parts[1])
                        cz := to_int(parts[2])
                        c_sz := to_int(parts[3])
                        rle_data := parts[4]
                        
                        let blks: vector[int] = []
                        // Decode RLE runs
                        let mut r_buf: string = ""
                        let mut r_idx: int = 0
                        while r_idx < len(rle_data):
                            rc := char_at(rle_data, r_idx)
                            if rc == ",":
                                // Parse single run mat_id:count
                                colon_pos := -1
                                let mut cp: int = 0
                                while cp < len(r_buf):
                                    if char_at(r_buf, cp) == ":":
                                        colon_pos = cp
                                        break
                                    cp = cp + 1
                                if colon_pos != -1:
                                    r_mat := to_int(substring(r_buf, 0, colon_pos))
                                    r_cnt := to_int(substring(r_buf, colon_pos + 1, len(r_buf) - colon_pos - 1))
                                    let mut k: int = 0
                                    while k < r_cnt:
                                        blks.push(r_mat)
                                        k = k + 1
                                r_buf = ""
                            else:
                                r_buf = r_buf + rc
                            r_idx = r_idx + 1
                        if len(r_buf) > 0:
                            colon_pos := -1
                            let mut cp: int = 0
                            while cp < len(r_buf):
                                if char_at(r_buf, cp) == ":":
                                    colon_pos = cp
                                    break
                                cp = cp + 1
                            if colon_pos != -1:
                                r_mat := to_int(substring(r_buf, 0, colon_pos))
                                r_cnt := to_int(substring(r_buf, colon_pos + 1, len(r_buf) - colon_pos - 1))
                                let mut k: int = 0
                                while k < r_cnt:
                                    blks.push(r_mat)
                                    k = k + 1
                                    
                        chunk := ClwChunk(cx, cy, cz, c_sz, blks)
                        w.chunks.push(chunk)
            line = ""
        else:
            line = line + ch
        i = i + 1
        
    return w
