#!/bin/bash
#
# Agent Skill Validator (Bash版)
#
# このスクリプトは Claude Code の Agent Skill を検証し、
# ベストプラクティスに準拠しているかを自動チェックします。
#
# 使用方法:
#     bash validate_skill.sh <skill-directory>
#
# 例:
#     bash validate_skill.sh /path/to/my-skill
#     bash validate_skill.sh .  # 現在のディレクトリ
#

set -e

# 色定義
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# カウンター
errors=0
warnings=0
info_count=0

# 引数チェック
if [ $# -eq 0 ]; then
    echo "使用方法: $0 <skill-directory>"
    echo "例: $0 /path/to/my-skill"
    exit 1
fi

SKILL_DIR="$1"

# スキルディレクトリの存在確認
if [ ! -d "$SKILL_DIR" ]; then
    echo -e "${RED}✗ エラー: ディレクトリが見つかりません: $SKILL_DIR${NC}"
    exit 1
fi

cd "$SKILL_DIR"
SKILL_NAME=$(basename "$(pwd)")

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Agent Skill Validator${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "検証対象: $(pwd)"
echo ""

# ============================================
# 1. SKILL.md の存在チェック
# ============================================
echo -e "${BLUE}[1/9]${NC} SKILL.md の存在チェック..."
if [ ! -f "SKILL.md" ]; then
    echo -e "${RED}  ✗ エラー: SKILL.md が見つかりません${NC}"
    ((errors++))
else
    echo -e "${GREEN}  ✓ SKILL.md が存在します${NC}"
fi

# 以降のチェックは SKILL.md が存在する場合のみ
if [ ! -f "SKILL.md" ]; then
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}検証失敗: $errors エラー${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi

# ============================================
# 2. YAML frontmatter の基本構造チェック
# ============================================
echo -e "${BLUE}[2/9]${NC} YAML frontmatter の構造チェック..."
first_line=$(head -1 SKILL.md)
if [ "$first_line" != "---" ]; then
    echo -e "${RED}  ✗ エラー: YAML frontmatter が --- で始まっていません${NC}"
    ((errors++))
else
    # 2つ目の --- を探す
    second_dash_line=$(tail -n +2 SKILL.md | grep -n "^---$" | head -1 | cut -d: -f1)
    if [ -z "$second_dash_line" ]; then
        echo -e "${RED}  ✗ エラー: YAML frontmatter が正しく閉じられていません（2つ目の --- が見つかりません）${NC}"
        ((errors++))
    else
        echo -e "${GREEN}  ✓ YAML frontmatter の構造が正しいです${NC}"
    fi
fi

# ============================================
# 3. name フィールドのチェック
# ============================================
echo -e "${BLUE}[3/9]${NC} name フィールドのチェック..."

# name が存在するか
if ! grep -q "^name:" SKILL.md; then
    echo -e "${RED}  ✗ エラー: name フィールドが見つかりません${NC}"
    ((errors++))
else
    # name の値を取得（frontmatter 部分から）
    name_value=$(head -20 SKILL.md | grep "^name:" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '\r\n')

    if [ -z "$name_value" ]; then
        echo -e "${RED}  ✗ エラー: name の値が空です${NC}"
        ((errors++))
    else
        echo -e "${GREEN}  ✓ name: $name_value${NC}"

        # lowercase-hyphen-case の形式チェック
        if ! echo "$name_value" | grep -Eq "^[a-z0-9-]+$"; then
            echo -e "${RED}  ✗ エラー: name は lowercase-hyphen-case である必要があります（小文字英数字とハイフンのみ）${NC}"
            ((errors++))
        fi

        # 64文字以内か
        name_length=${#name_value}
        if [ $name_length -gt 64 ]; then
            echo -e "${RED}  ✗ エラー: name は64文字以内である必要があります（現在: $name_length 文字）${NC}"
            ((errors++))
        fi

        # ディレクトリ名と一致するか
        if [ "$name_value" != "$SKILL_NAME" ]; then
            echo -e "${RED}  ✗ エラー: name '$name_value' がディレクトリ名 '$SKILL_NAME' と一致しません${NC}"
            ((errors++))
        fi
    fi
fi

# ============================================
# 4. description フィールドのチェック
# ============================================
echo -e "${BLUE}[4/9]${NC} description フィールドのチェック..."

# description が存在するか
if ! grep -q "^description:" SKILL.md; then
    echo -e "${RED}  ✗ エラー: description フィールドが見つかりません${NC}"
    ((errors++))
else
    # description の値を取得（frontmatter 部分から）
    desc_value=$(head -20 SKILL.md | grep "^description:" | head -1 | sed 's/^description:[[:space:]]*//' | tr -d '\r\n')

    if [ -z "$desc_value" ]; then
        echo -e "${RED}  ✗ エラー: description の値が空です${NC}"
        ((errors++))
    else
        # 最初の50文字のみ表示
        desc_preview=$(echo "$desc_value" | cut -c1-50)
        echo -e "${GREEN}  ✓ description: ${desc_preview}...${NC}"

        # 文字数チェック
        desc_chars=$(echo -n "$desc_value" | wc -m | tr -d ' ')

        if [ $desc_chars -gt 1024 ]; then
            echo -e "${RED}  ✗ エラー: description は1024文字以内である必要があります（現在: $desc_chars 文字）${NC}"
            ((errors++))
        elif [ $desc_chars -gt 200 ]; then
            echo -e "${YELLOW}  ⚠ 警告: description は200文字以内が推奨されます（現在: $desc_chars 文字）${NC}"
            ((warnings++))
        fi
    fi
fi

# ============================================
# 5. SKILL.md の行数チェック
# ============================================
echo -e "${BLUE}[5/9]${NC} SKILL.md の行数チェック..."
line_count=$(wc -l < SKILL.md | tr -d ' ')

if [ $line_count -gt 500 ]; then
    echo -e "${YELLOW}  ⚠ 警告: SKILL.md は500行以内が推奨されます（現在: $line_count 行）${NC}"
    echo -e "${YELLOW}     詳細情報は別ファイルに分離することを検討してください${NC}"
    ((warnings++))
else
    echo -e "${GREEN}  ✓ 行数: $line_count 行（500行以内）${NC}"
fi

# ============================================
# 6. サポートされていないフィールドのチェック
# ============================================
echo -e "${BLUE}[6/9]${NC} サポートされていないフィールドのチェック..."
unsupported_found=0

# frontmatter 内のすべてのフィールドを抽出
# (先頭の --- から2つ目の --- までの間で、コメント行以外のフィールド)
fields=$(sed -n '/^---$/,/^---$/p' SKILL.md | grep -E '^[a-z][a-z-]*:' | grep -v '^#' | sed 's/:.*//' | sort -u)

# サポートされているフィールド
supported_fields=("name" "description" "allowed-tools")

# 各フィールドをチェック
while IFS= read -r field; do
    if [ -z "$field" ]; then
        continue
    fi

    # サポートされているフィールドかチェック
    is_supported=0
    for supported in "${supported_fields[@]}"; do
        if [ "$field" = "$supported" ]; then
            is_supported=1
            break
        fi
    done

    # サポートされていないフィールドの場合は警告
    if [ $is_supported -eq 0 ]; then
        echo -e "${YELLOW}  ⚠ 警告: '$field' フィールドは公式仕様でサポートされていません${NC}"
        echo -e "${YELLOW}     サポートされているフィールド: name, description, allowed-tools${NC}"
        ((warnings++))
        ((unsupported_found++))
    fi
done <<< "$fields"

if [ $unsupported_found -eq 0 ]; then
    echo -e "${GREEN}  ✓ サポートされていないフィールドは見つかりませんでした${NC}"
fi

# ============================================
# 7. セキュリティチェック（基本パターン）
# ============================================
echo -e "${BLUE}[7/9]${NC} セキュリティパターンのチェック..."
security_issues=0

# API キー、パスワード、シークレットのハードコードチェック
# （コードブロック外のみをチェック - 簡易版）
if grep -iE 'api_key\s*=\s*["\047]' SKILL.md | grep -v '```' > /dev/null 2>&1; then
    echo -e "${RED}  ✗ エラー: ハードコードされた API キーの可能性があります${NC}"
    ((errors++))
    ((security_issues++))
fi

if grep -iE 'password\s*=\s*["\047]' SKILL.md | grep -v '```' > /dev/null 2>&1; then
    echo -e "${RED}  ✗ エラー: ハードコードされたパスワードの可能性があります${NC}"
    ((errors++))
    ((security_issues++))
fi

if grep -iE 'secret\s*=\s*["\047]' SKILL.md | grep -v '```' > /dev/null 2>&1; then
    echo -e "${RED}  ✗ エラー: ハードコードされたシークレットの可能性があります${NC}"
    ((errors++))
    ((security_issues++))
fi

# よく知られたトークンパターン
if grep -E 'sk-[a-zA-Z0-9]{32,}' SKILL.md | grep -v '```' > /dev/null 2>&1; then
    echo -e "${RED}  ✗ エラー: OpenAI API キーらしきパターンが見つかりました${NC}"
    ((errors++))
    ((security_issues++))
fi

if grep -E 'ghp_[a-zA-Z0-9]{36,}' SKILL.md | grep -v '```' > /dev/null 2>&1; then
    echo -e "${RED}  ✗ エラー: GitHub Personal Access Token らしきパターンが見つかりました${NC}"
    ((errors++))
    ((security_issues++))
fi

if [ $security_issues -eq 0 ]; then
    echo -e "${GREEN}  ✓ 明らかなセキュリティ問題は検出されませんでした${NC}"
fi

# ============================================
# 8. 参照ファイルの存在チェック
# ============================================
echo -e "${BLUE}[8/9]${NC} 参照ファイルの存在チェック..."
missing_files=0

# Markdown リンク [text](file.md) から相対パスを抽出
# http(s):// で始まらないローカルファイルのみチェック
links=$(grep -oE '\]\([^)]+\)' SKILL.md | sed 's/][(]//' | sed 's/)//' | grep -v '^https\?://' || true)

if [ -n "$links" ]; then
    while IFS= read -r link; do
        # アンカー (#) を削除
        file_path="${link%%#*}"

        # 空の場合はスキップ
        if [ -z "$file_path" ]; then
            continue
        fi

        # ファイルの存在確認
        if [ ! -f "$file_path" ] && [ ! -d "$file_path" ]; then
            echo -e "${YELLOW}  ⚠ 警告: 参照ファイルが見つかりません: $file_path${NC}"
            ((warnings++))
            ((missing_files++))
        fi
    done <<< "$links"
fi

if [ $missing_files -eq 0 ]; then
    echo -e "${GREEN}  ✓ すべての参照ファイルが存在します${NC}"
fi

# ============================================
# 9. allowed-tools の形式チェック（存在する場合）
# ============================================
echo -e "${BLUE}[9/9]${NC} allowed-tools の形式チェック..."

# frontmatter 内に allowed-tools があるかチェック（最初の20行のみ対象）
if head -20 SKILL.md | grep -q "^allowed-tools:"; then
    # インデントされたリスト項目があるか確認
    # frontmatter 内の allowed-tools セクションを抽出して確認
    if ! head -20 SKILL.md | sed -n '/^allowed-tools:/,/^[a-z-]*:/p' | grep -q "^  - "; then
        echo -e "${YELLOW}  ⚠ 警告: allowed-tools の書式が正しくない可能性があります${NC}"
        echo -e "${YELLOW}     期待される形式:${NC}"
        echo -e "${YELLOW}       allowed-tools:${NC}"
        echo -e "${YELLOW}         - Read${NC}"
        echo -e "${YELLOW}         - Write${NC}"
        ((warnings++))
    else
        echo -e "${GREEN}  ✓ allowed-tools の形式が正しいです${NC}"
    fi
else
    echo -e "${GREEN}  ✓ allowed-tools は使用されていません（オプション）${NC}"
fi

# ============================================
# 結果サマリー
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  検証結果${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "${GREEN}✓ すべてのチェックに合格しました！${NC}"
    echo ""
    echo -e "${BLUE}次のステップ:${NC}"
    echo "  手動チェックリストで追加の品質確認を行ってください。"
    echo "  詳細は SKILL.md の「STEP 8: 検証とテスト」を参照。"
    exit 0
elif [ $errors -eq 0 ]; then
    echo -e "${YELLOW}⚠ $warnings 件の警告があります${NC}"
    echo ""
    echo "警告を確認して必要に応じて修正してください。"
    exit 0
else
    echo -e "${RED}✗ $errors 件のエラーがあります${NC}"
    if [ $warnings -gt 0 ]; then
        echo -e "${YELLOW}⚠ $warnings 件の警告があります${NC}"
    fi
    echo ""
    echo "エラーを修正してから再度実行してください。"
    exit 1
fi
