{ lib, stdenv, fetchurl, automake, autoconf, subversion, fuse, apr, perl }:

stdenv.mkDerivation {
  name = "svnfs-0.4";

  src = fetchurl {
    url = "http://www.jmadden.eu/wp-content/uploads/svnfs/svnfs-0.4.tgz";
    sha256 = "1lrzjr0812lrnkkwk60bws9k1hq2iibphm0nhqyv26axdsygkfky";
  };

  buildInputs = [automake autoconf subversion fuse apr perl];

  # why is this required?
  preConfigure=''
    export LD_LIBRARY_PATH=${subversion.out}/lib
  '';

  env.NIX_CFLAGS_COMPILE="-I ${subversion.dev}/include/subversion-1";
  env.NIX_LDFLAGS="-lsvn_client-1 -lsvn_subr-1";

  meta = {
    description = "FUSE filesystem for accessing Subversion repositories";
    homepage = "http://www.jmadden.eu/index.php/svnfs/";
    license = lib.licenses.gpl2;
    maintainers = [lib.maintainers.marcweber];
    platforms = lib.platforms.linux;
  };
}
