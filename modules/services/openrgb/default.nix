{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.hardware.openrgb;
in
{
  options.services.hardware.openrgb = {
    enable = lib.mkEnableOption "OpenRGB server, for RGB lighting control";

    package = lib.mkPackageOption pkgs "openrgb" { };

    motherboard = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "amd"
          "intel"
        ]
      );
      default = "amd";
      /*
        if config.hardware.cpu.intel.updateMicrocode then
          "intel"
        else if config.hardware.cpu.amd.updateMicrocode then
          "amd"
        else
          null;
      */
      defaultText = lib.literalMD ''
        WARNING! Currently defaults to "amd". Set to "intel"
        if you have an intel cpu. Won't be an issue after 
        finix/#103 is merged.
      '';
      /*
        if config.hardware.cpu.intel.updateMicrocode then "intel"
        else if config.hardware.cpu.amd.updateMicrocode then "amd"
        else null;
      */
      description = "CPU family of motherboard. Allows for addition motherboard i2c support.";
    };

    server.port = lib.mkOption {
      type = lib.types.port;
      default = 6742;
      description = "Set server port of openrgb.";
    };

    startupProfile = lib.mkOption {
      type = lib.types.nullOr (lib.types.str);
      default = null;
      description = "The profile file to load from \"/var/lib/OpenRGB\" at startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    boot.kernelModules = [
      "i2c-dev"
    ]
    ++ lib.optionals (cfg.motherboard == "amd") [ "i2c-piix4" ]
    ++ lib.optionals (cfg.motherboard == "intel") [ "i2c-i801" ];

    providers.services.units.openrgb = {
      description = "OpenRGB SDK Server";

      # the logger, and the device manager's settle: it scans the i2c and USB controllers once
      # at startup, so a controller whose node or permissions are still to come is not found.
      requires = config.providers.services.lib.present [
        "syslogd"
        "devices-settled"
      ];

      type.service.command = lib.escapeShellArgs (
        [
          (lib.getExe cfg.package)
          "--server"
          "--server-port"
          cfg.server.port
        ]
        ++ lib.optionals (lib.isString cfg.startupProfile) [
          "--profile"
          cfg.startupProfile
        ]
      );
    };
  };
}
