const std = @import("std");
const math = std.math;

pub const V3 = @Vector(3, f32);
pub const IntV3 = @Vector(3, u32);

// lexicographic strict less than
pub fn lt(v: V3, w: V3) bool {
    if (v[0] < w[0]) {
        return true;
    } else if (v[0] > w[0]) {
        return false;
    } else if (v[1] < w[1]) {
        return true;
    } else if (v[1] > w[1]) {
        return false;
    } else if (v[2] < w[2]) {
        return true;
    } else return false;
    // else if (v[2] > w[2]) {
    // return false;
    // }
}

pub fn distance(v: V3, w: V3) f32 {
    return @sqrt((v[0] - w[0]) * (v[0] - w[0]) + (v[1] - w[1]) * (v[1] - w[1]) + (v[2] - w[2]) * (v[2] - w[2]));
}

pub fn quadrance(v: V3, w: V3) f32 {
    return ((v[0] - w[0]) * (v[0] - w[0]) + (v[1] - w[1]) * (v[1] - w[1]) + (v[2] - w[2]) * (v[2] - w[2]));
}

pub fn interpolate(v: V3, w: V3, coeff: f32) V3 {
    return V3{
        coeff * v[0] + (1 - coeff) * w[0],
        coeff * v[1] + (1 - coeff) * w[1],
        coeff * v[2] + (1 - coeff) * w[2],
    };
}
pub const Tri = packed struct {
    n: V3,
    a: V3,
    b: V3,
    c: V3,
    attrib: u16,
};

pub const TriSimple = packed struct {
    a: V3,
    b: V3,
    c: V3,
};

pub const va: V3 = V3{ @sqrt(8.0) / 3.0, 0.0, -1.0 / 3.0 };
pub const vb: V3 = V3{ @sqrt(2.0) / -3.0, @sqrt(2.0 / 3.0), -1.0 / 3.0 };
pub const vc: V3 = V3{ @sqrt(2.0) / -3.0, -@sqrt(2.0 / 3.0), -1.0 / 3.0 };
pub const vd: V3 = V3{ 0.0, 0.0, 1.0 };

pub const unitTet = [_]f32{
    @sqrt(8.0) / 3.0,  0.0,               -1.0 / 3.0,
    @sqrt(2.0) / -3.0, @sqrt(2.0 / 3.0),  -1.0 / 3.0,
    @sqrt(2.0) / -3.0, -@sqrt(2.0 / 3.0), -1.0 / 3.0,
    0,                 0,                 1,
};
pub const unitTetSlice: []const f32 = &unitTet;

pub const TriList = std.MultiArrayList(Tri);

pub const Stl = struct {
    header: [80]u8,
    count: u32,
    tris: TriList,
};

pub fn triListToSimpleArray(allocator: std.mem.Allocator, triList: TriList) ![]const TriSimple {
    var simpleArray = std.ArrayList(TriSimple).init(allocator);
    defer simpleArray.deinit();

    for (triList.items(.a), triList.items(.b), triList.items(.c)) |a, b, c| {
        var simpleTri: TriSimple = undefined;

        simpleTri.a = b;
        simpleTri.b = a;
        simpleTri.c = c;

        try simpleArray.append(simpleTri);
    }
    return simpleArray.toOwnedSlice();
}

pub fn concat(allocator: *std.mem.Allocator, a: Stl, b: Stl) !Stl {
    var tris = TriList{};
    try tris.ensureTotalCapacity(allocator, a.count + b.count);
    for (0..a.count) |idx| {
        tris.appendAssumeCapacity(a.tris.get(idx));
    }
    for (0..b.count) |idx| {
        tris.appendAssumeCapacity(b.tris.get(idx));
    }

    const joined_stl = Stl{
        .header = a.header,
        .count = a.count + b.count,
        .tris = tris,
    };
    return joined_stl;
}

