const std = @import("std");

pub fn build(b: *std.Build) void {
    const Feature = std.Target.x86.Feature;

    var disabled = std.Target.Cpu.Feature.Set.empty;
    disabled.addFeature(@intFromEnum(Feature.mmx));
    disabled.addFeature(@intFromEnum(Feature.sse));
    disabled.addFeature(@intFromEnum(Feature.sse2));
    disabled.addFeature(@intFromEnum(Feature.avx));
    disabled.addFeature(@intFromEnum(Feature.avx2));

    var enabled = std.Target.Cpu.Feature.Set.empty;
    enabled.addFeature(@intFromEnum(Feature.soft_float));

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = disabled,
        .cpu_features_add = enabled,
    });

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kfs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .stack_protector = false,
            .red_zone = false,
            .code_model = .kernel,
        }),
    });

    kernel.root_module.addAssemblyFile(b.path("boot.s"));
    kernel.root_module.addAssemblyFile(b.path("src/arch/x86/gdt.s"));
    kernel.root_module.addAssemblyFile(b.path("src/arch/x86/interrupts.s"));
    kernel.setLinkerScript(b.path("linker.ld"));
    b.installArtifact(kernel);

    const gdt_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/arch/x86/gdt.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    const run_gdt_tests = b.addRunArtifact(gdt_tests);

    const idt_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/arch/x86/idt.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    const run_idt_tests = b.addRunArtifact(idt_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_gdt_tests.step);
    test_step.dependOn(&run_idt_tests.step);
}
