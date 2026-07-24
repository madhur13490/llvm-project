# AGENTS.md

## Cursor Cloud specific instructions

This is the LLVM monorepo (a fork of `llvm/llvm-project`). The "product" is the
compiler toolchain (`clang`, `opt`, `llc`, ...). The configured dev scope in the
cloud environment is the core **LLVM + Clang** build; other subprojects (mlir,
lldb, flang, bolt, libc, libcxx, etc.) are not enabled by default because a full
all-projects build is impractical here.

### Build directory & configuration

A pre-configured Release build tree lives at `build-rel/` (Release +
assertions, `X86` target only, `clang` project). It was configured with:

```
cmake -S llvm -B build-rel -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_LLD=ON \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DLLVM_USE_SPLIT_DWARF=ON -DCMAKE_CXX_FLAGS=-gmlt \
  -DLLVM_OPTIMIZED_TABLEGEN=ON \
  -DLLVM_APPEND_VC_REV=OFF
```

Non-obvious gotchas discovered during setup (both matter if you re-run cmake):

- `-DLLVM_APPEND_VC_REV=OFF` is REQUIRED. The git remote URL embeds an
  `x-access-token` credential, and LLVM's `VCSRevision.h` generation aborts the
  build rather than embed a URL containing a password. Disabling VC-revision
  embedding avoids leaking the token and lets the build proceed.
- The system `clang`/`clang++` (v18) auto-selects the newest installed GCC
  toolchain directory (gcc-14). `g++-14` must be installed or linking fails with
  `cannot find -lstdc++`. It is already installed in the snapshot.

### Build / lint / test / run

- Build core tools: `ninja -C build-rel clang opt llc clang-format llvm-lit`
  (no `-j`; ninja auto-detects cores and auto-reruns cmake when CMake files
  change, so a plain `git pull` + `ninja` picks up new sources).
- Run the compiler: `build-rel/bin/clang ...`, `build-rel/bin/opt ...`,
  `build-rel/bin/llc ...`.
- Lint (formatting): `build-rel/bin/clang-format`. LLVM devs format only changed
  lines via `git clang-format`; whole-file diffs against upstream sources are
  expected and not a failure.
- Run a test subset: `build-rel/bin/llvm-lit -sv llvm/test/<path>`.
- Run the full LLVM suite: `ninja -C build-rel check-llvm` (this first builds all
  the auxiliary tools the tests depend on, e.g. `llvm-readobj`, `obj2yaml`).
  Running individual lit files may print "not found" notes for tools that
  haven't been built yet — those are harmless unless a specific test needs them.

### Notes

- `ccache` is enabled; the first clean build is slow (~15 min) but rebuilds are
  fast. Do not delete `build-rel/` unless necessary.
- The user's global rules reference an aarch64 laptop (`/local/home/madhura/...`
  helper scripts, `-mcpu=native`). Those paths/flags do not apply in this x86_64
  cloud VM; use the commands above instead.
