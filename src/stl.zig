const std = @import("std");
const math = std.math;

pub fn Vec3(comptime T: type) type {
    return packed struct {
        x: T,
        y: T,
        z: T,
        pub fn add(self: @This(), other: @This()) @This() {
            return @This(){
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }
        pub fn quadrance(self: @This(), other: @This()) T {
            return ((self.x - other.x) * (self.x - other.x) + (self.y - other.y) * (self.y - other.y) + (self.z - other.z) * (self.z - other.z));
        }
        pub fn distance(self: @This(), other: @This()) T {
            return @sqrt((self.x - other.x) * (self.x - other.x) + (self.y - other.y) * (self.y - other.y) + (self.z - other.z) * (self.z - other.z));
        }
        pub fn interpolate(self: @This(), other: @This(), coeff: T) @This() {
            return @This(){
                .x = coeff * self.x + (1 - coeff) * other.x,
                .y = coeff * self.y + (1 - coeff) * other.y,
                .z = coeff * self.z + (1 - coeff) * other.z,
            };
        }
    };
}

pub const V3 = Vec3(f32);
pub const IntV3 = Vec3(u32);

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

pub const va: V3 = V3{ .x = @sqrt(8.0) / 3.0, .y = 0.0, .z = -1.0 / 3.0 };
pub const vb: V3 = V3{ .x = @sqrt(2.0) / -3.0, .y = @sqrt(2.0 / 3.0), .z = -1.0 / 3.0 };
pub const vc: V3 = V3{ .x = @sqrt(2.0) / -3.0, .y = -@sqrt(2.0 / 3.0), .z = -1.0 / 3.0 };
pub const vd: V3 = V3{ .x = 0.0, .y = 0.0, .z = 1.0 };

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

// TODO: shouldn't need dynamic arrays
// n.b.: closed polylines have duplicate first-last vertices,
// so .verts.len == segments + 1
pub fn circle(allocator: std.mem.Allocator, radius: f32, segments: u32) !Polyline {
    var vertexList = std.ArrayList(V3).init(allocator);
    defer vertexList.deinit();

    var vertex: V3 = V3{ .x = 0, .y = 0, .z = 0 };
    const fsegments: f32 = @floatFromInt(segments);
    const angle_step: f32 = (2 * math.pi) / fsegments;
    var angle: f32 = 0;
    while (angle < 2 * math.pi) {
        vertex.x = radius * @cos(angle);
        vertex.y = radius * @sin(angle);
        try vertexList.append(vertex);
        angle += angle_step;
    }
    // close the polyline
    vertex.x = radius * @cos(0.0);
    vertex.y = radius * @sin(0.0);
    try vertexList.append(vertex);

    return .{
        .verts = try vertexList.toOwnedSlice(),
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

// bug when parts = p.verts.len - 1?
pub fn resample(allocator: std.mem.Allocator, p: Polyline, parts: u32) !Polyline {
    if (p.verts.len == parts) {
        return p;
    } else {
        // allocate one extra for the closing part,
        // maybe should make that caller responsibility?
        const resampledVerts = try allocator.alloc(V3, parts + 1);
        const portion: f32 = @floatFromInt(parts + 1);
        const step: f32 = length(p) / portion;
        var target: f32 = 0;
        var dist: f32 = 0;
        var j: usize = 0;
        for (0..parts) |i| {
            target += step;
            while (target > dist) {
                j += 1;
                j = @min(j, p.verts.len - 1);
                dist += p.verts[j].distance(p.verts[j - 1]);
                // TODO: ugly patch for float issues
            }
            // const c = (dist - target) / p.verts[j].distance(p.verts[j - 1]);
            // resampledVerts[i] = p.verts[j - 1].interpolate(p.verts[j], c);
            // exact match
            // if (target == dist) {
            // resampledVerts[i] = p.verts[j];
            // j += 1;
            // } else
            if (target <= dist) {
                // std.debug.print("tgt: {any}, dist: {any}, i: {any}\n", .{ target, dist, i }
                const c = (dist - target) / p.verts[j].distance(p.verts[j - 1]);
                resampledVerts[i] = p.verts[j - 1].interpolate(p.verts[j], c);
            }
        }
        resampledVerts[0] = p.verts[0];
        resampledVerts[parts] = p.verts[0];
        return .{ .verts = resampledVerts };
    }
}

// geometric length
pub fn length(p: Polyline) f32 {
    var total: f32 = 0;
    for (0..p.verts.len - 1) |i| {
        total += p.verts[i].distance(p.verts[i + 1]);
    }
    return total;
}

pub const Polyline = struct {
    verts: []V3,
    pub fn move(self: Polyline, vec: V3) void {
        for (self.verts) |*vert| {
            vert.* = vert.*.add(vec);
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
            try std.fmt.format(writer, "{d},{d},{d}", .{ vert.x, vert.y, vert.z });
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