// n.b.: closed polylines have duplicate first-last vertices,
// so .verts.len == segments + 1
pub fn circle(allocator: *std.mem.Allocator, radius: f32, segments: u32) !Polyline {
    var vertex_list = try allocator.*.alloc(V3, segments + 1);

    const fsegments: f32 = @floatFromInt(segments);
    const angle_step: f32 = (2 * math.pi) / fsegments;
    var angle: f32 = undefined;
    for (vertex_list, 0..) |*vertex, i| {
        const fi: f32 = @floatFromInt(i);
        angle = angle_step * fi;
        vertex.*[0] = radius * @cos(angle);
        vertex.*[1] = radius * @sin(angle);
    }
    // close the polyline, redundant were it not for floating point imprecision
    vertex_list[segments][0] = radius * @cos(0.0);
    vertex_list[segments][1] = radius * @sin(0.0);

    return .{
        .verts = vertex_list,
    };
}

// TODO: could convert to indexed array form directly, need to bench
pub fn loft(allocator: std.mem.Allocator, base: Polyline, target: Polyline) !IndexArray {
    var triList = std.ArrayList(TriSimple).init(allocator);
    defer triList.deinit();

    var tri: TriSimple = undefined;
    for (0..base.verts.len - 1) |i| {
        tri.a = base.verts[i];
        tri.b = target.verts[i];
        tri.c = target.verts[i + 1];

        try triList.append(tri);

        tri.a = base.verts[i];
        tri.b = target.verts[i + 1];
        tri.c = base.verts[i + 1];

        try triList.append(tri);
    }
    const triSlice = try triList.toOwnedSlice();
    return convertToIndexedArray(allocator, triSlice);
}

pub fn resample(allocator: *std.mem.Allocator, p: Polyline, segments: u32) !Polyline {
    // closed polyline has one more vertex than it has line segments
    if (p.verts.len == segments + 1) {
        return p;
    } else {
        // allocate one extra for the closing part,
        // maybe should make that caller responsibility?
        const resampledVerts = try allocator.*.alloc(V3, segments + 1);
        const portion: f32 = @floatFromInt(segments);
        const step: f32 = length(p) / portion;
        var target: f32 = 0;
        var dist: f32 = 0;
        var j: usize = 0;
        for (1..resampledVerts.len) |i| {
            // std.debug.print("target: {any}, dist: {any}\n", .{ target, dist });
            target += step;
            while (target > dist) {
                j += 1;
                j = @min(j, p.verts.len - 1);
                dist += distance(p.verts[j], p.verts[j - 1]);
            }
            const c = (dist - target) / distance(p.verts[j], p.verts[j - 1]);
            resampledVerts[i] = interpolate(p.verts[j], p.verts[j - 1], (1 - c));
        }
        resampledVerts[0] = p.verts[0];
        resampledVerts[segments] = p.verts[0];
        return .{ .verts = resampledVerts };
    }
}

// geometric length, as opposed to vertex count
pub fn length(p: Polyline) f32 {
    var total: f32 = 0;
    for (0..p.verts.len - 1) |i| {
        total += distance(p.verts[i], p.verts[i + 1]);
    }
    return total;
}

// TODO: serialization types should live in a different module
pub const PolylineList = struct {
    lines: std.ArrayList(Polyline),
    pub fn init(allocator: *std.mem.Allocator) PolylineList {
        const lines = std.ArrayList(Polyline).init(allocator.*);
        return PolylineList{ .lines = lines };
    }
    pub fn toJson(self: PolylineList, allocator: *std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator.*);
        defer list.deinit();
        var writer = list.writer();

        _ = try writer.write("{ \"modelType\": \"line\", \"lines\": [");
        // Write vertices
        for (self.lines.items, 0..) |line, j| {
            if (j != 0) try writer.writeByte(',');
            _ = try writer.write("[");
            for (line.verts, 0..) |vert, i| {
                if (i != 0) try writer.writeByte(',');
                try std.fmt.format(writer, "{d},{d},{d}", .{ vert[0], vert[1], vert[2] });
            }
            _ = try writer.write("]");
        }
        _ = try writer.write("]}");

        const jsonPayload = list.toOwnedSlice();
        return jsonPayload;
    }
};

