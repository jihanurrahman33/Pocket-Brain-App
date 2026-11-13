# Security policy

Pocket Brain stores personal notes, so we take privacy and security issues
seriously.

## Supported versions

Only the latest release on `main` receives security fixes.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately through GitHub:
[**Report a vulnerability**](https://github.com/jihanurrahman33/Pocket-Brain-App/security/advisories/new)
(Security → Advisories → *Report a vulnerability*).

Include:

- a description of the issue and its impact,
- steps to reproduce or a proof of concept,
- affected platform(s) and app version.

We aim to acknowledge reports within 7 days and to agree on a disclosure
timeline with you. Credit is given in the release notes unless you prefer
otherwise.

## In scope

- User memories, tasks or conversations leaving the device
- Unauthorised access to the local database or exports
- Unsafe handling of fetched web pages or downloaded model files
- Prompt-injection paths that cause data exfiltration or destructive actions

## Out of scope

- Behaviour of the third-party models' answers that does not affect data
  safety (please open a normal issue instead)
- Attacks that require an already-compromised, unlocked device
