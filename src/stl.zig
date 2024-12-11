const std = @import("std");

pub fn Vec3(comptime T: type) type {
    return packed struct { x: T, y: T, z: T };
}

pub const V3 = Vec3(f32);
pub const IntV3 = Vec3(u32);

// pub const V3 = packed struct {
//     x: f32,
//     y: f32,
//     z: f32,
// };

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

pub const IndexArray = struct {
    verts: []V3,
    idxs: []u32,
};

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

pub fn readStl(dir: std.fs.Dir, allocator: *std.mem.Allocator, sub_path: []const u8) !Stl {
    var file = try dir.openFile(sub_path, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var stream = buffered.reader();

    var header: [80]u8 = undefined;
    header = try stream.readBytesNoEof(80);
    var count: u32 = undefined;
    count = try stream.readIntLittle(u32);

    var tris = TriList{};
    try tris.ensureTotalCapacity(allocator, count);

    var tri: Tri = undefined;

    for (0..count) |_| {
        const bytes = try stream.readBytesNoEof(@divExact(@bitSizeOf(Tri), 8));
        @memcpy(std.mem.asBytes(&tri), &bytes);
        tris.appendAssumeCapacity(tri);
    }

    const stl = Stl{
        .header = header,
        .count = count,
        .tris = tris,
    };

    return stl;
}
