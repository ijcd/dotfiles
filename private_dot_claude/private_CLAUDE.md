- In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

## PR Comments

<pr-comment-rule>
When I say to add acomment to a PR with a TODO on it, use
'checkbox' markdown format to add the TODO. For instance:

<example>
- [ ] A description of the todo goes here
</example>
</pr-comment-rule>
- When tagging Claude in the GitHub issues, use '@claude'

## Changesets

To add a changeset, write a new file to the `.changeset` directory.

The file should be named `0000-your-change.md`. Decide yourself whether to
make it a patch, minor, or major change.

The format of the file should be:

```md
---
"evalite": patch
---

Description of the change.
```

The description of the change should be user-facing, describing which features
were added or bugs were fixed.

## GitHub

- Your primary method for interacting with GitHub should be the GitHub CLI.

## Git

- When creating branches, prefix them with ijcd/ to indicate they come from me.
- Do not add "Generated with Claude Code" or Co-Authored-By lines to commit messages. 

## Plans

- Think hardest.

- Consider how we will implement only the functionality we need right now.

- Write a short overview of what you are about to do.

- Identify files that need to be changed.

- Write function names and 1-3 sentences about what they do.

- Write test names and 5-10 words about behavior to cover.

- At the end of each plan, give me a list of unresolved questions to answer,
if any. Make the questions extremely concise. Sacrifice grammar for the sake
of concision.
