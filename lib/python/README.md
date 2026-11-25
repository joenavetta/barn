# lib/python

Python code behind the commands in [`bin/`](../../bin/). It's a uv project:
each `bin/` command is a thin shell wrapper that runs
`uv run --project lib/python <entry point>`, so the virtualenv and
dependencies are created on first use. Commit `uv.lock`.

| Package | Command | What it does |
|---------|---------|--------------|
| `barn.cf` | `barn-cf` | Roll Cloudflare account API tokens and save the new value to 1Password ([docs/barn-cf.md](../../docs/barn-cf.md)) |
| `barn.op` | `barn-op` | 1Password items, via the [1Password Python SDK](https://github.com/1Password/onepassword-sdk-python), with a read-only service account token or desktop app auth ([docs/1password-service-account.md](../../docs/1password-service-account.md)) |

To add a command: add a package under `src/barn/`, an entry under
`[project.scripts]` in `pyproject.toml`, and a wrapper in `bin/` (copy
`bin/barn-op` and change the last line).
