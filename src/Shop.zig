const std = @import("std");
const rl = @import("raylib");

const build_options = @import("build_options");

const emasm = @import("emasm.zig");
const Board = @import("Board.zig");
const Button = @import("ui/Button.zig");

const SHOP_BG: rl.Color = .{ .r = 128, .g = 42, .b = 98, .a = 255 };
const SHOP_TEXT: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
const SHOP_PADDING: rl.Vector2 = .{ .x = 20, .y = 20 };

const TITLE_FONT_SIZE = 44;
const MONEY_FONT_SIZE = 22;
const UPGRADE_FONT_SIZE = 44;
const UPGRADE_DESC_FONT_SIZE = 22;
const UPGRADE_COUNT_FONT_SIZE = 22;
const SHOP_POLL_TIME = 0.2;

const UPGRADE_PADDING = 5;

pub const Upgrade = enum { spread, monkey, focus, monkey_focus, monkey_spread };

const UpgradeInfo = struct {
    name: [:0]const u8,
    desc: [:0]const u8,

    base_cost: f32,
    mult: f32,
};

const UPGRADE_DATA: std.enums.EnumArray(Upgrade, UpgradeInfo) = .init(.{
    .spread = .{
        .name = "Spread",
        .desc = "Throw multiple darts at once",

        .base_cost = 100,
        .mult = 1.5,
    },
    .monkey = .{
        .name = "Monkey",
        .desc = "Throws darts for you",

        .base_cost = 300,
        .mult = 1.75,
    },
    .focus = .{
        .name = "Focus",
        .desc = "Throw darts more accurately",

        .base_cost = 500,
        .mult = 1.5,
    },
    .monkey_focus = .{
        .name = "Monkey focus",
        .desc = "Help Monkeys throw darts\nmore accurately",

        .base_cost = 800,
        .mult = 1.5,
    },
    .monkey_spread = .{
        .name = "Monkey spread",
        .desc = "Monkeys throw more darts\nat once",

        .base_cost = 1000,
        .mult = 2.0,
    },
});

const Shop = @This();

upgrade_buttons: std.enums.EnumArray(Upgrade, Button) = .initFill(.{
    .text_size = 0,
    .bounds = undefined,
}),

pub fn init(self: *Shop, bounds: rl.Rectangle) void {
    var pos: rl.Vector2 = .{
        .x = bounds.x + SHOP_PADDING.x,
        .y = bounds.y + SHOP_PADDING.y,
    };
    pos.y += TITLE_FONT_SIZE; // SHOP TITLE
    pos.y += MONEY_FONT_SIZE; // MONEY TEXT
    pos.y += UPGRADE_PADDING; // PAD

    for (std.enums.values(Upgrade)) |upgrade| {
        pos.y += UPGRADE_PADDING;

        const button = self.upgrade_buttons.getPtr(upgrade);

        const total_height: f32 = UPGRADE_PADDING + UPGRADE_FONT_SIZE + UPGRADE_DESC_FONT_SIZE * 2 + UPGRADE_PADDING;

        button.bounds = .{
            .x = pos.x,
            .y = pos.y,
            .width = bounds.width - SHOP_PADDING.x * 2,
            .height = total_height,
        };
        button.state.disabled = true;

        pos.y += total_height;
    }
}

pub const WebPayload = extern struct {
    payload_idx: usize,
    processed_darts: usize,

    shot_stats: extern struct {
        darts_per_shot: u32,
        aim_focus: f32,
    },

    monkey_stats: extern struct {
        shots_per_second: f32,
        darts_per_shot: u32,
        aim_focus: f32,
    },
};

