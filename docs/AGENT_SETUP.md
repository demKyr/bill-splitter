# Agent setup

This document describes how to add the tools from the lecture to your coding agent. Everything here is optional: we suggest adding a tool when a step of [README.md](../README.md) makes you want it. All the commands below should be run from the repository root, and your agent should then be restarted so that it loads the change. Note that each agent asks you to approve project configuration in its own way, e.g., Claude Code asks when it starts, Codex lists hooks in `/hooks`, and Grok requires `/hooks-trust` and a restart.

## Skills

A skill is a folder with a `SKILL.md` file, which the agent loads when the task matches it or when you call it by name. The `skills` installer copies a skill from a GitHub repository into the folder that your agent reads. The general form of the command is:

```bash
npx skills add <owner>/<repository> --skill <skill name> -a <agent> -y
```

where `<agent>` is `claude-code`, `grok`, or `universal` (for Codex and most other agents). For example, `grill-me` relies on a second skill, `grilling`, so both are installed with:

```bash
npx skills add mattpocock/skills --skill grilling grill-me -a claude-code -y   # Claude Code
npx skills add mattpocock/skills --skill grilling grill-me -a universal -y     # Codex and most other agents
npx skills add mattpocock/skills --skill grilling grill-me -a grok -y          # Grok
```

The skills shown in the lecture are listed below:

| Skill | Source | Skill names | Note |
| --- | --- | --- | --- |
| grill-me | `mattpocock/skills` | `grilling grill-me` | Loads only when you call it: `/grill-me` in Claude Code and Grok, `$grill-me` in Codex |
| Simplified Technical English | `danyuchn/asd-ste100-skill` | `asd-ste100` | |
| OpenZeppelin Skills | `OpenZeppelin/openzeppelin-skills` | `develop-secure-contracts` | |
| Cyfrin solskill | `Cyfrin/solskill` | `solidity` | Loads only when you call it by name |
| solidity-auditor | `pashov/skills` | `solidity-auditor` | |

Note that a skill comes from someone else's repository and runs with all the permissions of your agent, so you should skim each `SKILL.md` that you install.

## Hooks

A hook is a command that the agent's program runs at a fixed point, e.g., before every file edit. Unlike a rule in `AGENTS.md`, a hook cannot be skipped by the agent. Two hook scripts are provided in `scripts/hooks/`:

- **`guard-locked.mjs`** Before every file edit, it refuses any edit to a locked file. With `--after`, it runs after every edit and shell command, and reports any change, removal or move of a locked file.
- **`forge-check.sh`** After every file edit, it formats and builds the contracts, and sends any error back to the agent.

They should be registered as project-level hooks: `node scripts/hooks/guard-locked.mjs` before every file edit, `node scripts/hooks/guard-locked.mjs --after` after every file edit and every shell command, and `scripts/hooks/forge-check.sh` after every file edit. You can also ask your agent to do it. Prepared configurations can be found in `scripts/hooks/examples/`. Copy the one for your agent, and then read it:

```bash
mkdir -p .claude && cp scripts/hooks/examples/claude-settings.json .claude/settings.json   # Claude Code
mkdir -p .codex && cp scripts/hooks/examples/codex-hooks.json .codex/hooks.json             # Codex
mkdir -p .grok/hooks && cp scripts/hooks/examples/grok-hooks.json .grok/hooks/hooks.json    # Grok
```

### Locking files

The list of locked files, `LOCKED`, is at the top of `scripts/hooks/guard-locked.mjs`. It already contains the interface, the mock, the ready-made tests and the chain connection. Once you have agreed on a specification, you can lock it too, so that the agent cannot change it without you:

1. Commit the specification. Note that the `--after` check reports every uncommitted change to a locked file.
2. In `LOCKED`, remove the `//` in front of the line for that specification.

To change a locked specification later, edit it yourself and commit it.

### Checking that the hooks run

An agent may refuse to edit a locked file only because `AGENTS.md` tells it to, which shows nothing about the hook. To check the hook, ask the agent to attempt the edit:

```prompt
This is a test of the guard hook. Use your file-edit tool to add a blank
line to the end of contracts/src/interfaces/IBillSplitter.sol. Report
what happened.
```

Each run of a hook adds a line to `.hooks.log`. The hook works if the log has a new `guard-locked BLOCKED` line and `git status` shows the interface unchanged. If the edit went through, run `git checkout -- contracts/src/interfaces/`, and then check that the hooks are registered and approved.

## The Slither MCP server

An MCP server gives your agent extra tools. The Slither MCP server lets the agent query Slither, the static analyser, about the contract. It should be registered as a project-level MCP server named `slither`, with the following command:

```text
uvx --with fastmcp==2.14.3 --with slither-analyzer==0.11.5 --from git+https://github.com/trailofbits/slither-mcp@196a420a90f4b5e27d245148f46fb1ad32c40458 slither-mcp --disable-metrics
```

For example, for Claude Code, in the file `.mcp.json` in the repository root:

```json
{
  "mcpServers": {
    "slither": {
      "command": "uvx",
      "args": ["--with", "fastmcp==2.14.3", "--with", "slither-analyzer==0.11.5", "--from", "git+https://github.com/trailofbits/slither-mcp@196a420a90f4b5e27d245148f46fb1ad32c40458", "slither-mcp", "--disable-metrics"]
    }
  }
}
```

For Codex, in the file `.codex/config.toml`, and for Grok, in the file `.grok/config.toml`:

```toml
[mcp_servers.slither]
command = "uvx"
args = ["--with", "fastmcp==2.14.3", "--with", "slither-analyzer==0.11.5", "--from", "git+https://github.com/trailofbits/slither-mcp@196a420a90f4b5e27d245148f46fb1ad32c40458", "slither-mcp", "--disable-metrics"]
```

Note that the first start downloads the packages of the server, which can take a minute.

Without the MCP server, you can also run Slither yourself in `contracts/`: `uvx --from slither-analyzer==0.11.5 slither .`
