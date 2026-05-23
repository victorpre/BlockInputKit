## Repo-Local Agent Workflows

- **Separate workflow types.** Store capability workflows under `.agents/skills` and review, audit, or check workflows under `.agents/checks`.
- **Keep workflows concise.** Put only agent-facing workflow details in `SKILL.md`; keep human-facing docs in `README.md`.
- **Use release skill.** For release bumps or release dry runs, follow `.agents/skills/create-release/SKILL.md`.
- **Use self-review check.** For self reviews or audits, follow `.agents/checks/self-review/SKILL.md`.
- **Use block-support skill.** For adding or extending block types, follow `.agents/skills/add-block-support/SKILL.md`.
- **Protect secrets.** Never commit signing keys, tokens, passwords, or base64 secret values.
- **Validate changes.** Run the workflow validator after editing `.agents/skills/*/SKILL.md` or `.agents/checks/*/SKILL.md` when one is available.
