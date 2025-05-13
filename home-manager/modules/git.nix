{
  programs.git = {
    enable = true;
    userName = "Lucas Alves de Lima";
    userEmail = "lucaslima@weg.net";
    extraConfig = {
      credential = {
        helper = "manager";
        "https://gitlab.weg.net".username = "lucaslima";
        credentialStore = "cache";
      };
    };
  };
}
