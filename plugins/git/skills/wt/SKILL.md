---
name: wt
description: このスキルは、「worktree を構築」「worktree 化して」「wt で変換」「ディレクトリを worktree 構成にして」「bare リポジトリ + worktree にして」「worktree セットアップ」「worktree 構成に変換」などのリクエスト、または既存の Git リポジトリを bare + worktree の並列構成に変換する際に使用する。引数に指定されたディレクトリを bare.git + ブランチディレクトリの並列構成に変換する。
argument-hint: <directory>
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# Worktree 構成への変換ワークフロー

引数に指定されたディレクトリ内の Git リポジトリを、bare リポジトリ + worktree の並列構成に変換する。

## 重要な原則

1. **変換対象は既存の Git リポジトリのみ** - `.git` ディレクトリが存在するディレクトリのみ変換可能
2. **現在のブランチのみ worktree として作成する** - 他のブランチは変換後に手動で追加
3. **元のファイルは全てブランチディレクトリに移動する** - 未コミットの変更も引き継がれる
4. **変換は一括実行する** - 途中失敗時の中途半端な状態を防ぐ
5. **`bare.git/config` にカスタム設定を追加する** - `[wt]` セクションを付与

## 変換後の構成

```
<directory>/
├── bare.git/       # bare リポジトリ
└── <branch>/       # 現在のブランチの worktree (元のファイルを含む)
```

例: `hoge/` が `main` ブランチの場合:

```
hoge/
├── bare.git/
└── main/
```

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "対象ディレクトリの検証", description: "Git リポジトリであること、未変換であることを確認", activeForm: "ディレクトリを検証中" })
TaskCreate({ subject: "現在のブランチ名を取得", description: "branch --show-current でブランチ名を取得", activeForm: "ブランチ名を取得中" })
TaskCreate({ subject: "未コミットの変更を確認", description: "変更がある場合はユーザーに警告", activeForm: "未コミット変更を確認中" })
TaskCreate({ subject: "worktree 構成への変換", description: "bare.git 作成、ファイル退避、worktree 追加、ファイル復元を一括実行", activeForm: "worktree 構成に変換中" })
TaskCreate({ subject: "結果の確認", description: "worktree list とディレクトリ構成を確認", activeForm: "変換結果を確認中" })
TaskCreate({ subject: "完了報告", description: "変換結果を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. 対象ディレクトリの検証

```bash
# Git リポジトリであることを確認
git -C "$ARGUMENTS" rev-parse --git-dir

# 既に bare リポジトリでないことを確認
git -C "$ARGUMENTS" rev-parse --is-bare-repository

# .git がディレクトリ (通常リポジトリ) であることを確認
# .git がファイルの場合は既に worktree の可能性がある
test -d "$ARGUMENTS/.git"
```

- Git リポジトリでない場合 → エラーを報告して終了
- 既に bare リポジトリの場合 → 「既に bare リポジトリです」と報告して終了
- `.git` がファイルの場合 → 「既に worktree 構成の可能性があります」と報告して終了

### 2. 現在のブランチ名を取得

```bash
BRANCH=$(git -C "$ARGUMENTS" branch --show-current)
```

detached HEAD (空文字列が返る) の場合はエラーを報告して終了する。

### 3. 未コミットの変更を確認

```bash
git -C "$ARGUMENTS" status --porcelain
```

未コミットの変更がある場合、ユーザーに警告する。変更は worktree ディレクトリに引き継がれる。

### 4. worktree 構成への変換

以下の手順を **1 つの Bash コマンド** (`set -euo pipefail` 付き) で実行する。途中で失敗した場合に中途半端な状態にならないよう、一括で実行すること。

`$ARGUMENTS` は実際の引数値に置換して使用する。

```bash
set -euo pipefail

DIR="<実際のディレクトリパス>"
BRANCH=$(git -C "$DIR" branch --show-current)

# 事前検証
if [ "$(git -C "$DIR" rev-parse --is-bare-repository 2>/dev/null)" = "true" ]; then
  echo "Error: 既に bare リポジトリです" >&2
  exit 1
fi
if [ ! -d "$DIR/.git" ]; then
  echo "Error: .git ディレクトリが見つかりません (既に worktree 構成の可能性があります)" >&2
  exit 1
fi

# 変換前の remote 設定を記録
REMOTE_BEFORE=$(git -C "$DIR" remote -v)

# .git を bare.git に変換
mv "$DIR/.git" "$DIR/bare.git"
git -C "$DIR/bare.git" config core.bare true

# bare.git/config にカスタム設定を追加
cat >> "$DIR/bare.git/config" << 'EOF'
[wt]
	copyignored = true
	basedir = ./
	nocopy = .idea
EOF

# 元のファイルを一時ディレクトリに退避 (bare.git 以外)
TMPDIR=$(mktemp -d)
for item in "$DIR"/* "$DIR"/.*; do
  basename="$(basename "$item")"
  [ "$basename" = "." ] || [ "$basename" = ".." ] || [ "$basename" = "bare.git" ] && continue
  mv "$item" "$TMPDIR/"
done

# worktree を追加
git -C "$DIR/bare.git" worktree add "../$BRANCH" "$BRANCH"

# 退避したファイルを worktree にコピー (checkout 済みファイルを上書き)
cp -a "$TMPDIR/." "$DIR/$BRANCH/"

# 一時ディレクトリを削除
rm -rf "$TMPDIR"

# remote 設定が変換前と同一であることを検証
REMOTE_AFTER=$(git -C "$DIR/bare.git" remote -v)
if [ "$REMOTE_BEFORE" != "$REMOTE_AFTER" ]; then
  echo "Warning: remote 設定が変換前と異なります" >&2
  echo "変換前: $REMOTE_BEFORE" >&2
  echo "変換後: $REMOTE_AFTER" >&2
fi
```

### 5. 結果の確認

```bash
# worktree 一覧を確認
git -C "$DIR/bare.git" worktree list

# remote 設定が変換前と変わっていないことを確認
git -C "$DIR/bare.git" remote -v

# ディレクトリ構成を確認
ls -la "$DIR"
```

remote 設定が変換前と異なる場合は、ユーザーに警告し修正を提案する。

### 6. 完了報告

```
## Worktree 構成への変換完了

- **ディレクトリ:** <directory>
- **bare リポジトリ:** <directory>/bare.git
- **worktree:** <directory>/<branch>

新しい worktree を追加するには:
git -C <directory>/bare.git worktree add ../<new-branch> <new-branch>
```

## エラーハンドリング

### Git リポジトリでない場合

```
指定されたディレクトリは Git リポジトリではありません。
```

### detached HEAD の場合

```
detached HEAD 状態では変換できません。ブランチをチェックアウトしてから再実行してください。
```

### 既に bare リポジトリ / worktree 構成の場合

```
既に bare リポジトリです。
```

または:

```
.git ディレクトリが見つかりません (既に worktree 構成の可能性があります)。
```

### 変換途中で失敗した場合

`set -e` により即座に停止する。以下の手順で復旧を試みる:

1. `bare.git` が存在し `.git` がない場合 → `mv "$DIR/bare.git" "$DIR/.git"` と `git config core.bare false` で元に戻す
2. 一時ディレクトリにファイルが残っている場合 → ファイルを元のディレクトリに戻す
3. worktree が作成済みの場合 → `git -C "$DIR/bare.git" worktree remove "$BRANCH"` で削除
