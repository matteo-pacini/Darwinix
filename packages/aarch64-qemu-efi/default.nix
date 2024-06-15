{ stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "aarch64-qemu-efi";
  version = "unstable-14-06-2024";
  src = ./src;
  phases = [ "installPhase" ];
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share
    cp $src/RELEASEAARCH64_QEMU_EFI.fd $out/share/
    cp $src/RELEASEAARCH64_QEMU_VARS.fd $out/share/
    runHook postInstall
  '';
}
