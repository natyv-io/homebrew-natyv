class Natyv < Formula
  desc "CLI for building natyv apps -- native desktop apps with no bundled browser"
  homepage "https://github.com/natyv-io/cli"
  url "https://github.com/natyv-io/cli/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "21ca760c2aa76fc78fb6aa4c1d58c4686c3974ef902ca4d222b91073c6e9edf9"
  license "Apache-2.0"

  # Deliberately not `depends_on "zig"`: Homebrew's own zig formula tracks
  # whatever's currently stable there, not necessarily the exact pinned
  # version natyv-io/cli's own build.zig.zon requires (Zig's build system
  # and package-manifest format still churn between releases) -- see the
  # caveats block below instead.
  depends_on "natyv-shared"
  depends_on "natyv-core"

  # Real, official per-target Extism v1.41.0 static libraries -- the same
  # ones natyv-io/cli's own build.zig.zon fetches by default, vendored
  # here instead since Homebrew's own install sandbox has no network
  # access (unlike natyv-core's later, separate `zig build` invocation on
  # a developer's own machine, which fetches these normally).
  resource "extism" do
    on_macos do
      on_arm do
        url "https://github.com/extism/extism/releases/download/v1.41.0/libextism-aarch64-apple-darwin-v1.41.0.tar.gz"
        sha256 "a6b1bcdecea3fcb0bcb20908a992d32e4c1f714683d15771735eaa7ef47d6aae"
      end
      on_intel do
        url "https://github.com/extism/extism/releases/download/v1.41.0/libextism-x86_64-apple-darwin-v1.41.0.tar.gz"
        sha256 "163769b36ffee26a3e1f8fe1cc695bd2d9d83deb1d8fc728dfa20dedce87e2cf"
      end
    end
    on_linux do
      on_arm do
        url "https://github.com/extism/extism/releases/download/v1.41.0/libextism-aarch64-unknown-linux-gnu-v1.41.0.tar.gz"
        sha256 "c8bf58093b036a6741408511c74ba27da1d6f5c9a48b2668fa7638a7028ad66c"
      end
      on_intel do
        url "https://github.com/extism/extism/releases/download/v1.41.0/libextism-x86_64-unknown-linux-gnu-v1.41.0.tar.gz"
        sha256 "753cef478c853556212f6ad64b6e98adbc8b7908931c54b79678bb7c1fb2643b"
      end
    end
  end

  def install
    # `zig` is deliberately not a `depends_on` (see above), so Homebrew's
    # own sandboxed build PATH -- confirmed for real to exclude anywhere
    # a manually-installed `zig` actually lives -- never has it on PATH.
    # `ORIGINAL_PATHS` is Homebrew's own established idiom for exactly
    # this: locating a real, non-brew-managed tool from the user's actual
    # environment rather than the restricted build sandbox one.
    zig = which("zig", ORIGINAL_PATHS)
    odie "natyv requires a real `zig` install on your PATH (see this formula's caveats for the version natyv-io/cli was built against) -- none found" if zig.nil?
    ENV.prepend_path "PATH", zig.dirname

    # Zig's own package manager requires a `.path` dependency's value to
    # be a real relative path from the consuming package's build root --
    # confirmed the hard way (a real compile error, "expected path
    # relative to build root; found absolute path") when this first tried
    # a plain absolute `opt_prefix`.
    shared_relative = Formula["natyv-shared"].opt_prefix.relative_path_from(buildpath)
    zon_path = Pathname.new("build.zig.zon")
    contents = zon_path.read
    contents.sub!(/\.shared\s*=\s*\.\{[^}]*\}/, ".shared = .{ .path = \"#{shared_relative}\" }")
    zon_path.atomic_write(contents)

    # `-Dextism-prefix` expects a real `include/`+`lib/` layout (matching
    # Extism's own `extism lib install` tool, which is what this flag was
    # originally designed for) -- confirmed the hard way ("file not
    # found") that the raw per-target release tarball's own flat layout
    # (extism.h/libextism.a side by side, no subdirectories) doesn't match
    # that on its own, so it has to be restructured here.
    extism_dir = buildpath/"extism-vendor"
    resource("extism").stage do
      (extism_dir/"include").install "extism.h"
      (extism_dir/"lib").install "libextism.a"
    end

    # `--prefix` takes a separate argv element, not `--prefix=value` --
    # confirmed the hard way ("unrecognized argument"), matching
    # natyv-io/cli's own established convention for this exact flag.
    system "zig", "build", "install",
           "-Dnatyv-core-src=#{Formula["natyv-core"].opt_prefix}",
           "-Dextism-prefix=#{extism_dir}",
           "--prefix", prefix
  end

  def caveats
    <<~EOS
      natyv build requires a real `zig` install matching the version
      natyv-io/cli's own build.zig.zon was built against -- see
      https://github.com/natyv-io/cli for the currently pinned version.
      natyv checks `zig version` before every prepare/build and reports
      a clear error if the `zig` on your PATH doesn't match.
    EOS
  end

  test do
    # `natyv` (no subcommand) is a real, documented usage error -- exits
    # non-zero with a real usage line on stderr. No side-effect-free
    # success path exists to test against instead (every real subcommand
    # needs a conf.natyv.json/guest dir), so this is the honest check.
    output = shell_output("#{bin}/natyv 2>&1", 1)
    assert_match "usage: natyv", output
  end
end
