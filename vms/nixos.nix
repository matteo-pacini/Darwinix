{
  stdenvNoCC,
  nixosIso,
  lib,
  perl,
  gum,
  makeWrapper,
  qemu,
  curl,
}:
stdenvNoCC.mkDerivation {

  pname = "nixos-vm";
  version = "25.05";
  src = ../scripts;
  nativeBuildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/{bin,share}
    cp $src/nixos.sh $out/bin
    patchShebangs $out/bin/nixos.sh
    substituteInPlace $out/bin/nixos.sh \
      --replace-fail "@@prefix@@" "\"$out\""
    chmod +x $out/bin/nixos.sh
    cp ${nixosIso}/iso/*.iso $out/share/nixos.iso
    wrapProgram $out/bin/nixos.sh \
      --prefix PATH : "${
        lib.makeBinPath [
          qemu
          perl
          gum
          curl
        ]
      }"
  '';
}
