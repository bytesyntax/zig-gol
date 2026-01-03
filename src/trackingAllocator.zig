const std = @import("std");

pub const TrackingAllocator = struct {
    child: std.mem.Allocator,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const p = self.child.rawAlloc(len, alignment, ret_addr) orelse return null;

        self.live_bytes += len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        return p;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.live_bytes -= buf.len;
        self.child.rawFree(buf, alignment, ret_addr);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const ok = self.child.rawResize(buf, alignment, new_len, ret_addr);
        if (ok) {
            self.live_bytes = self.live_bytes - buf.len + new_len;
            self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        }
        return ok;
    }

    fn remap(
        ctx: *anyopaque,
        buf: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));

        const new_ptr = self.child.rawRemap(buf, alignment, new_len, ret_addr) orelse return null;

        self.live_bytes = self.live_bytes - buf.len + new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);

        return new_ptr;
    }
};
