#!/usr/bin/env bash
# Copia SWF e imagens de ui/vietnam para ui/pt-BR (o Git não versiona essa duplicata).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/Source Flash/FlashSV1/ui/vietnam"
dst="$root/Source Flash/FlashSV1/ui/pt-BR"
if [[ ! -d "$src/swf" ]]; then
  echo "Pasta origem nao encontrada: $src/swf" >&2
  exit 1
fi
mkdir -p "$dst"
for name in swf img; do
  if [[ -e "$dst/$name" ]]; then
    echo "Ja existe: $dst/$name"
    continue
  fi
  echo "Copiando $name ..."
  cp -a "$src/$name" "$dst/$name"
done
echo "Pronto. language.txt e xml/ ja vem do Git em ui/pt-BR/."
