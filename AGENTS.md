# AGENTS.md

## Cursor Cloud specific instructions

This repository is the **LLVM monorepo** (a personal fork of `llvm/llvm-project`,
including `libsycl`). It is a large C++/CMake codebase; the "application" is the
LLVM/Clang compiler toolchain (`clang`, `lld`, `llc`, `opt`, `llvm-mc`, ...).

### Toolchain already present (installed during environment setup)
- `clang-18` / `clang++-18`, `g++`/GCC 13, `cmake` 3.28, `python3` 3.12.
- `ninja`, `ccache`, `lld` (installed via apt during setup).

### Non-obvious gotcha: which GCC clang uses for libstdc++
The VM has GCC 13 **and** GCC 14, but only GCC 13 ships the `libstdc++` dev files
(`libstdc++.so` + C++ headers). `clang` picks the newest GCC (14) by default and
then fails to find `libstdc++` when compiling/linking **C++** code
(`cannot find -lstdc++` or `'iostream' file not found`). `libstdc++-14-dev` cannot
be installed here because the Ubuntu package pool returns 503 on this network.

Workaround — point clang at GCC 13 for C++:
```
--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13
```
This applies to **both** the system `clang-18` and the freshly built `clang` when
compiling C++ (add `-Wno-gcc-install-dir-libstdcxx` to silence the advisory
warning). Plain C programs are unaffected.

### Configuring the build (reference)
Build out-of-tree from the `llvm/` subdirectory into `/workspace/build`
(`/build*` is gitignored). The configuration used for the dev build:
```
cmake -S llvm -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_TARGETS_TO_BUILD=X86 \
  -DCMAKE_C_COMPILER=clang-18 -DCMAKE_CXX_COMPILER=clang++-18 \
  -DCMAKE_C_FLAGS="--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13" \
  -DCMAKE_CXX_FLAGS="--gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13" \
  -DLLVM_ENABLE_LLD=ON \
  -DLLVM_CCACHE_BUILD=ON \
  -DLLVM_APPEND_VC_REV=OFF
```
Two flags matter in this environment:
- `LLVM_APPEND_VC_REV=OFF`: the cloud clone URL embeds an access token, so
  `VCSRevision.h` generation otherwise aborts ("git remote URL has an embedded
  password"). Turning it off avoids the failure.
- Do **not** enable `LLVM_OPTIMIZED_TABLEGEN`: it spawns a `NATIVE/` sub-build
  that re-runs CMake **without** the `--gcc-install-dir` flags and fails on
  `-lstdc++`.

### Build / run / test
- Build (use ninja, no `-j`; it auto-detects cores; ccache warms rebuilds):
  `ninja -C build clang lld llc opt llvm-mc`
- Run the compiler, e.g.: `build/bin/clang <src.c>` (for C++ add the
  `--gcc-install-dir=...13` flag above).
- Tests use LLVM `lit`. Prefer the generated `check-*` ninja targets, which
  auto-build the tool dependencies (running `build/bin/llvm-lit` directly fails
  until tools like `llvm-config`, `FileCheck`, `verify-uselistorder`, etc. are
  built). Example targeted suite: `ninja -C build check-llvm-mc-x86`.
  The full suite is `ninja -C build check-llvm` (very large).
- Lint/format: LLVM uses `clang-format` (`.clang-format`) and `.clang-tidy`;
  format only your diff, e.g. `git clang-format` / `clang-format -i <files>`.

### Network note
apt access to `archive.ubuntu.com` / `security.ubuntu.com` is intermittent
(frequent 503s from the egress proxy). Avoid depending on new apt installs at
runtime; the build tools above are already installed.
