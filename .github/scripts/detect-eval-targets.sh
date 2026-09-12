#!/usr/bin/env bash
# 変更ファイル一覧 (stdin、1 行 1 パス) から、実行すべき plugin eval の対象を JSON 配列で出力する。
#
#   出力例: [{"plugin":"git","tags":"commit ignores-unrelated-request pr-fix"},{"plugin":"dev","tags":""}]
#   - tags はスペース区切りのケース名。`claude plugin eval . --tag <tags>` にそのまま渡す
#   - tags が空文字のプラグインは suite 全体を実行する
#
# 判定ルール (プラグインごと):
#   - plugins/<p>/skills/<s>/... または plugins/<p>/evals/<s>/... の変更 → ケース <s>
#   - スキルを変更 (または既存スキルのケースを削除) したのに evals/<s> が無い場合はエラー終了 (exit 1)。
#     スキルの追加・description 変更時にケースの追加・更新を必須にするため。ただし model から起動できない
#     スキル (frontmatter が disable-model-invocation: true) は発火テストの対象外。
#     user-invocable: false はスラッシュメニューから隠すだけで model からは起動されるので対象
#   - plugins/<p>/evals/ 直下でケースでないディレクトリ (mocks/ や .replay/ などの共有アセット) の変更・削除 → suite 全体
#   - 対象になったプラグインに過剰発火テスト evals/ignores-unrelated-request が無い場合はエラー終了 (exit 1)
#   - スキルを持つプラグインの evals/ ディレクトリごと削除された場合はエラー終了 (exit 1)
#   - plugins/<p>/README.md と plugins/<p>/.claude-plugin/... の変更 → 対象外 (スキル発火に影響しない)
#   - それ以外 (hooks、agents、共有ファイルなど) の変更 → suite 全体
#   - ケースを 1 つでも選んだ場合は ignores-unrelated-request も常に含める
#
# 使い方:
#   git diff --name-only --no-renames <base> HEAD -- plugins | .github/scripts/detect-eval-targets.sh
#   (--no-renames で rename を追加 + 削除として列挙し、削除元も検査する)
#   .github/scripts/detect-eval-targets.sh --all [plugin...]   # 変更に関係なく suite 全体 (省略時は全プラグイン)
set -euo pipefail

NEGATIVE_CASE="ignores-unrelated-request"
FULL_MARKER="__FULL__"
ERROR_MARKER="__ERROR__"

emit() {
  jq -n --arg p "$1" --arg t "$2" '{plugin: $p, tags: $t}'
}

# SKILL.md 先頭の YAML frontmatter (最初の --- から次の --- まで) だけを出力する
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

# model から起動できないスキル (frontmatter に disable-model-invocation: true) なら 0 を返す。本文中の記述は見ない
skill_exempt() {
  frontmatter "$1" | grep -q -E '^disable-model-invocation:[[:space:]]*true[[:space:]]*$'
}

# 発火テストが必要なスキル (存在し、除外対象でない) なら 0 を返す
skill_needs_case() {
  local skill_md="plugins/$1/skills/$2/SKILL.md"
  [ -f "$skill_md" ] && ! skill_exempt "$skill_md"
}

# プラグインに発火テストが必要なスキルが 1 つでもあれば 0 を返す
plugin_has_testable_skill() {
  local skill_md
  for skill_md in plugins/"$1"/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_exempt "$skill_md" || return 0
  done
  return 1
}

# evals/<name> がケースディレクトリ (prompt.md または case.yaml を持つ) なら 0 を返す
is_case_dir() {
  [ -f "$1/prompt.md" ] || [ -f "$1/case.yaml" ]
}

