{
  stdenvNoCC,
  aarch64-qemu-efi,
  fetchurl,
  lib,
  perl,
  gum,
  makeWrapper,
  qemu,
}:
let

  iso = fetchurl {
    url = "https://channels.nixos.org/nixos-25.05/latest-nixos-minimal-aarch64-linux.iso";
    hash = "sha256-50qA6OPt6QXUqCHDqvm6ScP3NPVFfOxyrMh75Bu/Yiw=";
  };
in
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
    cp -r ${aarch64-qemu-efi}/share/RELEASEAARCH64_QEMU_EFI.fd $out/share
    cp -r ${aarch64-qemu-efi}/share/RELEASEAARCH64_QEMU_VARS.fd $out/share
    cp ${iso} $out/share/nixos.iso
    wrapProgram $out/bin/nixos.sh \
      --prefix PATH : "${
        lib.makeBinPath [
          qemu
          perl
          gum
        ]
      }"
  '';
}
