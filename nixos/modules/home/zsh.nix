{ config, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
    };

    history.size = 10000;
    history.path = "${config.xdg.dataHome}/zsh/history";

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
      ];
      theme = "agnoster";
    };

    initContent = ''
      # Remove user@host from agnoster
      prompt_context() {}

      # Compress middle dirs to first letter: ~/super_balas/nixos-btw → ~/s/nixos-btw
      _compressed_dir() {
        local p="''${PWD/#$HOME/~}"
        local -a parts=("''${(@s:/:)p}")
        local result="" n=''${#parts[@]}
        for (( i=1; i<=n; i++ )); do
          if (( i == n )); then
            result+="''${parts[$i]}"
          elif [[ "''${parts[$i]}" == "~" ]]; then
            result+="~/"
          elif [[ -z "''${parts[$i]}" ]]; then
            result+="/"
          else
            result+="''${parts[$i][1]}/"
          fi
        done
        echo "$result"
      }

      prompt_dir() {
        prompt_segment blue black "$(_compressed_dir)"
      }

      _cmd_start=0
      _cmd_duration_str=""

      preexec() {
        _cmd_start=$SECONDS
      }

      precmd() {
        if (( _cmd_start > 0 )); then
          local dur=$(( SECONDS - _cmd_start ))
          local h=$(( dur / 3600 ))
          local m=$(( (dur % 3600) / 60 ))
          local s=$(( dur % 60 ))
          if (( dur < 60 )); then
            _cmd_duration_str="''${dur}s"
          elif (( dur < 3600 )); then
            _cmd_duration_str="$(printf '%dm%02ds' $m $s)"
          else
            _cmd_duration_str="$(printf '%dh%02dm%02ds' $h $m $s)"
          fi
        else
          _cmd_duration_str=""
        fi
        _cmd_start=0

        if [[ -n "$_cmd_duration_str" ]]; then
          RPROMPT="%F{208}⏱ %B$_cmd_duration_str%b%f %F{240}│%f %F{039}%B%*%b%f"
        else
          RPROMPT="%F{039}%B%*%b%f"
        fi
      }
    '';
  };
}
