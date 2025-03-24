# File to quickly generate zig code for array of all game assets, based on folder structure.
# While it's just a bunch of string manipulation to write some zig code,
# it's also not pretty, but should be understandable by looking at the code and the output it makes (assets.zig).

from os import path, scandir

FILE_HEADER = (
    """\
/// File generated by """
    + path.split(__file__)[-1]
    + """ - Manual changes will probably be overwritten.
/// Stage parts are also separated into 'Modes', which doesn't really make sense,
/// but I don't feel like having separate logic for stages.
const SDL_Texture = @import("sdl2").SDL_Texture;
const StaticMap = @import("utils.zig").StaticMap;
const fields = @import("std").meta.fields;
const print = @import("std").debug.print;

pub const Texture = struct {
    ptr: ?*SDL_Texture,
    width: c_int,
    height: c_int,
};

pub const Asset = struct {
    path: []const u8,
    id: ID,
};
"""
)

ENUM_HEADER = """\
pub const ID = enum(u16) {
"""

ENUM_FOOTER = """\

    pub inline fn int(id: ID) u16 {
        return @intFromEnum(id);
    }

    pub inline fn size() u16 {
        return fields(ID).len;
    }
};
"""


ASSETS_PRE_HEADER = "pub const ALL: ["

ASSETS_POST_HEADER = "]Asset = .{\n"

ASSETS_FOOTER = """\
};
"""

BACKING_INTEGER = "u16"

MODE_PRE_HEADER = "pub const "

MODE_POST_HEADER = "Mode = enum(" + BACKING_INTEGER + ") {\n"

ENTITY_MODE_HEADER = "pub const EntityMode = union(enum(" + BACKING_INTEGER + ")) {\n"

ENTITY_MODE_INIT_HEADER = """
    pub fn init(comptime Type: type, comptime val: @TypeOf(.enum_literal)) @This() {
        switch (Type) {
"""

ENTITY_MODE_FOOTER = """
            else => |mode| {
                print(\"\\nUnexpected entity mode: {any}\\n\", .{mode});
                unreachable; // shouldn't happen
            }
        }
    }
};
"""


ID_FROM_MODE_HEADER = """\
pub fn IDFromEntityMode(mode: EntityMode) ID {
    switch (mode) {
"""

ID_FROM_MODE_FOOTER = """\
    }
    unreachable; // shouldn't happen
}
"""

# Run this file from the project root (i.e. the battlebuds/ directory).
# Update: script is automatically called from build.zig now.
if __name__ == "__main__":
    print("\nRUNNING:", __file__, "\n")
    TAB_SIZE = 4
    asset_dir = "assets/visual"
    output_file = "src/visual_assets.zig"

    with open(output_file, "w") as outfile:
        print(FILE_HEADER, file=outfile)

        enum_string = ENUM_HEADER
        assets_string = ""
        assets_per_id = []
        texture_array_names = []
        mode_strings = []
        entity_mode_string = ENTITY_MODE_HEADER
        entity_mode_types = []
        entity_mode_field_names = []
        id_from_mode_string = ID_FROM_MODE_HEADER

        total_num_assets = 0
        for asset_type_dir in scandir(asset_dir):
            if not asset_type_dir.is_dir():
                continue

            asset_type = asset_type_dir.name

            for asset_subtype_dir in scandir(asset_type_dir.path):
                if not asset_subtype_dir.is_dir():
                    continue

                asset_subtype = asset_subtype_dir.name
                entity_mode_field = asset_type.lower() + "_" + asset_subtype.lower()
                mode_type = asset_type + asset_subtype
                mode_string = MODE_PRE_HEADER + mode_type + MODE_POST_HEADER
                id_from_mode = (
                    "\t\t."
                    + entity_mode_field
                    + " => |"
                    + entity_mode_field
                    + "_mode| switch ("
                    + entity_mode_field
                    + "_mode) {\n"
                )

                has_animations = False
                for animation_dir in scandir(asset_subtype_dir.path):
                    if not animation_dir.is_dir():
                        continue

                    has_animations = True
                    animation = animation_dir.name
                    id = (
                        asset_type.upper()
                        + "_"
                        + asset_subtype.upper()
                        + "_"
                        + animation.upper()
                    )
                    num_assets = 0

                    # We sort images by name for animation to play in order.
                    def sort_query(img) -> int:
                        return int(img.name.strip(".png"))

                    for image in sorted(scandir(animation_dir.path), key=sort_query):
                        if not image.is_file():
                            continue

                        num_assets += 1
                        assets_string += (
                            '\t.{ .path = "'
                            + path.relpath(image.path, ".")
                            + '", .id = .'
                            + id
                            + " },\n"
                        )

                    if num_assets > 0:
                        mode = animation.upper()
                        enum_string += "\t" + id + ",\n"
                        mode_string += "\t" + mode + ",\n"
                        id_from_mode += "\t\t\t." + mode + " => return ID." + id + ",\n"
                        assets_per_id.append(num_assets)
                        texture_array_names.append(id.lower() + "_textures")
                        total_num_assets += num_assets

                if has_animations:
                    entity_mode_string += (
                        "\t" + entity_mode_field + ": " + mode_type + "Mode,\n"
                    )
                    entity_mode_types.append(mode_type)
                    entity_mode_field_names.append(entity_mode_field)
                    mode_strings.append(mode_string + "};\n")
                    id_from_mode += "\t\t},\n"
                    id_from_mode_string += id_from_mode

        enum_string += ENUM_FOOTER
        print(enum_string.expandtabs(TAB_SIZE), file=outfile)

        id_from_mode_string += ID_FROM_MODE_FOOTER
        print(id_from_mode_string.expandtabs(TAB_SIZE), file=outfile)

        entity_mode_string += ENTITY_MODE_INIT_HEADER

        for type, field in zip(entity_mode_types, entity_mode_field_names):
            entity_mode_string += (
                "\t\t\t"
                + type + "Mode"
                + ' => |Enum| return @unionInit(@This(), "'
                + field
                + '", @as(Enum, val)),\n'
            )

        entity_mode_string += ENTITY_MODE_FOOTER
        print((entity_mode_string).expandtabs(TAB_SIZE), file=outfile)

        for string in mode_strings:
            print(string.expandtabs(TAB_SIZE), file=outfile)

        assets_string = (
            ASSETS_PRE_HEADER
            + str(total_num_assets)
            + ASSETS_POST_HEADER
            + assets_string
        )
        assets_string += ASSETS_FOOTER
        print(assets_string.expandtabs(TAB_SIZE), file=outfile)

        assets_per_id_string = (
            "pub const ASSETS_PER_ID: [ID.size()]usize = .{ "
            + str(assets_per_id)[1:-1]
            + " };\n"
        )
        print(assets_per_id_string.expandtabs(TAB_SIZE), file=outfile)

        print("// Storage for textures to be initialized at runtime.", file=outfile)
        for size, array_name in zip(assets_per_id, texture_array_names):
            print(
                "var " + array_name + ": [" + str(size) + "]Texture = undefined;",
                file=outfile,
            )

        print("\npub var texture_slices: [ID.size()][]Texture = .{", file=outfile)
        for array_name in texture_array_names:
            print(("\t&" + array_name + ",").expandtabs(TAB_SIZE), file=outfile)
        print("};", file=outfile)
