const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const global_alloc = arena.allocator();
const max_read = 21 * 1024;

pub fn main() !void {
    const data = try loadData(global_alloc, "data/prod.txt");
    // These can't be run together, as they modify the data in place.

    // try part1(data);
    try part2(data);
}


fn part1(data:[]u8) !void {
    var block_list = try std.ArrayList(usize).initCapacity(global_alloc, data.len);

    var counter: usize = 0;
    // Max id, So we start counting back;
    var j: usize = data.len - 1;
    var back_id: usize = if (j % 2 == 0)  j / 2 else j/2 + 1;
    var front_id: usize = 0;

    while (counter <= j) : (counter += 1) {
        var block_count: u8 = data[counter];
        if (counter % 2 == 0) {
            // Existing Blocks
            try block_list.appendNTimes(front_id, block_count);
            front_id += 1;
        } else {
            // Free Space/ Compression
            var xfer_count = data[j];
            while (block_count > 0) {
                if (xfer_count > block_count) {
                    try block_list.appendNTimes(back_id, block_count);
                    xfer_count -= block_count;
                    block_count = 0;
                    data[j] = xfer_count;
                } else {
                    try block_list.appendNTimes(back_id, xfer_count);
                    block_count -= xfer_count;
                    j -= 2;
                    back_id -= 1;
                    xfer_count = data[j];
                }
            }
        }
    }
    std.debug.print("Hash: {d}\n", .{hash(block_list.items)});
}

fn part2(data: []u8) !void {
    // Build out the Free List
    const list_front: *ListNode, const list_back: *ListNode  = try buildFreeList(data);
    var blocks_back:?*ListNode = list_back;
    // Go through each file from the back and move it to the front
    files: while (blocks_back) |file|{
        if (file.data == .free) {
            blocks_back = file.prev;
            continue;
        }

        var free_block: ?*ListNode = list_front;
        // Find space to move it;
        frees: while (free_block) |free| {
            if (free.data == .file) {
                free_block = free.next;
                continue :frees;
            }
            if (free.data.free.start > file.data.file.start) {
                break :frees;
            }
            if (file.data.file.size <= free.data.free.size) {
                blocks_back = file.prev;
                try coalasce(file);
                free.insert(file);
                // Insert file into free location
                file.data.file.start = free.data.free.start;
                free.data.free.size -= file.getSize();
                free.data.free.start += file.getSize();
                // displayList(list_front.*);
                continue :files;
            }
            free_block = free.next;
        }
       blocks_back = file.prev;
    }

    var total: usize = 0;
    var list: ?*ListNode = list_front;
    while (list) |file| {
        if (file.data == .file) {
            total += subhash(file.data.file.size, file.data.file.start, file.data.file.id);
        }
        list = file.next;
    }

    displayList(list_front.*);
    std.debug.print("Hash: {d}\n", .{total});

}

// DEBUG ONLY SUPER INEF
fn displayList(data: ListNode) void {
    var list: ?*const ListNode = &data;


    while (list) |l|{
        switch (l.data) {
            .free => |d| {
                for(0..d.size) |_|{
                    std.debug.print(".", .{});
                }
            },
            .file => |d| {
                for (0..d.size) |_|{
                    std.debug.print("{d}", .{d.id});
                }
            }
        }
        list = l.next;
    }
    std.debug.print("\n", .{});
}

