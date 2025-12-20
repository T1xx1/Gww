# Gww (Git Worktree Wrapper)

**Gww** is a PowerShell shell tool that wraps Git commands to provide an improved UX around Git worktrees, making multi-branch and multi-directory workflows way seamless.

This project was heavily inspired by the [git-worktree-runner by CodeRabbit](https://github.com/coderabbitai/git-worktree-runner).

![](./assets/banner.png)

## Features

- Better UX working with Git worktrees and worktreed branches
- Configs setup and postCreate script
- Configurable

## Requirements
- [PowerShell](https://learn.microsoft.com/it-it/powershell) 7+
- [Git](https://git-scm.com) 2.5+

## Installation (Windows)

```powershell
<# 1. Clone this repository #>
git clone https://github.com/t1xx1/gww.git

<# 2. Add Gww to $PATH #>
[System.Environment]::SetEnvironmentVariable("Path", ($env:Path + ";C:\Path\To\Gww"), "User")

<# 3. Open a new PowerShell window #>
wt nt -p "PowerShell"
exit
```

## Usage

```powershell
> gww <command> [<args>]
```

## Commands

Run `gww h` to log all the commands in your terminal or view the [Commands file](./src/cmds.txt).

## Config

The `gww.config.json` configures some aspects of Gww commands.

> Gww supports the config directory as `.config/gww.json` ([.config directory proposal](https://github.com/pi0/config-dir))

Run `gww config h` to log all supported config properties or view the [Config file](./src/config.txt).

<br />

### Happy parallel hacking!