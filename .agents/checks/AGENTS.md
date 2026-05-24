## Repo-Local Checks

- **Keep `.agents/checks` canonical.** Store review, audit, and check workflows under `.agents/checks`.
- **Use direct Markdown files.** Store check workflows directly under `.agents/checks` as `.md` files, not in child folders.
- **Require frontmatter.** Check workflow files must include `name` and `description` fields.
- **Use self-review check.** For self reviews or audits, follow `.agents/checks/self-review.md`.
- **Keep checks concise.** Keep check workflow files focused on agent-facing procedure.
