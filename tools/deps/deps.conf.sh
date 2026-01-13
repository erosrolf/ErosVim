# tools/deps/deps.conf.sh
# Списки команд, которые должны быть доступны в PATH.

# База: почти всегда нужна
DEPS_COMMON=(
  git
  curl
  tar
)

# Часто нужны для плагинов/поиска
DEPS_SEARCH=(
  rg
  fd
)

# Языковые рантаймы/провайдеры (включай только если реально надо)
DEPS_LANG=(
  node
  python3
)

# LSP servers
DEPS_LSP=(
  vscode-json-language-server
)

# OS-specific
DEPS_MACOS=(
  # pbcopy/pbpaste обычно уже есть, но можно проверять по желанию
)

DEPS_LINUX=(
  # xclip/xsel — если нужен clipboard в X11 (опционально)
  # xclip
)

# Сборка итогового набора (можешь редактировать, что включать)
DEPS_ENABLED_GROUPS=(
  DEPS_COMMON
  DEPS_SEARCH
  DEPS_LANG
  DEPS_LSP
  # DEPS_LINUX / DEPS_MACOS подхватятся автоматически по OS
)

