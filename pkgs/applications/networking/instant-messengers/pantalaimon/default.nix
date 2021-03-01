{ lib, stdenv, buildPythonApplication, fetchFromGitHub, pythonOlder,
  attrs, aiohttp, appdirs, click, keyring, Logbook, peewee, janus,
  prompt_toolkit, matrix-nio, dbus-python, pydbus, notify2, pygobject3,
  setuptools,

  pytest, faker, pytest-aiohttp, aioresponses,

  enableDbusUi ? true
}:

buildPythonApplication rec {
  pname = "pantalaimon";
  version = "0.8.0";

  disabled = pythonOlder "3.6";

  # pypi tarball miss tests
  src = fetchFromGitHub {
    owner = "matrix-org";
    repo = pname;
    rev = version;
    sha256 = "0n86cdpw85qzlcr1ynvar0f0zbphmdz1jia9r75lmj07iw4r5hk9";
  };

  propagatedBuildInputs = [
    aiohttp
    appdirs
    attrs
    click
    janus
    keyring
    Logbook
    matrix-nio
    peewee
    prompt_toolkit
    setuptools
  ] ++ lib.optionals enableDbusUi [
      dbus-python
      notify2
      pygobject3
      pydbus
  ];

  checkInputs = [
    pytest
    faker
    pytest-aiohttp
    aioresponses
  ];

  # darwin has difficulty communicating with server, fails some integration tests
  doCheck = !stdenv.isDarwin;

  checkPhase = ''
    pytest
  '';

  meta = with lib; {
    description = "An end-to-end encryption aware Matrix reverse proxy daemon";
    homepage = "https://github.com/matrix-org/pantalaimon";
    license = licenses.asl20;
    maintainers = with maintainers; [ valodim ];
  };
}
