addCMakeParams() {
    addToSearchPath CMAKE_PREFIX_PATH $1
}

fixCmakeFiles() {
    # Replace occurences of /usr and /opt by /var/empty.
    echo "fixing cmake files..."
    find "$1" \( -type f -name "*.cmake" -o -name "*.cmake.in" -o -name CMakeLists.txt \) -print |
        while read fn; do
            sed -e 's^/usr\([ /]\|$\)^/var/empty\1^g' -e 's^/opt\([ /]\|$\)^/var/empty\1^g' < "$fn" > "$fn.tmp"
            mv "$fn.tmp" "$fn"
        done
}

cmakeConfigurePhase() {
    runHook preConfigure

    export CTEST_OUTPUT_ON_FAILURE=1
    if [ -n "${enableParallelChecking-1}" ]; then
        export CTEST_PARALLEL_LEVEL=$NIX_BUILD_CORES
    fi

    if [ -z "${dontFixCmake-}" ]; then
        fixCmakeFiles .
    fi

    if [ -z "${dontUseCmakeBuildDir-}" ]; then
        mkdir -p build
        cd build
        cmakeDir=${cmakeDir:-..}
    fi

    if [ -z "${dontAddPrefix-}" ]; then
        cmakeFlags=("-DCMAKE_INSTALL_PREFIX=$prefix" ${cmakeFlags[@]+"${cmakeFlags[@]}"})
    fi

    # We should set the proper `CMAKE_SYSTEM_NAME`.
    # http://www.cmake.org/Wiki/CMake_Cross_Compiling
    #
    # Unfortunately cmake seems to expect absolute paths for ar, ranlib, and
    # strip. Otherwise they are taken to be relative to the source root of the
    # package being built.
    cmakeFlags=(
        "-DCMAKE_CXX_COMPILER=$CXX"
        "-DCMAKE_C_COMPILER=$CC"
        "-DCMAKE_AR=$(command -v $AR)"
        "-DCMAKE_RANLIB=$(command -v $RANLIB)"
        "-DCMAKE_STRIP=$(command -v $STRIP)"

        # on macOS we want to prefer Unix-style headers to Frameworks
        # because we usually do not package the framework
        "-DCMAKE_FIND_FRAMEWORK=LAST"

        # on macOS i686 was only relevant for 10.5 or earlier.
        "-DCMAKE_OSX_ARCHITECTURES=x86_64"

        # we never want to use the global macOS SDK
        "-DCMAKE_OSX_SYSROOT="

        # correctly detect our clang compiler
        "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"

        # This installs shared libraries with a fully-specified install
        # name. By default, cmake installs shared libraries with just the
        # basename as the install name, which means that, on Darwin, they
        # can only be found by an executable at runtime if the shared
        # libraries are in a system path or in the same directory as the
        # executable. This flag makes the shared library accessible from its
        # nix/store directory.
        "-DCMAKE_INSTALL_NAME_DIR=${!outputLib}/lib"

        # This ensures correct paths with multiple output derivations
        # It requires the project to use variables from GNUInstallDirs module
        # https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html
        "-DCMAKE_INSTALL_BINDIR=${!outputBin}/bin"
        "-DCMAKE_INSTALL_SBINDIR=${!outputBin}/sbin"
        "-DCMAKE_INSTALL_INCLUDEDIR=${!outputInclude}/include"
        "-DCMAKE_INSTALL_OLDINCLUDEDIR=${!outputInclude}/include"
        "-DCMAKE_INSTALL_MANDIR=${!outputMan}/share/man"
        "-DCMAKE_INSTALL_INFODIR=${!outputInfo}/share/info"
        "-DCMAKE_INSTALL_DOCDIR=${!outputDoc}/share/doc/${shareDocName}"
        "-DCMAKE_INSTALL_LIBDIR=${!outputLib}/lib"
        "-DCMAKE_INSTALL_LIBEXECDIR=${!outputLib}/libexec"
        "-DCMAKE_INSTALL_LOCALEDIR=${!outputLib}/share/locale"

        # Avoid cmake resetting the rpath of binaries, on make install
        # And build always Release, to ensure optimisation flags
        "-DCMAKE_BUILD_TYPE=${cmakeBuildType:-Release}" "-DCMAKE_SKIP_BUILD_RPATH=ON"

        # Disable user package registry to avoid potential side effects
        # and unecessary attempts to access non-existent home folder
        # https://cmake.org/cmake/help/latest/manual/cmake-packages.7.html#disabling-the-package-registry
        "-DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON"
        "-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF"
        "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF"

        ${cmakeFlags[@]+"${cmakeFlags[@]}"}
        ${cmakeFlagsArray[@]+"${cmakeFlagsArray[@]}"}
    )

    # The docdir flag needs to include PROJECT_NAME as per GNU guidelines,
    # try to extract it from CMakeLists.txt.
    if [[ -z "$shareDocName" ]]; then
        local cmakeLists="${cmakeDir}/CMakeLists.txt"
        if [[ -f "$cmakeLists" ]]; then
            local shareDocName="$(grep --only-matching --perl-regexp --ignore-case '\bproject\s*\(\s*"?\K([^[:space:]")]+)' < "$cmakeLists" | head -n1)"
        fi
        # The argument sometimes contains garbage or variable interpolation.
        # When that is the case, let’s fall back to the derivation name.
        if [[ -z "$shareDocName" ]] || echo "$shareDocName" | grep -q '[^a-zA-Z0-9_+-]'; then
            if [[ -n "${pname-}" ]]; then
                shareDocName="$pname"
            else
                shareDocName="$(echo "$name" | sed 's/-[^a-zA-Z].*//')"
            fi
        fi
    fi

    # Don’t build tests when doCheck = false
    if [ -z "${doCheck-}" ]; then
        cmakeFlags=("-DBUILD_TESTING=OFF" "${cmakeFlags[@]}")
    fi
    if [ "${buildPhase-}" = ninjaBuildPhase ]; then
        cmakeFlags=("-GNinja" "${cmakeFlags[@]}")
    fi

    echo "cmake flags: ${cmakeFlags[@]}"

    cmake ${cmakeDir:-.} "${cmakeFlags[@]}"

    if ! [[ -v enableParallelBuilding ]]; then
        enableParallelBuilding=1
        echo "cmake: enabled parallel building"
    fi

    runHook postConfigure
}

if [ -z "${dontUseCmakeConfigure-}" -a -z "${configurePhase-}" ]; then
    setOutputFlags=
    configurePhase=cmakeConfigurePhase
fi

addEnvHooks "$targetOffset" addCMakeParams

makeCmakeFindLibs(){
  isystem_seen=
  iframework_seen=
  for flag in ${NIX_CFLAGS_COMPILE-} ${NIX_LDFLAGS-}; do
    if test -n "$isystem_seen" && test -d "$flag"; then
      isystem_seen=
      export CMAKE_INCLUDE_PATH="${CMAKE_INCLUDE_PATH-}${CMAKE_INCLUDE_PATH:+:}${flag}"
    elif test -n "$iframework_seen" && test -d "$flag"; then
      iframework_seen=
      export CMAKE_FRAMEWORK_PATH="${CMAKE_FRAMEWORK_PATH-}${CMAKE_FRAMEWORK_PATH:+:}${flag}"
    else
      isystem_seen=
      iframework_seen=
      case $flag in
        -I*)
          export CMAKE_INCLUDE_PATH="${CMAKE_INCLUDE_PATH-}${CMAKE_INCLUDE_PATH:+:}${flag:2}"
          ;;
        -L*)
          export CMAKE_LIBRARY_PATH="${CMAKE_LIBRARY_PATH-}${CMAKE_LIBRARY_PATH:+:}${flag:2}"
          ;;
        -F*)
          export CMAKE_FRAMEWORK_PATH="${CMAKE_FRAMEWORK_PATH-}${CMAKE_FRAMEWORK_PATH:+:}${flag:2}"
          ;;
        -isystem)
          isystem_seen=1
          ;;
        -iframework)
          iframework_seen=1
          ;;
      esac
    fi
  done
}

# not using setupHook, because it could be a setupHook adding additional
# include flags to NIX_CFLAGS_COMPILE
postHooks+=(makeCmakeFindLibs)
