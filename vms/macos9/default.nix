{
  stdenvNoCC,
  lib,
  perl,
  gum,
  makeWrapper,
  mkQemu,
}:
let
  qemu = mkQemu { hostCpuTarget = "ppc-softmmu"; };
in
stdenvNoCC.mkDerivation {

  pname = "macos9-vm";
  version = "9.2.2";
  src = ../../scripts;
  nativeBuildInputs = [ makeWrapper ];
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/{bin,share}
    cp $src/macos9.sh $out/bin
    patchShebangs $out/bin/macos9.sh
    chmod +x $out/bin/macos9.sh
    wrapProgram $out/bin/macos9.sh \
      --prefix PATH : "${
        lib.makeBinPath [
          qemu
          perl
          gum
        ]
      }"
  '';
}
