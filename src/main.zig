const std = @import("std");
const testing = std.testing;
const websocket = @import("websocket");
const Server = websocket.Server;
const model = @import("model.zig");
const ws = @import("websocket.zig");
const stl = @import("stl.zig");
const tree = @import("binary_tree.zig");
const seidel = @cImport({
    @cInclude("triangulate.h");
    @cInclude("misc.c");
    @cInclude("monotone.c");
    @cInclude("construct.c");
    @cInclude("interface.h");
    @cInclude("tri.c");
});
pub fn main() !void {
    // const stdout = std.io.getStdOut().writer();
    // Reflect over all fields in the imported namespace
    const meta = @typeInfo(@TypeOf(seidel));
    std.debug.print("run:\n", .{});
    // if (meta != .Struct) return; // Ensure it's a struct-like namespace
    std.debug.print("p: {any}\n", .{meta});
    const result = seidel.math_N(21000, 1); // Replace 10 with the desired input
    std.debug.print("Result from math_logstar_n: {}\n", .{result});

    const filename: []const u8 = "./src/nih/data_1"; // Null-terminated C string
    // _ = filename;
    var genus: c_uint = 0; // Initialize genus to 1
    // _ = genus;

    const allocator = std.heap.page_allocator;
    const seg = try allocator.alloc(seidel.segment_t, 1024);
    const qs = try allocator.alloc(seidel.node_t, 1024 * 2);
    const tr = try allocator.alloc(seidel.trap_t, 1024 * 4);
    defer allocator.free(seg); // Free memory when done
    const tris = seidel.read_segments(@constCast(@ptrCast(filename)), &genus, &seg[0]);
    std.debug.print("Tris: {}\n", .{tris});
    std.debug.print("Segments: {any}\n", .{seg[0]});
    std.debug.print("Genus: {any}\n", .{genus});
    _ = seidel.initialise(13, &seg[0]);
    std.debug.print("Segments: {any}\n", .{tr[0]});
    _ = seidel.construct_trapezoids(13, &seg[0], &qs[0], &tr[0]);
    std.debug.print("Segments: {any}\n", .{tr[0]});
    const nmonpoly = seidel.monotonate_trapezoids(13, &seg[0], &tr[0]);
    std.debug.print("nmonpolys: {any}\n", .{nmonpoly});
    std.debug.print("Segments: {any}\n", .{tr[0]});
    // const ntriangles = seidel.triangulate_monotone_polygons(13, nmonpoly, &tr[0]);
    // const counts: [4]u32 = .{ 4, 3, 3, 3 };
    // _ = counts;
    // const status = seidel.triangulate_polygon(4, &counts[0], &seg[0]);
    // std.debug.print("status: {any}\n", .{status});
    // const i = seidel.read_segments(
    // const fields = meta.Struct.fields;
    // for (fields) |field| {
    //     stdout.print("Field: {}\n", .{field.name});
    // }
}

pub fn main2() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    // hardcoded tetrahedron test
    // const indexArray = try stl.convertToIndexedArray(allocator, &model.unitTetTries);
    // const jsonPayload = try indexArray.toJson(allocator);
    // defer allocator.free(jsonPayload);

    // const stl_model = try stl.readStl(std.fs.cwd(), allocator, "Bunny.stl"); // hardcoded path to untracked STL because this is development
    // const stl_tris = try stl.triListToSimpleArray(allocator, stl_model.tris);
    // const indexArray = try stl.convertToIndexedArray(allocator, stl_tris);
    // std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    // std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    // std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    // const jsonPayload = try indexArray.toJson(allocator);

    const polyline = try stl.circle(allocator, 2, 10);
    polyline.move(stl.V3{ .x = 0, .y = 0, .z = 2.0 });
    const samples: u32 = 103;
    const polylineBase = try stl.circle(allocator, 1, samples - 3);
    const resampledPolyline = try stl.resample(allocator, polyline, samples - 1);
    const resampledBase = try stl.resample(allocator, polylineBase, samples - 1);

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    try tree.triangulate(allocator, rand, polyline);
    // std.debug.print("{any}\n", .{polyline.verts.len});
    // std.debug.print("{any}\n", .{resampledPolyline.verts.len});
    // std.debug.print("{d}\n", .{polylineBase.verts.len});
    // std.debug.print("{d}\n", .{resampledBase.verts.len});

    // std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    // std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    // std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    // std.debug.print("length: {d}\n", .{stl.length(polyline)});

    const indexArray = try stl.loft(allocator, resampledBase, resampledPolyline);
    // const jsonPayload = try resampledPolyline.toJson(allocator);
    // const jsonPayload = try resampledBase.toJson(allocator);
    const jsonPayload = try indexArray.toJson(allocator);
    defer allocator.free(jsonPayload);

    var context = ws.Context{
        .payload = jsonPayload,
    };

    const config = .{
        // .handshake_timeout_ms = null,
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    };

    var server = try Server.init(allocator, config);
    defer server.deinit(allocator);

    try websocket.listen(ws.Handler, allocator, &context, .{
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    });
}

test "main memory-leaks" {
    const allocator = testing.allocator;

    var stl_model = try stl.readStl(std.fs.cwd(), allocator, "Bunny.stl"); // hardcoded path to untracked STL because this is development
    defer stl_model.tris.deinit(allocator);

    const stl_tris = try stl.triListToSimpleArray(allocator, stl_model.tris);
    defer allocator.free(stl_tris);

    const indexArray = try stl.convertToIndexedArray(allocator, stl_tris);
    // TODO write a nicer deinit
    defer allocator.free(indexArray.verts);
    defer allocator.free(indexArray.idxs);

    std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    const jsonPayload = try indexArray.toJson(allocator);

    std.debug.print("{d}\n", .{jsonPayload.len});
    defer allocator.free(jsonPayload);
}
