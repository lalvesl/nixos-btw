{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Lucas Alves de Lima";
      user.email = "alvesdelima.lucas45@gmail.com";
      safe.directory = [ "~/super_balas/*" ];
    };
  };
}
