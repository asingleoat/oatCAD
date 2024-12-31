// O(n log* n) simple polygon triangulation based on:
// A simple and fast incremental randomized algorithm for computing trapezoidal decompositions and for triangulating polygons
// by Raimund Seidel
// https://doi.org/10.1016/0925-7721(91)90012-4

// note for readers: the implementation implicitly regards vertex[0] as the y-component and
// vertex[1] as the x-component when using the terminology from the paper. This is just so that
// stl.lt (less than) can be the expected lexicographic definition. users of this module don't have
// to care about this, in effect we apply seidel's algorithm from left to right instead of top to
// bottom, but either way we get a triangulation out the end.

// we work exclusively with V3s, but ignore the z-component. if you want to triangulate a
// generalized polygon in 3d space, first rotate it such that it has a sufficiently nice projection
// onto the xy-plane, triangulate, then rotate back

const std = @import("std");
const stl = @import("stl.zig");
const math = std.math;

pub const forced_dependency = "from seidel";

pub const Edge = struct {
    source: u32,
    sink: u32,
};

pub fn renderHorz(allocator: *std.mem.Allocator, vert: stl.V3) !stl.Polyline {
    var line = try stl.Polyline.init(allocator, 2);
    // set "y-component" (actually x, but in this model treated as y) and z to match source
    line.verts[0][0] = vert[0];
    line.verts[1][0] = vert[0];
    line.verts[0][2] = vert[2];
    line.verts[1][2] = vert[2];
    // spiritually -inf and inf
    line.verts[0][1] = -1000;
    line.verts[1][1] = 1000;
    return line;
}

pub fn renderSegment(allocator: *std.mem.Allocator, v: stl.V3, u: stl.V3) !stl.Polyline {
    var line = try stl.Polyline.init(allocator, 2);
    // set "y-component" (actually x, but in this model treated as y) and z to match source
    line.verts[0] = v;
    line.verts[1] = u;
    return line;
}

pub fn renderTrapezoid(allocator: *std.mem.Allocator, p: *stl.PolylineList, t: *TrapezoidStructure, i: u32) !void {
    const ti = t.trapezoids[i];
    std.debug.print("\n\ntrap: {any}\n\n", .{t.trapezoids[0]});
    if (validIndex(ti.v_upper)) {
        std.debug.print("\n\n vertex: {any}\n\n", .{t.vertices.*[ti.v_upper]});
        try p.lines.append(try renderHorz(allocator, t.vertices.*[ti.v_upper]));
    }
    if (validIndex(ti.v_lower)) {
        try p.lines.append(try renderHorz(allocator, t.vertices.*[ti.v_lower]));
    }
    if (validIndex(ti.e_left.source)) {
        try p.lines.append(try renderSegment(allocator, t.vertices.*[ti.e_left.source], t.vertices.*[ti.e_left.sink]));
    }
    if (validIndex(ti.e_right.source)) {
        try p.lines.append(try renderSegment(allocator, t.vertices.*[ti.e_right.source], t.vertices.*[ti.e_right.sink]));
    }
}

pub inline fn leadingBitSetP(value: u32) bool {
    // slightly faster than the alternatives
    // https://uops.info/html-instr/LZCNT_R32_M32.html
    // https://uops.info/html-instr/LZCNT_R32_R32.html
    return @clz(value) == 0;
}

const leadingBit: u32 = @shlExact(1, 31);
const invalid: u32 = 0xFFFFFFFF;
pub inline fn validIndex(value: u32) bool {
    return value != invalid;
}

pub fn segmentCrossing(vUpper: stl.V3, vLower: stl.V3, vHorizontal: stl.V3) f32 {
    if ((vUpper[0] - vHorizontal[0]) * (vLower[0] - vHorizontal[0]) > 0) {
        // the segment strictly crosses (not merely contacts) the horizontal line
        // return horizontal component of crossing
        return vUpper[1] + (vLower[1] - vUpper[1]) * (vHorizontal[0] - vLower[0]) / (vUpper[0] - vLower[0]);
    }
    // if no crossing then, can check with std.math.isNan
    return std.math.nan(f32);
}

pub fn isLeftOf(v0: stl.V3, v1: stl.V3, vq: stl.V3) bool {
    // compute the cross product determinant:
    const cross = (v1[0] - v0[0]) * (vq[1] - v0[1]) - (v1[1] - v0[1]) * (vq[0] - v0[0]);
    // if cross >= 0, point p is to the left of line segment.
    return cross >= 0;
}

// some fields are spiritually nullable, but to pack tighter we do it manually with `invalid`,
// rather than using ?u32. this technically restricts the size of triangulations we can compute to
// 2^32-2 instead of 2^32-1
pub const Trapezoid = struct {
    // nullable, index of vertex implicitly representing {top,bottom} side
    v_upper: u32,
    v_lower: u32,
    // nullable, concrete side or side at infinity
    e_left: Edge,
    e_right: Edge,
    // nullable, neighbor trapezoids
    n_upper_left: u32,
    n_upper_right: u32,
    n_lower_left: u32,
    n_lower_right: u32,
    // index into search tree
    node: u32,
    // inside: bool,
};