if [ "${1:-}" = "--all" ]; then
  shift
  if [ $# -gt 0 ]; then plugins="$*"; else plugins=$(ls plugins); fi
  for plugin in $plugins; do
    if [ -d "plugins/${plugin}/evals" ]; then
      emit "$plugin" ""
    fi
  done | jq -sc 'sort_by(.plugin)'
  exit 0
fi

# ケースの frontmatter (prompt.md) または case.yaml の tags にケース名が含まれていれば 0 を返す。
# CI は --tag <ケース名> で選ぶので、tag が無いケースは選択されない
case_has_tag() {
  local dir="$1" tag="$2" fm=""
  [ -f "${dir}/prompt.md" ] && fm=$(frontmatter "${dir}/prompt.md")
  [ -f "${dir}/case.yaml" ] && fm=$(printf '%s\n%s\n' "$fm" "$(cat "${dir}/case.yaml")")
  awk -v t="$tag" '
    function clean(s) { gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", s); return s }
    /^tags:[[:space:]]*\[/ {
      s = $0; sub(/^tags:[[:space:]]*\[/, "", s); sub(/\].*$/, "", s)
      n = split(s, a, ","); for (i = 1; i <= n; i++) if (clean(a[i]) == t) found = 1
      next
    }
    /^tags:[[:space:]]*$/ { inblock = 1; next }
    inblock && /^[[:space:]]*-[[:space:]]*/ { s = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", s); if (clean(s) == t) found = 1; next }
    inblock { inblock = 0 }
    END { exit found ? 0 : 1 }
  ' <<< "$fm"
}

# evals/<name> をケースとして受理する: 行を出力し、tag が無ければエラー行も出す
accept_case() {
  local plugin="$1" name="$2"
  if case_has_tag "plugins/${plugin}/evals/${name}" "$name"; then
    echo "${plugin} ${name}"
  else
    echo "${plugin} ${ERROR_MARKER}:missing-tag:${name}"
  fi
}

# 変更パスを "<plugin> <case|__FULL__|__ERROR__:<message>>" の行に正規化する (スペースはメッセージ内で _ に置換)
entries=$(
  while IFS= read -r path; do
    [[ "$path" == plugins/*/* ]] || continue
    IFS=/ read -r _ plugin kind name _ <<< "$path"
    case "$kind" in
      skills)
        [ -n "${name:-}" ] || continue
        if is_case_dir "plugins/${plugin}/evals/${name}"; then
          accept_case "$plugin" "$name"
        elif skill_needs_case "$plugin" "$name"; then
          echo "${plugin} ${ERROR_MARKER}:missing-case:${name}"
        fi
        ;;
      evals)
        [ -n "${name:-}" ] || continue
        if [ "$name" = "results" ]; then
          continue
        elif [ ! -d "plugins/${plugin}/evals" ]; then
          # suite ごと削除された
          if plugin_has_testable_skill "$plugin"; then
            echo "${plugin} ${ERROR_MARKER}:suite-deleted"
          fi
        elif is_case_dir "plugins/${plugin}/evals/${name}"; then
          accept_case "$plugin" "$name"
        elif [ "$name" = "$NEGATIVE_CASE" ]; then
          echo "${plugin} ${ERROR_MARKER}:missing-negative"
        elif skill_needs_case "$plugin" "$name"; then
          # 既存スキルのケースが削除された
          echo "${plugin} ${ERROR_MARKER}:missing-case:${name}"
        else
          # mocks/ や .replay/ など共有アセットの変更・削除 (削除済みで判別できないものも安全側に倒す)
          echo "${plugin} ${FULL_MARKER}"
        fi
        ;;
      README.md | .claude-plugin) ;;
      *)
        # hooks / agents / 共有ファイルの変更は suite 全体 (suite が無いプラグインは対象外)。
        # `[ ] && echo` の形だと偽のときループの終了コードが 1 になり set -e で落ちるので if を使う
        if [ -d "plugins/${plugin}/evals" ]; then
          echo "${plugin} ${FULL_MARKER}"
        fi
        ;;
    esac
  done | sort -u
)

plugins=$(cut -d' ' -f1 <<< "$entries" | awk 'NF' | sort -u)

# 対象になるプラグインには過剰発火テストが必須
for plugin in $plugins; do
  if ! grep -q "^${plugin} ${ERROR_MARKER}:suite-deleted$" <<< "$entries" \
    && ! is_case_dir "plugins/${plugin}/evals/${NEGATIVE_CASE}"; then
    entries=$(printf '%s\n%s\n' "$entries" "${plugin} ${ERROR_MARKER}:missing-negative")
  fi
done

errors=$(grep " ${ERROR_MARKER}:" <<< "$entries" | sort -u || true)
if [ -n "$errors" ]; then
  while read -r plugin marker; do
    kind="${marker#"${ERROR_MARKER}":}"
    case "$kind" in
      missing-case:*)
        skill="${kind#missing-case:}"
        echo "::error::plugins/${plugin}/skills/${skill} に対応する発火テスト plugins/${plugin}/evals/${skill}/ がありません。ケースを追加してください (model から起動できないスキルなら frontmatter に disable-model-invocation: true を設定)" >&2
        ;;
      missing-negative)
        echo "::error::plugins/${plugin}/evals/${NEGATIVE_CASE}/ がありません。過剰発火を確認する否定ケースは各 suite に必須です" >&2
        ;;
      missing-tag:*)
        name="${kind#missing-tag:}"
        echo "::error::plugins/${plugin}/evals/${name}/ の tags にケース名 '${name}' がありません。CI は --tag ${name} でこのケースを選ぶため、prompt.md の frontmatter (または case.yaml) の tags に追加してください" >&2
        ;;
      suite-deleted)
        echo "::error::plugins/${plugin}/evals/ が削除されましたが、発火テストが必要なスキルが残っています" >&2
        ;;
    esac
  done <<< "$errors"
  exit 1
fi

for plugin in $plugins; do
  if grep -q "^${plugin} ${FULL_MARKER}$" <<< "$entries"; then
    emit "$plugin" ""
    continue
  fi
  tags=$(awk -v p="$plugin" '$1 == p { print $2 }' <<< "$entries")
  tags=$(printf '%s\n%s\n' "$tags" "$NEGATIVE_CASE" | sort -u)
  emit "$plugin" "$(tr '\n' ' ' <<< "$tags" | sed 's/^ *//; s/ *$//')"
done | jq -sc 'sort_by(.plugin)'
