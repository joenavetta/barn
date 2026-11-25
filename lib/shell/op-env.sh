# Sets up 1Password credentials in your shell for Terraform's onepassword
# provider and the op CLI. Source it from ~/.zshrc (or ~/.bashrc):
#
#   . "$HOME/src/github.com/joenavetta/barn/lib/shell/op-env.sh"
#
# The provider refuses to start when both OP_SERVICE_ACCOUNT_TOKEN and
# OP_ACCOUNT are set, so this exports exactly one:
#   - OP_SERVICE_ACCOUNT_TOKEN, the read-only service account token from the
#     macOS Keychain (generic password, service "barn.op.service-account"), or
#   - OP_ACCOUNT, for the desktop app (Touch ID), when there's no token.
# See docs/1password-service-account.md. Plain sh syntax, so zsh and bash both work.

if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && command -v security >/dev/null 2>&1; then
  OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -s "${BARN_OP_KEYCHAIN_SERVICE:-barn.op.service-account}" -w 2>/dev/null) || OP_SERVICE_ACCOUNT_TOKEN=
fi
if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  export OP_SERVICE_ACCOUNT_TOKEN
  unset OP_ACCOUNT
else
  unset OP_SERVICE_ACCOUNT_TOKEN
  # Account ID (not the name the Python SDK uses), as Terraform and op expect.
  export OP_ACCOUNT="${OP_ACCOUNT:-PW5WK2EEO5HM5L4UG46ABS37TA}"
fi
