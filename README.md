# simple-git-ssh

auto-creates bare repos when pushing over ssh, as an sshd `ForceCommand`.
denies non-git commands.

does not allow you to create repos outside of the git user's home directory

1. create git user with whatever home dir you want
2. compile (`nix build` or `zig build`)
3. place binary in `/usr/local/bin` (or just use the nix store path; i'm not ur mom)
4. add ForceCommand to `/etc/ssh/sshd_config`:

```nix
{ ... }: {
  services.openssh.extraConfig = ''
    Match User git
      ForceCommand /usr/local/bin/simple-git-ssh
  '';
}
```