// Combine the prev and next nodes if, they are both free, into one large free
// chunk
fn coalasce(node:*ListNode) !void {
    var next = node.next;
    const prev = node.prev;
    var free_sapce = node.data.getSize();


    // Situations we need to think about



    // Free Free Free => coalesce all three into one value)
    if (
        next != null and next.?.data == .free and
        prev != null and prev.?.data == .free) {

        free_sapce += next.?.getSize();

        next = next.?.next;
        // prev beccomes main node
        prev.?.data.free.size += free_sapce;
        prev.?.next = next;
        if (next) |n| {
            n.prev = prev;
        }
        return;
    }
    // File Free Free => coalesce last two
    // Null Free Free => Coalesce last two
    if (next != null and next.?.data == .free) {
        next.?.data.free.size += free_sapce;
        next.?.prev = prev;
        if (prev) |p| {
            p.next = next;
        }
        return;
    }
    // File Free File => create new node
    // File Free Null => Create New node
    // Null Free File => Create New Node
    if ((next != null and next.?.data == .file and prev == null) or 
        (prev != null and prev.?.data == .file and next == null) or
        (prev != null and prev.?.data == .file and next != null and next.?.data == .file)) {

        const new_node: *ListNode = try global_alloc.create(ListNode);
        const data: FreeData = .{ .size = node.data.getSize(), .start=node.data.file.start };
        new_node.initUnmanaged(.{ .free =  data}, prev, next);
        if (prev) |p| {
            p.next = new_node;
        }
        if (next) |n| {
            n.prev = new_node;
        }
        return;
    }
    // Free Free Null => Coalesce First two
    // Free Free File => coalesce first two
    if (prev != null and prev.?.data == .free) {
        prev.?.data.free.size += free_sapce;
        prev.?.next = next;
        if (next) |n| {
            n.prev = prev;
        }
        return;
    }

}

fn buildFreeList(data:[]u8) !struct {*ListNode, *ListNode} {
    var list: *ListNode = try global_alloc.create(ListNode);
    const list_node_data: FileData = .{.size = data[0], .start = 0, .id = 0};
    list.initUnmanaged(ListData{.file = list_node_data}, null, null);

    var curr: *ListNode = list;
    var pos: usize = curr.data.file.start + curr.data.file.size;
    var file_id: usize = 1;
    for (data[1..], 1..) |value, i| {
        if (i % 2 == 0) {
            const next = try global_alloc.create(ListNode);
            const d: FileData = .{.id = file_id, .start = pos, .size = value};
            next.initUnmanaged(ListData{.file = d}, curr, null);
            curr.next = next;
            curr = next;
            pos += value;
            file_id += 1;
        } else {
            const next = try global_alloc.create(ListNode);
            const d: FreeData = .{.start = pos, .size = value};
            next.initUnmanaged(ListData{.free = d}, curr, null);
            curr.next = next;
            curr = next;

            pos += value;
        }
    }
    return .{list, curr};
}

const FreeData = struct {
    size: usize,
    start: usize,
};

const FileData = struct {
    id: usize,
    start: usize,
    size: usize,
};

const ListData = union(enum) {
    file: FileData,
    free: FreeData,

    pub fn getSize(self: ListData) usize {
        return switch (self) {
            .file => |v| v.size,
            .free => |v| v.size,
        };
    }
};

const ListNode = struct {
    data: ListData,
    prev: ?*ListNode,
    next: ?*ListNode,

    fn initUnmanaged(self: *ListNode, data: ListData, prev:?*ListNode, next: ?*ListNode) void {
        self.*.data = data;
        self.*.prev = prev;
        self.*.next = next;
    }


    fn insert(self: *ListNode, other:*ListNode) void {
        // Insert other infront of self
        other.next = self;
        other.prev = self.prev;

        if (self.prev) |p| {
            p.next = other;
        }
        self.prev = other;
    }

    fn getSize(self: ListNode) usize {
        return ListData.getSize(self.data);
    }
};


/// Computes the sub hash for a range
/// n is the number of blocks
/// offset is the offset
/// id is the id of the file
fn subhash(n: usize, offset: usize, id: usize) usize {
    var total: usize = 0;
    for (offset..offset+n) |i| {
        total += i * id;
    }
    return total;
}

fn hash(data: []usize) usize {
    var total:usize = 0;
    for (data, 0..) |value, i| {
        total += value * i;
    }
    return total;
}

/// Load the Data from path
fn loadData(allocator: Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    const data = try fd.readToEndAlloc(allocator, max_read);
    var iter = std.mem.splitScalar(u8, data, '\n');
    var i: usize = 0;
    for (iter.first()) |value| {
        data[i] = value - '0';
        i += 1;
    }
    return data[0..i];
}
