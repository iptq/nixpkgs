{ lib, stdenv, fetchFromGitHub, rustPlatform, pkg-config, openssl }:

rustPlatform.buildRustPackage rec {
  pname = "mdbook-linkcheck";
  version = "0.7.5";

  src = fetchFromGitHub {
    owner = "Michael-F-Bryan";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-KOf/rNYXzV1TnAlTdneiyDcK1WJrpIzX90JlmKBlb08=";
  };

  patches = [ ./0001-dont-vendor.patch ];
  cargoPatches = [ ./0001-dont-vendor-lock.patch ];

  cargoSha256 = "sha256-tnw+nxGg4drp0n7mFtCjSHdWhWiKDdYyY3RgZc3hOMk=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  # Can't run tests, since they fetch from the web.
  doCheck = false;

  meta = with lib; {
    description = "A backend for mdbook which will check your links for you";
    homepage = "https://github.com/Michael-F-Bryan/mdbook-linkcheck";
    license = [ licenses.mit ];
    maintainers = with maintainers; [ mzhang ];
  };
}
