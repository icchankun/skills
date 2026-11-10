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

Skills are written so that any agent can follow the same SKILL.md. They do not name tools, slash commands or models that only one agent has. Only when no tool-neutral wording works does a skill branch with `Claude Code なら … / Codex なら …` at that step.

Skills follow these rules:

- **Frontmatter**: only `name` and `description`, the keys in the [agentskills.io](https://agentskills.io/specification) spec that every agent reads.
- **Paths**: files are referenced from the skill's own directory, written as `<skill のディレクトリ>/scripts/...`. Another skill's files are `<skill のディレクトリ>/../<skill>/...`. Claude Code installs skills to `~/.claude/skills/` and Codex to `~/.agents/skills/`, so fixed paths break on one of them.
- **Models**: a skill says only how heavy a subagent's work is: `軽いモデル`, `標準のモデル` or `重いモデル`. The model names for each agent live in one table in the agent's global instructions (`~/.config/agents/shared.md` in the dotfiles). When a model is retired, only that table changes.
- **Subagents**: a skill that uses a subagent also says what to do when subagents are not available, because not every agent has them turned on.
- **Tools of one agent**: a skill writes what to do (`セッションの todo に積む`, `会話のリセット`), not the tool that does it. A plugin or skill that only one agent has is optional: the skill gives the steps to follow without it, and says the plugin may be used when installed.
- **Other agents and background work**: skills use Herdr.app's `hc`, which treats every agent the same. Agents are addressed by their terminal (`hc send t8 "…"`), replies arrive as the next input (`<hc from="t8 …">`), and long commands run with `hc run --bg` and `hc wait`. `SendMessage`, `ListAgents` and `run_in_background` are Claude-only and are not used.
- **Calling another skill**: skills are named without a prefix or invocation syntax (`committing-git-changes`, not `/committing-git-changes`). Each agent knows how to invoke a skill by name.
