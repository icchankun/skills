# icchankun/skills

A plugin bundling personal git / GitHub workflow skills, maintained by [@icchankun](https://github.com/icchankun) and distributed via [APM](https://github.com/microsoft/apm) (Agent Package Manager). Each skill under `skills/` follows the [agentskills.io](https://agentskills.io/specification) open standard.

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
