{
  stdenvNoCC,
  nixosIso ? null,
  lib,
  perl,
  gum,
  makeWrapper,
  qemu,
  curl,
  pv,
  jq,
  aria2,
}:
stdenvNoCC.mkDerivation {

  pname = "linux-vm";
  version = "1.0.0";
  src = ../scripts;
  isoSourcesJson = ../iso-sources.json;
  nativeBuildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/{bin,share}
    cp $src/linux.sh $out/bin
    patchShebangs $out/bin/linux.sh
    substituteInPlace $out/bin/linux.sh \
      --replace-fail "@@prefix@@" "\"$out\""
    chmod +x $out/bin/linux.sh

    # Copy ISO sources configuration
    cp $isoSourcesJson $out/share/iso-sources.json

    # Include the pre-built NixOS ISO if provided
    ${lib.optionalString (nixosIso != null) ''
      cp ${nixosIso}/iso/*.iso $out/share/nixos.iso
    ''}

    wrapProgram $out/bin/linux.sh \
      --prefix PATH : "${
        lib.makeBinPath [
          qemu
          perl
          gum
          curl
          pv
          jq
          aria2
        ]
      }"
  '';
}
