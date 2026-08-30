class Natyv < Formula
  desc "CLI for building natyv apps -- native desktop apps with no bundled browser"
  homepage "https://github.com/natyv-io/cli"
  url "https://github.com/natyv-io/cli/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "50f65c46f43983a9572da1a7c3509fe428a9519431cbad9ed2a5cd207d0105f1"
  license "Apache-2.0"

  # Deliberately not `depends_on "zig"`: Homebrew's own zig formula tracks
  # whatever's currently stable there, not necessarily the exact pinned
  # version natyv-io/cli's own build.zig.zon requires (Zig's build system
  # and package-manifest format still churn between releases) -- see the
  # caveats block below instead.
  depends_on "natyv-shared"
  depends_on "natyv-core"

  # Real, official per-target Extism v1.30.0 static libraries -- the same
  # ones natyv-io/cli's own build.zig.zon fetches by default, vendored
  # here instead since Homebrew's own install sandbox has no network
  # access (unlike natyv-core's later, separate `zig build` invocation on
  # a developer's own machine, which fetches these normally).
  resource "extism" do
    on_macos do
      on_arm do
        url "https://github.com/extism/extism/releases/download/v1.30.0/libextism-aarch64-apple-darwin-v1.30.0.tar.gz"
        sha256 "96df7cb87f7fae7218a788b9d0f4dcac9d98d23b9c5f11e0e12d13075d75c94f"
      end
      on_intel do
        url "https://github.com/extism/extism/releases/download/v1.30.0/libextism-x86_64-apple-darwin-v1.30.0.tar.gz"
        sha256 "c2b9e3f81cf8d1c168fbac14c079e568c76420b06115df940ab38c7634cff9c9"
      end
    end
    on_linux do
      on_arm do
        url "https://github.com/extism/extism/releases/download/v1.30.0/libextism-aarch64-unknown-linux-gnu-v1.30.0.tar.gz"
        sha256 "bf4684c4cb138ce35fefdc8f44d51cab41b53765095f8f24a1d62d75909c8d7a"
      end
      on_intel do
        url "https://github.com/extism/extism/releases/download/v1.30.0/libextism-x86_64-unknown-linux-gnu-v1.30.0.tar.gz"
        sha256 "57924a2cffaf228ea209d153951371bc17c86a3527ecce374eedc4bb32c4e338"
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
      natyv does not yet verify this itself, so a mismatched `zig` on
      your PATH may surface as a confusing failure from inside
      natyv-core's own build.zig rather than a clear natyv-attributed one.
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
