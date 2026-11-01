# icchankun/skills

A plugin bundling personal development workflow skills, maintained by [@icchankun](https://github.com/icchankun) and distributed via [APM](https://github.com/microsoft/apm) (Agent Package Manager). Each skill under `skills/` follows the [agentskills.io](https://agentskills.io/specification) open standard.

## Install

Add to a project's (or global) `apm.yml`:

```yaml
dependencies:
  apm:
    - git: icchankun/skills
```

Then:

```sh
apm install -g
```

Pin to a tag:

```sh
apm install -g icchankun/skills#v0.1.0
```

## Claude Code and Codex

Skills work in both Claude Code and Codex unless their description starts with `Claude Code 専用`. Those rely on Claude-only features (`SendMessage`, Claude Code hooks, Claude Code plugins) and stay as they are.

Tool-neutral skills follow these rules:

- **Paths**: files are referenced from the skill's own directory, written as `<skill のディレクトリ>/scripts/...`. Another skill's files are `<skill のディレクトリ>/../<skill>/...`. Claude Code installs skills to `~/.claude/skills/` and Codex to `~/.agents/skills/`, so fixed paths break on one of them.
- **Models**: a skill says how heavy a subagent's work is, then names the model for both tools, for example `いちばん軽いモデル（Claude Code は haiku、Codex は gpt-6-luna）`. Only Claude Code and Codex are used, so both are named rather than left to the tool. When a model is retired, search the skills for its name and replace it.

  | Claude Code | Codex |
  |---|---|
  | opus | gpt-6.1-sol |
  | sonnet | gpt-6-luna |
  | haiku | gpt-6-luna |

  Codex's frontier model (gpt-6-astra) has no counterpart here: its usage allowance is too small for work that runs on every task.

  A skill that uses a subagent also says what to do when subagents are not available, because Codex runs them only with `multi_agent` turned on.
- **Calling another skill**: skills are named without a prefix (`committing-git-changes`). Claude Code invokes them as `/name`, Codex as `$name`.
