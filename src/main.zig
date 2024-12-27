const std = @import("std");
const testing = std.testing;
const websocket = @import("websocket");
const Server = websocket.Server;
const model = @import("model.zig");
const ws = @import("websocket.zig");
const stl = @import("stl.zig");
const tree = @import("binary_tree.zig");
const seidel = @import("seidel.zig");

pub fn loftPayload(allocator: std.mem.Allocator) ![]u8 {
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

    const start_time = std.time.nanoTimestamp();
    const samples: u32 = 6;
    const polyline = try stl.circle(allocator, 1, samples);
    polyline.move(stl.V3{ .x = 0, .y = 0, .z = 0.0 });
    const resampledPolyline = try stl.resample(allocator, polyline, samples - 1);

    const end_time = std.time.nanoTimestamp();
    const elapsed_time = end_time - start_time;
    std.debug.print("Elapsed time: {d}ns\n", .{@divTrunc(elapsed_time, samples)});

    // const polylineBase = try stl.circle(allocator, 1, 4);
    // const resampledBase = try stl.resample(allocator, polylineBase, samples - 1);

    // std.debug.print("{any}\n", .{polyline.verts.len});
    // std.debug.print("{any}\n", .{resampledPolyline.verts.len});
    // std.debug.print("{d}\n", .{polylineBase.verts.len});
    // std.debug.print("{d}\n", .{resampledBase.verts.len});

    // std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    // std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    // std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    // std.debug.print("length: {d}\n", .{stl.length(polyline)});

    // const indexArray = try stl.loft(allocator, resampledBase, resampledPolyline);
    // const jsonPayload = try resampledPolyline.toJson(allocator);
    var line_list = try allocator.alloc(stl.Polyline, 1);
    line_list[0] = resampledPolyline;
    // line_list[1] = polylineBase;
    const lines = stl.PolylineList{ .lines = line_list };
    const jsonPayload = try lines.toJson(allocator);
    // const jsonPayload = try resampledBase.toJson(allocator);
    // const jsonPayload = try indexArray.toJson(allocator);
    return jsonPayload;
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    std.debug.print("{s}\n", .{seidel.forced_dependency});
    const t: u32 = @shlExact(1, 31);
    std.debug.print("{b}\n", .{t});
    // var prng = std.rand.DefaultPrng.init(blk: {
    //     var seed: u64 = undefined;
    //     try std.posix.getrandom(std.mem.asBytes(&seed));
    //     break :blk seed;
    // });
    // const rand = prng.random();

    // try tree.triangulate(allocator, rand, polyline);

    const jsonPayload = try loftPayload(allocator);
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
