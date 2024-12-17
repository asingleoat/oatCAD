const std = @import("std");
const stl = @import("stl.zig");

pub fn triangulate(allocator: std.mem.Allocator, r: std.Random.Random, polygon: stl.Polyline) !void {
    const n = polygon.verts.len - 1;
    const edges = try allocator.alloc(Edge, n);
    const treeBuf = try allocator.alloc(TreeNode, n + 1);
    const vertBuf = try allocator.alloc(bool, n + 1);
    for (0..edges.len) |i| {
        edges[i] = .{ .v0 = i, .v1 = (i + 1) };
    }
    std.Random.shuffle(r, Edge, edges);

    var tree = BinaryTree.init(treeBuf, vertBuf);
    // _ = tree;
    try insertEdge(&tree, polygon.verts, edges[0]);
    std.debug.print("{any}\n\n", .{edges});
    std.debug.print("{any}\n\n", .{tree});
    for (1..logstar(polygon.verts.len - 1)) |h| {
        // std.debug.print("l: {any}, r: {any}\n", .{ (N(n, h - 1)), (N(n, h)) });
        for ((N(n, h - 1) + 1)..(N(n, h) + 1)) |i| {
            _ = i;
            // std.debug.print("i: {any}, h: {any}\n", .{ i, h });
        }
    }

    // Seidel's paper uses a real valued log2. If we do the integer log2 instead, then the for-loop in step (4) is always empty and we can skip it.
    // var i: usize = N(n, logstar(n));
    // std.debug.print("i: {any}, n: {any}\n", .{ i, n });
    // while (i < n) {
    // std.debug.print("i: {any}\n", .{i});
    // i += 1;
    // }

    // tree.addNode
}

pub fn insertEdge(tree: *BinaryTree, verts: []stl.V3, e: Edge) !void {
    if (verts[e.v0].lessThan(verts[e.v1])) {
        std.debug.print("{any}\n\n", .{e});
        _ = try tree.*.addNode(NodeKind{ .vertex = e.v1 });
    } else {
        _ = try tree.*.addNode(NodeKind{ .vertex = e.v0 });
    }

    // _ = tree;
    // _ = e;
}

pub fn N(n: usize, h: u64) usize {
    return divCeil(usize, n, iterLog(usize, h, n));
}

pub fn divCeil(comptime T: type, a: T, b: T) T {
    if (b > 0) {
        return (a + (b - 1)) / b;
    } else if (b < 0) {
        return (a + (b + 1)) / b;
    } else {
        @panic("Division by zero");
    }
}

pub fn iterLog(comptime T: type, h: T, n: T) T {
    var r: T = n;
    for (0..@intCast(h)) |i| {
        _ = i;
        r = log2(T, r);
    }
    return @max(1, r);
}

// integer log2, might want to use floating log2?
pub fn log2(comptime T: type, x: T) T {
    return (@sizeOf(T) * 8 - 1) - @clz(x);
}

pub fn logstar(x: u64) u64 {
    if (x > 65536) {
        return 5;
    } else if (x > 16) {
        return 4;
    } else if (x > 4) {
        return 3;
    } else if (x > 2) {
        return 2;
    } else if (x > 1) {
        return 1;
    } else {
        return 0;
    }
}

pub const Trapezoid = struct {
    left: ?Edge,
    right: ?Edge,
    above0: ?usize,
    above1: ?usize,
    below0: ?usize,
    below1: ?usize,
};

pub const Edge = struct {
    v0: usize,
    v1: usize,
};

pub const NodeKind = union(enum) {
    edge: Edge,
    vertex: usize,
};

pub const TreeNode = struct {
    kind: NodeKind,
    leftChild: ?usize, // left/lower
    rightChild: ?usize, // right/upper
};

pub const BinaryTree = struct {
    nodes: []TreeNode,
    nextIndex: usize, // Next available index in the array
    contains: []bool,

    pub fn init(buffer: []TreeNode, containsBuf: []bool) BinaryTree {
        return BinaryTree{ .nodes = buffer, .nextIndex = 0, .contains = containsBuf };
    }

    pub fn addNode(
        self: *BinaryTree,
        nodeKind: NodeKind,
    ) !usize {
        if (self.nextIndex >= self.nodes.len) return error.OutOfSpace;
        switch (nodeKind) {
            .vertex => |i| self.contains[i] = true,
            .edge => {},
        }

        // TODO: locate parents and update their children indexes

        self.nodes[self.nextIndex] = TreeNode{
            .kind = nodeKind,
            .leftChild = null,
            .rightChild = null,
        };
        const currentIndex = self.nextIndex;
        self.nextIndex += 1;
        return currentIndex;
    }

    pub fn setChildren(self: *BinaryTree, parentIndex: usize, left: ?usize, right: ?usize) void {
        self.nodes[parentIndex].leftChild = left;
        self.nodes[parentIndex].rightChild = right;
    }

    // pub fn traverseInOrder(
    //     self: *BinaryTree,
    //     nodeIndex: usize,
    //     visit: fn (*TreeNode) void,
    // ) void {
    //     const node = &self.nodes[nodeIndex];
    //     if (node.leftChild) |left| self.traverseInOrder(left, visit);

    //     visit(node);

    //     if (node.rightChild) |right| self.traverseInOrder(right, visit);
    // }
};
