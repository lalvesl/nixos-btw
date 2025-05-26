{
  programs.git = {
    enable = true;
    userName = "Lucas Alves de Lima";
    userEmail = "alvesdelima.lucas45@gmail.com";
    extraConfig = {
      safe.directory = [
        "~/super_balas/*"
      ];
    };
  };
}
