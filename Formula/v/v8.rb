class V8 < Formula
  desc "Google's JavaScript engine"
  homepage "https://github.com/v8/v8/wiki"
  # Track V8 version from Chrome stable: https://chromiumdash.appspot.com/releases?platform=Mac
  url "https://github.com/v8/v8/archive/11.7.439.15.tar.gz"
  sha256 "2fc5131a2ee3c44f935cc353284902a448cf4c7f8abd2de434e4d522ef1675d0"
  license "BSD-3-Clause"

  livecheck do
    url "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Mac"
    regex(/(\d+\.\d+\.\d+\.\d+)/i)
    strategy :json do |json, regex|
      # Find the v8 commit hash for the newest Chromium release version
      v8_hash = json.max_by { |item| Version.new(item["version"]) }.dig("hashes", "v8")
      next if v8_hash.blank?

      # Check the v8 commit page for version text
      v8_page = Homebrew::Livecheck::Strategy.page_content(
        "https://chromium.googlesource.com/v8/v8.git/+/#{v8_hash}",
      )
      v8_page[:content]&.scan(regex)&.map { |match| match[0] }
    end
  end

  bottle do
    sha256 cellar: :any,                 arm64_ventura:  "26622cb1e34064011d53c9aa2193cc8b28224f14cdc334d38b1d84cdaf604684"
    sha256 cellar: :any,                 arm64_monterey: "1a5df5a4b8ff1f06218c9068e952c396d4973b11db3dcd93ea738c3a459e481b"
    sha256 cellar: :any,                 arm64_big_sur:  "4b9ee5ada8c24b6411822d219f9a38e8fb57f1ce6c64ece21c4b0d46b4e96ab1"
    sha256 cellar: :any,                 ventura:        "ed3665e0ad5615d7c615e47c077effcb968f62330c6a589500a53d01290deb05"
    sha256 cellar: :any,                 monterey:       "1d4a9462e4cce755fb8ef46ab9fee80d81e0011f56029a199b8e1be3dc74de46"
    sha256 cellar: :any,                 big_sur:        "50fa9c83a3474fe33576ee6314d6201f92b8001f8d47a6f3fdfc3cb7c40c2561"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "982f4018916b7a165c3bd83bf208c0a9a3a097f024df7189b4009b4fa452301f"
  end

  depends_on "ninja" => :build
  depends_on "python@3.11" => :build

  on_macos do
    depends_on "llvm" => :build
    depends_on xcode: ["10.0", :build] # required by v8
  end

  on_linux do
    depends_on "pkg-config" => :build
    depends_on "glib"
  end

  fails_with gcc: "5"

  # Look up the correct resource revisions in the DEP file of the specific releases tag
  # e.g. for CIPD dependency gn: https://chromium.googlesource.com/v8/v8.git/+/refs/tags/<version>/DEPS#64
  resource "gn" do
    url "https://gn.googlesource.com/gn.git",
        revision: "811d332bd90551342c5cbd39e133aa276022d7f8"
  end

  resource "v8/base/trace_event/common" do
    url "https://chromium.googlesource.com/chromium/src/base/trace_event/common.git",
        revision: "147f65333c38ddd1ebf554e89965c243c8ce50b3"
  end

  resource "v8/build" do
    url "https://chromium.googlesource.com/chromium/src/build.git",
        revision: "afe0125ef9e10b400d9ec145aa18fca932369346"
  end

  resource "v8/third_party/googletest/src" do
    url "https://chromium.googlesource.com/external/github.com/google/googletest.git",
        revision: "af29db7ec28d6df1c7f0f745186884091e602e07"
  end

  resource "v8/third_party/icu" do
    url "https://chromium.googlesource.com/chromium/deps/icu.git",
        revision: "de4ce0071eb47ed54cbda54869001210cf3a8ae5"
  end

  resource "v8/third_party/jinja2" do
    url "https://chromium.googlesource.com/chromium/src/third_party/jinja2.git",
        revision: "515dd10de9bf63040045902a4a310d2ba25213a0"
  end

  resource "v8/third_party/markupsafe" do
    url "https://chromium.googlesource.com/chromium/src/third_party/markupsafe.git",
        revision: "006709ba3ed87660a17bd4548c45663628f5ed85"
  end

  resource "v8/third_party/zlib" do
    url "https://chromium.googlesource.com/chromium/src/third_party/zlib.git",
        revision: "526382e41c9c5275dc329db4328b54e4f344a204"
  end

  resource "v8/third_party/abseil-cpp" do
    url "https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp.git",
        revision: "583dc6d1b3a0dd44579718699e37cad2f0c41a26"
  end

  def install
    (buildpath/"build").install resource("v8/build")
    (buildpath/"third_party/jinja2").install resource("v8/third_party/jinja2")
    (buildpath/"third_party/markupsafe").install resource("v8/third_party/markupsafe")
    (buildpath/"third_party/googletest/src").install resource("v8/third_party/googletest/src")
    (buildpath/"base/trace_event/common").install resource("v8/base/trace_event/common")
    (buildpath/"third_party/icu").install resource("v8/third_party/icu")
    (buildpath/"third_party/zlib").install resource("v8/third_party/zlib")
    (buildpath/"third_party/abseil-cpp").install resource("v8/third_party/abseil-cpp")

    # Build gn from source and add it to the PATH
    (buildpath/"gn").install resource("gn")
    cd "gn" do
      system "python3.11", "build/gen.py"
      system "ninja", "-C", "out/", "gn"
    end
    ENV.prepend_path "PATH", buildpath/"gn/out"

    # create gclient_args.gni
    (buildpath/"build/config/gclient_args.gni").write <<~EOS
      declare_args() {
        checkout_google_benchmark = false
      }
    EOS

    # setup gn args
    gn_args = {
      is_debug:                     false,
      is_component_build:           true,
      v8_use_external_startup_data: false,
      v8_enable_i18n_support:       true, # enables i18n support with icu
      clang_base_path:              "\"#{Formula["llvm"].opt_prefix}\"", # uses Homebrew clang instead of Google clang
      clang_use_chrome_plugins:     false, # disable the usage of Google's custom clang plugins
      use_custom_libcxx:            false, # uses system libc++ instead of Google's custom one
      treat_warnings_as_errors:     false, # ignore not yet supported clang argument warnings
      use_lld:                      false, # upstream use LLD but this leads to build failure on ARM
    }

    if OS.linux?
      gn_args[:is_clang] = false # use GCC on Linux
      gn_args[:use_sysroot] = false # don't use sysroot
      gn_args[:custom_toolchain] = "\"//build/toolchain/linux/unbundle:default\"" # uses system toolchain
      gn_args[:host_toolchain] = "\"//build/toolchain/linux/unbundle:default\"" # to respect passed LDFLAGS
      ENV["AR"] = DevelopmentTools.locate("ar")
      ENV["NM"] = DevelopmentTools.locate("nm")
      gn_args[:use_rbe] = false
    end

    # Make sure private libraries can be found from lib
    ENV.prepend "LDFLAGS", "-Wl,-rpath,#{rpath(target: libexec)}"

    # Transform to args string
    gn_args_string = gn_args.map { |k, v| "#{k}=#{v}" }.join(" ")

    # Build with gn + ninja
    system "gn", "gen", "--args=#{gn_args_string}", "out.gn"
    system "ninja", "-j", ENV.make_jobs, "-C", "out.gn", "-v", "d8"

    # Install libraries and headers into libexec so d8 can find them, and into standard directories
    # so other packages can find them and they are linked into HOMEBREW_PREFIX
    libexec.install "include"

    # Make sure we don't symlink non-headers into `include`.
    header_files_and_directories = (libexec/"include").children.select do |child|
      (child.extname == ".h") || child.directory?
    end
    include.install_symlink header_files_and_directories

    libexec.install "out.gn/d8", "out.gn/icudtl.dat"
    bin.write_exec_script libexec/"d8"

    libexec.install Pathname.glob("out.gn/#{shared_library("*")}")
    lib.install_symlink libexec.glob(shared_library("libv8*"))
    lib.glob("*.TOC").map(&:unlink) if OS.linux? # Remove symlinks to .so.TOC text files
  end

  test do
    assert_equal "Hello World!", shell_output("#{bin}/d8 -e 'print(\"Hello World!\");'").chomp
    t = "#{bin}/d8 -e 'print(new Intl.DateTimeFormat(\"en-US\").format(new Date(\"2012-12-20T03:00:00\")));'"
    assert_match %r{12/\d{2}/2012}, shell_output(t).chomp

    (testpath/"test.cpp").write <<~EOS
      #include <libplatform/libplatform.h>
      #include <v8.h>
      int main(){
        static std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
        v8::V8::InitializePlatform(platform.get());
        v8::V8::Initialize();
        return 0;
      }
    EOS

    # link against installed libc++
    system ENV.cxx, "-std=c++17", "test.cpp",
                    "-I#{include}", "-L#{lib}",
                    "-Wl,-rpath,#{libexec}",
                    "-lv8", "-lv8_libplatform"
  end
end