pub fn update(self: *Shop, done: bool, board: *Board, bounds: rl.Rectangle, dt: f32) void {
    _ = bounds;

    switch (board.player) {
        .user => {
            for (std.enums.values(Upgrade)) |upgrade| {
                const cost = upgradeCost(board, upgrade);

                const button = self.upgrade_buttons.getPtr(upgrade);

                button.state.disabled = done or cost > board.money;

                button.update();

                if (button.isPressed()) {
                    board.buyUpgrade(upgrade);
                    board.money -= @intCast(cost);
                    board.upgrade_counts.getPtr(upgrade).* += 1;

                    board.shopSend();
                }
            }
        },
        .ai => |ai| {
            for (std.enums.values(Upgrade)) |upgrade| {
                const cost = upgradeCost(board, upgrade);
                if (cost > board.money)
                    continue;

                if (rl.getRandomValue(0, 100) < ai.upgrade_rate) {
                    board.buyUpgrade(upgrade);
                    board.money -= @intCast(cost);
                    board.upgrade_counts.getPtr(upgrade).* += 1;
                }
            }
        },
        .web => {
            board.player.web.poll_timer += dt;
            if (board.player.web.poll_timer > 0.2) {
                read: {
                    var data: WebPayload = undefined;

                    if (emasm.EM_ASM_INT(
                        \\data = shop_sync();
                        \\if (data.length < 1) return 0;
                        \\const stringData = JSON.parse(data);
                        \\const stringBytes = new Uint8Array(Object.values(stringData));
                        \\const memoryView = new Uint8Array(wasmMemory.buffer, $0, $1);
                        \\memoryView.set(stringBytes);
                        \\return 1;
                    , .{ &data, @as(i32, @sizeOf(WebPayload)) }) == 0)
                        break :read;

                    if (data.payload_idx <= board.player.web.last_sync)
                        break :read;

                    board.player.web.last_sync = data.payload_idx;
                    board.processed_darts = data.processed_darts;
                    board.monkey_stats = @bitCast(data.monkey_stats);
                    board.shot_stats = @bitCast(data.shot_stats);
                }

                board.player.web.poll_timer = 0.0;
            }
        },
    }
}

pub fn draw(self: *const Shop, board: *const Board, bounds: rl.Rectangle) void {
    var fmt_buf: [64]u8 = undefined;

    rl.drawRectangleRec(bounds, SHOP_BG);

    var pos: rl.Vector2 = .{
        .x = bounds.x + SHOP_PADDING.x,
        .y = bounds.y + SHOP_PADDING.y,
    };

    //draw title
    rl.drawText(
        build_options.GAME_NAME,
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        TITLE_FONT_SIZE,
        SHOP_TEXT,
    );
    pos.y += TITLE_FONT_SIZE;

    //draw money/points
    const money_text = std.fmt.bufPrintSentinel(
        &fmt_buf,
        "Points: {d}",
        .{board.money},
        0,
    ) catch unreachable;

    rl.drawText(
        money_text,
        @intFromFloat(pos.x),
        @intFromFloat(pos.y),
        MONEY_FONT_SIZE,
        SHOP_TEXT,
    );
    pos.y += MONEY_FONT_SIZE;
    pos.y += UPGRADE_PADDING;

    for (std.enums.values(Upgrade)) |upgrade| {
        pos.y += UPGRADE_PADDING;

        const info = UPGRADE_DATA.getPtrConst(upgrade);
        const button = self.upgrade_buttons.getPtrConst(upgrade);

        button.draw("");

        pos.y += UPGRADE_PADDING;

        const count_text = std.fmt.bufPrintSentinel(
            &fmt_buf,
            "({})",
            .{board.upgrade_counts.get(upgrade)},
            0,
        ) catch unreachable;
        const width: f32 = @floatFromInt(rl.measureText(count_text, UPGRADE_FONT_SIZE));

        rl.drawText(
            count_text,
            @intFromFloat(bounds.x + bounds.width - SHOP_PADDING.x - width),
            @intFromFloat(pos.y),
            UPGRADE_COUNT_FONT_SIZE,
            Button.TEXT_COLOR,
        );

        rl.drawText(
            info.name,
            @intFromFloat(pos.x + UPGRADE_PADDING),
            @intFromFloat(pos.y),
            UPGRADE_FONT_SIZE,
            Button.TEXT_COLOR,
        );
        pos.y += UPGRADE_FONT_SIZE;
        rl.drawText(
            info.desc,
            @intFromFloat(pos.x + UPGRADE_PADDING),
            @intFromFloat(pos.y),
            UPGRADE_DESC_FONT_SIZE,
            Button.TEXT_COLOR,
        );
        pos.y += UPGRADE_DESC_FONT_SIZE * 2;

        pos.y += UPGRADE_PADDING;
    }
}

pub fn upgradeCost(board: *const Board, upgrade: Upgrade) i32 {
    const info = UPGRADE_DATA.getPtrConst(upgrade);

    const purchased = @as(f32, @floatFromInt(board.upgrade_counts.get(upgrade)));

    return @intFromFloat(info.base_cost * std.math.pow(f32, info.mult, purchased));
}
