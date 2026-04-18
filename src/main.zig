const std = @import("std");
const shlex = @import("shlex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const cmd = init.environ_map.get("SSH_ORIGINAL_COMMAND") orelse {
        std.log.err("SSH_ORIGINAL_COMMAND not set", .{});
        std.process.exit(1);
    };

    const tokens = shlex.split(allocator, cmd, false, true) catch |err| {
        std.log.err("failed to parse SSH_ORIGINAL_COMMAND: {}", .{err});
        std.process.exit(1);
    };
    defer {
        for (tokens) |t| allocator.free(t);
        allocator.free(tokens);
    }

    // must be an invocation of git-receive-pack with the path (therefore 2 tokens)
    if (tokens.len < 2 or !std.mem.eql(u8, tokens[0], "git-receive-pack")) {
        return execGitShell(allocator, io, cmd);
    }

    const repo_path_raw = tokens[tokens.len - 1];

    var repo_path_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const repo_path = blk: {
        if (std.fs.path.isAbsolute(repo_path_raw)) {
            break :blk repo_path_raw;
        }
        const home = init.environ_map.get("HOME") orelse ".";
        break :blk try std.fmt.bufPrint(&repo_path_buf, "{s}/{s}", .{ home, repo_path_raw });
    };

    std.Io.Dir.accessAbsolute(io, repo_path, .{}) catch {
        std.log.info("auto-initializing bare repo at {s}", .{repo_path});
        const result = try std.process.run(allocator, io, .{
            .argv = &.{ "git", "init", "--bare", repo_path },
        });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term != .exited or result.term.exited != 0) {
            std.log.err("git init --bare failed: {s}", .{result.stderr});
            std.process.exit(1);
        }
    };

    return execGitShell(allocator, io, cmd);
}

fn execGitShell(allocator: std.mem.Allocator, io: std.Io, cmd: []const u8) !void {
    const argv = try allocator.dupe([]const u8, &.{ "git-shell", "-c", cmd });
    defer allocator.free(argv);
    return std.process.replace(io, .{ .argv = argv });
}
