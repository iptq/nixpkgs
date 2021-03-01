{ lib, stdenv, autoconf, automake, fetchFromGitHub, libgcc, libjpeg_turbo
, libpng, libtool, libxml2, pkg-config, which, xorg
, libtirpc
}:
stdenv.mkDerivation rec {
  pname = "nx-libs";
  version = "3.5.99.26";
  src = fetchFromGitHub {
    owner = "ArcticaProject";
    repo = "nx-libs";
    rev = version;
    sha256 = "sha256-qVOdD85sBMxKYx1cSLAGKeODsKKAm9UPBmYzPBbBOzQ=";
  };

  nativeBuildInputs = [ autoconf automake libtool pkg-config which
    xorg.gccmakedep xorg.imake ];
  buildInputs = [ libgcc libjpeg_turbo libpng libxml2 xorg.fontutil
    xorg.libXcomposite xorg.libXdamage xorg.libXdmcp xorg.libXext xorg.libXfont2
    xorg.libXinerama xorg.libXpm xorg.libXrandr xorg.libXtst xorg.pixman
    xorg.xkbcomp xorg.xkeyboardconfig libtirpc
  ];

  env.NIX_CFLAGS_COMPILE = "-I${libtirpc.dev}/include/tirpc";
  env.NIX_LDFLAGS = "-ltirpc";

  postPatch = ''
    patchShebangs .
    find . -type f -name Makefile -exec sed -i 's|^\(SHELL:=\)/bin/bash$|\1${stdenv.shell}|g' {} \;
    ln -s libNX_X11.so.6.3.0
  '';

  installFlags = [ "PREFIX=" "DESTDIR=${placeholder "out"}" ];

  # See:
  # - https://salsa.debian.org/debian-remote-team/nx-libs/blob/bcc152100617dc59156015a36603a15db530a64f/debian/rules#L66-72
  # - https://github.com/ArcticaProject/nx-libs/issues/652
  postFixup = ''
    patchelf --remove-needed "libX11.so.6" $out/bin/nxagent
  '';

  meta = {
    description = "NX X server based on Xnest";
    homepage = "https://github.com/ArcticaProject/nx-libs";
    license = lib.licenses.gpl2;
    maintainers = with lib.maintainers; [ jD91mZM2 ];
    platforms = lib.platforms.linux;
  };
}