pub const TrapezoidStructure = struct {
    trapezoids: []Trapezoid,
    nextIndex: u32,
    // each vertex is inserted twice, once for each edge it is a member of
    // we track which vertices have been inserted and no-op on the second insert
    included: []bool,
    vertices: *[]stl.V3,
    // we need constant time lookup from vertices to their corresponding subtree in the query structure
    // y_nodes[vertex_index] is the query structure index of the y node.
    y_nodes: []u32,
    searchTree: SearchTree,

    pub fn init(allocator: *std.mem.Allocator, vertices: *[]stl.V3, numVertices: u32) !TrapezoidStructure {
        const trapezoids = try allocator.alloc(Trapezoid, numVertices * 3 + 1);

        // unitialized, we take care to only lookup a y-node if the vertex has already been inserted
        // either checking if included[vert] is true, or if the vertex was explicitly inserted eariler in the same block
        const y_nodes = try allocator.alloc(u32, numVertices);

        // number of vertices (Y nodes) + number of edges (X nodes) + number of trapezoids (implicit leaves, 0) + root
        const searchTree = try SearchTree.init(allocator, numVertices * 2 + 1);
        const included = try allocator.alloc(bool, numVertices);
        for (included) |*v| {
            v.* = false;
        }

        var r = TrapezoidStructure{
            .trapezoids = trapezoids,
            .nextIndex = 0,
            .included = included,
            .vertices = vertices,
            .y_nodes = y_nodes,
            .searchTree = searchTree,
        };

        const base_trapezoid = Trapezoid{
            .v_upper = invalid,
            .v_lower = invalid,
            // nullable, concrete side or side at infinity
            .e_left = Edge{ .source = invalid, .sink = invalid },
            .e_right = Edge{ .source = invalid, .sink = invalid },
            // nullable, neighbor trapezoids
            .n_upper_left = invalid,
            .n_upper_right = invalid,
            .n_lower_left = invalid,
            .n_lower_right = invalid,
            // index into search tree
            .node = 0,
            // inside: bool,
        };
        r.insert_trapezoid(base_trapezoid);
        return r;
    }

    pub fn deinit(self: *TrapezoidStructure, allocator: *std.mem.Allocator) void {
        allocator.free(self.trapezoids);
        self.searchTree.deinit;
    }
    pub fn insert_trapezoid(self: *TrapezoidStructure, trapezoid: Trapezoid) void {
        self.trapezoids[self.nextIndex] = trapezoid;
        self.nextIndex += 1;
    }
    pub fn insert_vertex(self: *TrapezoidStructure, v: u32) void {
        if (self.included[v]) {} else {
            self.included[v] = true;
            const root = 0;
            // index of located containing trapezoid
            const t = self.searchTree.lookup(root, v, self.vertices);
            const located = self.trapezoids[t];
            std.debug.print("{any}\n", .{t});

            // update trapezoid structure
            const upper_trapezoid = Trapezoid{
                .v_upper = located.v_upper,
                // inserted vertex becomes lower bound of upper split trap
                .v_lower = v,
                // sides are unchanged after split
                .e_left = located.e_left,
                .e_right = located.e_right,
                .n_upper_left = located.n_upper_left,
                .n_upper_right = located.n_upper_right,
                // new upper trap has only one lower neighbor, the new lower trap which is about to be inserted
                .n_lower_left = self.nextIndex,
                .n_lower_right = invalid,
                // each new trap gets a new search tree node
                .node = self.searchTree.nextIndex,
                // inside: bool,
            };
            // we'll replace the old trapezoid with this one TODO
            self.trapezoids[t] = upper_trapezoid;
            const lower_trapezoid = Trapezoid{
                // inserted vertex becomes upper bound of lower split trap
                .v_upper = v,
                .v_lower = located.v_lower,
                .e_left = located.e_left,
                .e_right = located.e_right,
                // new lower trap has only one upper neighbor, the new upper trap
                .n_upper_left = t + 1,
                .n_upper_right = invalid,
                .n_lower_left = located.n_lower_left,
                .n_lower_right = located.n_lower_right,
                // we'll insert this one into the search tree second
                .node = self.searchTree.nextIndex + 1,
                // inside: bool,
            };
            self.insert_trapezoid(lower_trapezoid);

            // update query structure
            const y_node = Node{
                .v_0 = invalid,
                .v_1 = v,
                .left_child = self.searchTree.nextIndex,
                .right_child = self.searchTree.nextIndex + 1,
            };
            // replace original leaf node with the new y node
            self.searchTree.set_node(y_node, located.node);
            // and record the index of the y-node for constant time subtree lookup
            self.y_nodes[v] = located.node;

            // insert two new trapezoid leaves underneath the y-node
            const upper_node = Node{
                // n.b. the "- 2", since we called insert_trapezoid, this is the index of the upper trap,
                // we decrement one to get the index of the previously inserted lower trap and one more
                // to get back to the index of the upper trap,
                .v_0 = self.nextIndex - 2,
                .v_1 = invalid,
                .left_child = invalid,
                .right_child = invalid,
            };
            const lower_node = Node{
                // n.b. similar to above, since we called insert_trapezoid, this is the index of the lower trap
                .v_0 = self.nextIndex - 1,
                .v_1 = invalid,
                .left_child = invalid,
                .right_child = invalid,
            };
            // _ = lower_node;
            // _ = upper_node;
            self.searchTree.insert_node(lower_node); // left_child of replaced node
            self.searchTree.insert_node(upper_node); // right_child of replaced node
        }
    }
    pub fn insert_segment(self: *TrapezoidStructure, v: u32, u: u32) void {
        const v_y_node = self.y_nodes[v];
        const u_y_node = self.y_nodes[u];
        std.debug.print("y-node: {X}\n", .{v_y_node});
        std.debug.print("{X}\n", .{u_y_node});
        const y_node = self.searchTree.nodes[v_y_node];
        std.debug.print("{any}\n\n", .{y_node});
        std.debug.print("v_0 valid? {any}\n", .{validIndex(y_node.v_0)});
        std.debug.print("v_1 valid? {any}\n\n", .{validIndex(y_node.v_1)});

        // pub fn segmentCrossing(vUpper: stl.V3, vLower: stl.V3, vHorizontal: stl.V3) f32 {
        // const f = segmentCrossing(a,b,);
        // std.debug.print("{d}\n", .{f});

        // start at v, while not at u, get 0-2 lower neighbors
        // check which at most one the segment enters
        // recurse

    }

    pub fn insert_edge(self: *TrapezoidStructure, edge: Edge) void {
        var a: u32 = undefined;
        var b: u32 = undefined;
        if (stl.lt(self.vertices.*[edge.source], self.vertices.*[edge.sink])) {
            a = edge.sink;
            b = edge.source;
        } else {
            a = edge.source;
            b = edge.sink;
        }
        self.insert_vertex(a);
        self.insert_vertex(b);
        // TODO
        // thread segment into trapezoid structure
        // need to find intersection of segment with horizontal line of neighboring traps, determine if that is left or right of vert representing horizontal line, recurse into appropriate left or right neighbor and split
        // tricky special case for totally horizontal line segments
        self.insert_segment(a, b);
    }
};

