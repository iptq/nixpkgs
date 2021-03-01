{lib, stdenv, fetchurl, gettext, jdk8, libmatthew_java}:

let jdk = jdk8; in
stdenv.mkDerivation {
  name = "dbus-java-2.7";
  src = fetchurl {
    url = "https://dbus.freedesktop.org/releases/dbus-java/dbus-java-2.7.tar.gz";
    sha256 = "0cyaxd8x6sxmi6pklkkx45j311a6w51fxl4jc5j3inc4cailwh5y";
  };

  env = {
    JAVA_HOME = toString jdk;
    JAVA = "${jdk}/bin/java";
    PREFIX = placeholder "out";
    JAVAUNIXLIBDIR = "${libmatthew_java}/lib/jni";
    JAVAUNIXJARDIR = "${libmatthew_java}/share/java";
  };

  buildInputs = [ gettext jdk ];

  # I'm too lazy to build the documentation
  preBuild = ''
    sed -i -e "s|all: bin doc man|all: bin|" \
           -e "s|install: install-bin install-man install-doc|install: install-bin|" Makefile
  '';

  meta = with lib; {
    platforms = platforms.linux;
    maintainers = [ maintainers.sander ];
    license = licenses.afl21;
  };
}