pub const Polyline = struct {
    verts: []V3,

    pub fn init(allocator: *std.mem.Allocator, numVertices: u32) !Polyline {
        const verts = try allocator.alloc(V3, numVertices);
        return Polyline{
            .verts = verts,
        };
    }

    pub fn move(self: Polyline, vec: V3) void {
        for (self.verts) |*vert| {
            vert.* = vert.* + vec;
        }
    }

    pub fn toJson(self: Polyline, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit();
        var writer = list.writer();

        _ = try writer.write("{ \"modelType\": \"line\", \"vertices\": [");

        // Write vertices
        for (self.verts, 0..) |vert, i| {
            if (i != 0) try writer.writeByte(',');
            try std.fmt.format(writer, "{d},{d},{d}", .{ vert.x, vert.y, vert.z });
        }
        _ = try writer.write("] }");

        const jsonPayload = list.toOwnedSlice();
        return jsonPayload;
    }
    pub fn len(self: Polyline) usize {
        return self.verts.len;
    }
};

pub const IndexArray = struct {
    verts: []V3,
    idxs: []u32,

    pub fn toJson(self: IndexArray, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit();
        var writer = list.writer();

        // Start JSON object
        _ = try writer.write("{ \"modelType\": \"mesh\", \"vertices\": [");

        // Write vertices
        for (self.verts, 0..) |vert, i| {
            if (i != 0) try writer.writeByte(',');
            try std.fmt.format(writer, "{d},{d},{d}", .{ vert[0], vert[1], vert[2] });
        }
        _ = try writer.write("], \"indices\": [");

        // Write indices
        for (self.idxs, 0..) |idx, i| {
            if (i != 0) try writer.writeByte(',');
            try std.fmt.format(writer, "{d}", .{idx});
        }
        _ = try writer.write("] }");

        const jsonPayload = list.toOwnedSlice();
        return jsonPayload;
    }
};

// TODO: shouldn't need dynamic arrays
pub fn convertToIndexedArray(allocator: std.mem.Allocator, triangles: []const TriSimple) !IndexArray {
    var vertexMap = std.AutoHashMap(IntV3, u32).init(allocator);
    defer vertexMap.deinit();

    var vertexList = std.ArrayList(V3).init(allocator);
    defer vertexList.deinit();

    var indexList = std.ArrayList(u32).init(allocator);
    defer indexList.deinit();

    for (triangles) |triangle| {
        try addVertex(triangle.a, &vertexMap, &vertexList, &indexList);
        try addVertex(triangle.b, &vertexMap, &vertexList, &indexList);
        try addVertex(triangle.c, &vertexMap, &vertexList, &indexList);
    }

    return .{
        .verts = try vertexList.toOwnedSlice(),
        .idxs = try indexList.toOwnedSlice(),
    };
}

fn addVertex(vertex: V3, vertexMap: *std.AutoHashMap(IntV3, u32), vertexList: *std.ArrayList(V3), indexList: *std.ArrayList(u32)) !void {
    if (!vertexMap.contains(@bitCast(vertex))) {
        const index = vertexList.items.len;
        try vertexList.append(vertex);
        try vertexMap.put(@bitCast(vertex), @intCast(index));
        try indexList.append(@intCast(index));
    } else {
        const existingIndex = vertexMap.get(@bitCast(vertex)).?;
        try indexList.append(existingIndex);
    }
}

pub fn readStl(dir: std.fs.Dir, allocator: std.mem.Allocator, sub_path: []const u8) !Stl {
    var file = try dir.openFile(sub_path, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var stream = buffered.reader();

    var header: [80]u8 = undefined;
    header = try stream.readBytesNoEof(80);
    var count: u32 = undefined;
    count = try stream.readInt(u32, std.builtin.Endian.little);

    var tris = TriList{};
    try tris.ensureTotalCapacity(allocator, count);

    var tri: Tri = undefined;

    for (0..count) |_| {
        const bytes = try stream.readBytesNoEof(50); // @divExact(@bitSizeOf(Tri), 8));
        @memcpy(std.mem.asBytes(&tri)[0..50], &bytes);
        tris.appendAssumeCapacity(tri);
    }

    const stl = Stl{
        .header = header,
        .count = count,
        .tris = tris,
    };

    return stl;
}
