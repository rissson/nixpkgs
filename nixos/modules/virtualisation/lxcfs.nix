# LXC Configuration

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.lxc.lxcfs;
in {
  meta.maintainers = [ maintainers.mic92 ];

  ###### interface
  options = {
    virtualisation.lxc.lxcfs = {
      enable = mkOption {
       type = types.bool;
       default = false;
       description = ''
         This enables LXCFS, a FUSE filesystem for LXC.
         To use lxcfs in include the following configuration in your
         container configuration:
         <code>
           virtualisation.lxc.defaultConfig = "lxc.include = ''${pkgs.lxcfs}/share/lxc/config/common.conf.d/00-lxcfs.conf";
         </code>
       '';
      };
    };

    security.pam =
      let
        pamModuleCfg = config.security.pam.modules.lxcfs;
        moduleOptions = global: {
          enable = mkOption {
            type = types.bool;
            default = if global then cfg.enable else pamModuleCfg.enable;
            description = ''
              Whether to authenticate against lxcfs using PAM
            '';
          };
        };
      in
      {
        services = mkOption {
          type = with types; attrsOf (submodule
            ({ config, ... }: {
              options = {
                modules.lxcfs = moduleOptions false;
              };

              config = mkIf config.modules.lxcfs.enable {
                session.lxcfs = {
                  control = "optional";
                  path = "${pkgs.lxc}/lib/security/pam_cgfs.so";
                  args = [ "-c" "all" ];
                  order = 19000;
                };
              };
            })
          );
        };

        modules.lxcfs = moduleOptions true;
      };
  };

  ###### implementation
  config = mkIf cfg.enable {
    systemd.services.lxcfs = {
      description = "FUSE filesystem for LXC";
      wantedBy = [ "multi-user.target" ];
      before = [ "lxc.service" ];
      restartIfChanged = false;
      serviceConfig = {
        ExecStartPre="${pkgs.coreutils}/bin/mkdir -p /var/lib/lxcfs";
        ExecStart="${pkgs.lxcfs}/bin/lxcfs /var/lib/lxcfs";
        ExecStopPost="-${pkgs.fuse}/bin/fusermount -u /var/lib/lxcfs";
        KillMode="process";
        Restart="on-failure";
      };
    };
  };
}