pub const Node = struct {
    // if v_0 and v_1 are valid indices, then this is an X node in sediel's terminology
    // and represents a segment which divides the tree left-right (along X)
    // if v_0 and v_1 are invalid then this is the initial root node
    // if only v_1 is a valid index then it's the index of the vertex in a Y node which divides vertically
    // if only v_0 is a valid index then it's a leaf node with the index into the trapezoid structure
    v_0: u32,
    v_1: u32,
    left_child: u32,
    right_child: u32,
};

pub const SearchTree = struct {
    nodes: []Node,
    nextIndex: u32,

    pub fn init(allocator: *std.mem.Allocator, numNodes: u32) !SearchTree {
        const nodes = try allocator.alloc(Node, numNodes);
        // nodes[0] = Node{
        //     .v_0 = invalid,
        //     .v_1 = invalid,
        //     .left_child = invalid,
        //     .right_child = invalid,
        // };
        return SearchTree{
            .nodes = nodes,
            .nextIndex = 1,
        };
    }

    pub fn deinit(self: *SearchTree, allocator: *std.mem.Allocator) void {
        allocator.free(self.nodes);
    }
    pub fn insert_node(self: *SearchTree, node: Node) void {
        self.nodes[self.nextIndex] = node;
        self.nextIndex += 1;
    }
    pub fn set_node(self: *SearchTree, node: Node, i: u32) void {
        self.nodes[i] = node;
    }
    // returns index of trapezoid containing v
    pub fn lookup(self: SearchTree, search_node: u32, v: u32, vertices: *[]stl.V3) u32 {
        if (self.nextIndex == 1) {
            // empty search tree
            return 0;
            // } else if (leadingBitSetP(search_node)) {
            // search_node is leaf
            // toggle off leading bit indicator
            // return search_node ^ leadingBit;
        } else if (validIndex(self.nodes[search_node].v_0) and validIndex(self.nodes[search_node].v_1)) {
            // X node
            // n.b. we are assuming v_0->v_1 is th ascending direction in isLeftOf
            if (isLeftOf(
                vertices.*[self.nodes[search_node].v_0],
                vertices.*[self.nodes[search_node].v_1],
                vertices.*[v],
            )) {
                return self.lookup(self.nodes[search_node].left_child, v, vertices);
            } else {
                return self.lookup(self.nodes[search_node].right_child, v, vertices);
            }
        } else if (validIndex(self.nodes[search_node].v_0)) {
            return self.nodes[search_node].v_0;
        } else {
            // Y Node
            if (stl.lt(vertices.*[v], vertices.*[self.nodes[search_node].v_1])) {
                // below horizontal line
                return self.lookup(self.nodes[search_node].left_child, v, vertices);
            } else {
                // above horizontal line
                return self.lookup(self.nodes[search_node].right_child, v, vertices);
            }
        }
    }
};
