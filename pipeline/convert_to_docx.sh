#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  Markdown → 政府標案 DOCX 全自動轉換 Pipeline
#  依據：國發會《政府文書格式參考規範》
#
#  三階段流程：
#    1. 建立 reference.docx 模板（標楷體/邊界/頁首頁尾）
#    2. Pandoc 批次轉換 md → docx
#    3. python-docx 後處理（表格框線/TOC/標題列底色）
#    4. 格式排查驗證
#
#  用法：./pipeline/convert_to_docx.sh [--force]
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="$DIR/output"
OUTPUT_DIR="$DIR/output_docx"
REFERENCE="$DIR/reference.docx"
FORCE=0

# 解析參數
for arg in "$@"; do
    [ "$arg" == "--force" ] && FORCE=1
done

# 顏色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "  ${GREEN}▸${NC} $1"; }
log_done()  { echo -e "  ${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "  ${RED}✘${NC} $1"; }

echo -e "\n${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  Markdown → 政府標案 DOCX 轉換${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}\n"

# ── 前置檢查 ──────────────────────────────────────────────
if ! command -v pandoc &>/dev/null; then
    log_error "pandoc 未安裝。請先 brew install pandoc"
    exit 1
fi

if ! python3 -c "import docx" 2>/dev/null; then
    log_error "python-docx 未安裝。請先 pip3 install python-docx"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    log_error "找不到 $INPUT_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── Mermaid 渲染環境偵測 ─────────────────────────────────
HAS_MMDC=0
if command -v npx &>/dev/null; then
    # 自動偵測 Puppeteer Chrome 路徑
    CHROME_PATH=""
    for _cdir in "$HOME/.cache/puppeteer/chrome"/mac_arm-*/chrome-mac-arm64; do
        _cbin="$_cdir/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
        [ -x "$_cbin" ] && CHROME_PATH="$_cbin" && break
    done
    # fallback: macOS 系統 Chrome
    if [ -z "$CHROME_PATH" ] && [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
        CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    fi
    if [ -n "$CHROME_PATH" ]; then
        export PUPPETEER_EXECUTABLE_PATH="$CHROME_PATH"
        HAS_MMDC=1
        log_info "Mermaid 渲染可用（Chrome: $(basename "$(dirname "$CHROME_PATH")")）"
    else
        log_warn "找不到 Chrome，Mermaid 區塊將保留原始碼。執行 npx puppeteer browsers install chrome 安裝"
    fi
else
    log_warn "npx 未安裝，Mermaid 區塊將保留原始碼"
fi

# ══════════════════════════════════════════════════════════════
#  Phase 1：建立 reference.docx 模板
# ══════════════════════════════════════════════════════════════
echo -e "${CYAN}Phase 1：建立 reference.docx 模板${NC}"

if [ "$FORCE" -eq 1 ] || [ ! -f "$REFERENCE" ]; then
    python3 "$DIR/create_reference_docx.py"
else
    log_warn "reference.docx 已存在（用 --force 重建）"
fi

# ══════════════════════════════════════════════════════════════
#  Phase 1.5：Mermaid 預渲染（Python 腳本）
# ══════════════════════════════════════════════════════════════
MERMAID_SCRIPT="$DIR/render_mermaid.py"
IMG_DIR="$OUTPUT_DIR/images"

# ══════════════════════════════════════════════════════════════
#  Phase 2：Pandoc 批次轉換
# ══════════════════════════════════════════════════════════════
echo -e "\n${CYAN}Phase 2：Pandoc 批次轉換（含 Mermaid 預渲染）${NC}"

declare -a CONVERT_LIST=()
for md_file in "$INPUT_DIR"/*.md; do
    [ ! -f "$md_file" ] && continue
    fname=$(basename "$md_file")
    [[ "$fname" == "品質報告.md" ]] && continue
    [[ "$fname" =~ _ch[0-9] ]] && continue
    CONVERT_LIST+=("$md_file")
done

TOTAL=${#CONVERT_LIST[@]}
COUNT=0
FAIL=0

for md_file in "${CONVERT_LIST[@]}"; do
    fname=$(basename "$md_file")
    docx_name="${fname%.md}.docx"
    docx_file="$OUTPUT_DIR/$docx_name"
    COUNT=$((COUNT + 1))

    if [ "$FORCE" -eq 0 ] && [ -f "$docx_file" ]; then
        log_warn "[$COUNT/$TOTAL] 已存在: ${docx_name}（用 --force 重轉）"
        continue
    fi

    log_info "[$COUNT/$TOTAL] 轉換中: $fname"

    file_size=$(wc -c < "$md_file" | tr -d ' ')
    base_name="${fname%.md}"

    # 分章合併邏輯
    chapter_files=()
    for _cf in "$INPUT_DIR/${base_name}_ch"*.md; do
        [ -f "$_cf" ] && chapter_files+=("$_cf")
    done

    if [ ${#chapter_files[@]} -gt 0 ] && [ "$file_size" -lt 10240 ]; then
        log_warn "主文件較小 (${file_size}B)，合併分章檔轉換"
        tmp_merged=$(mktemp /tmp/merged_XXXXXX.md)
        cat "$md_file" > "$tmp_merged"
        for ch_file in "${chapter_files[@]}"; do
            [ -f "$ch_file" ] && {
                echo -e "\n\n" >> "$tmp_merged"
                cat "$ch_file" >> "$tmp_merged"
            }
        done
        md_file="$tmp_merged"
    fi

    # Mermaid 預渲染：將 ```mermaid 區塊轉為 PNG 圖片
    rendered_md=""
    if grep -q '```mermaid' "$md_file" 2>/dev/null; then
        rendered_md=$(mktemp /tmp/mermaid_out_XXXXXX.md)
        python3 "$MERMAID_SCRIPT" "$md_file" "$rendered_md" "$IMG_DIR"
        pandoc_input="$rendered_md"
    else
        pandoc_input="$md_file"
    fi

    if pandoc "$pandoc_input" \
        --reference-doc="$REFERENCE" \
        --toc --toc-depth=3 \
        --wrap=none \
        -f markdown \
        -t docx \
        -o "$docx_file" 2>/dev/null; then
        size=$(du -h "$docx_file" | cut -f1 | tr -d ' ')
        log_done "$docx_name ($size)"
    else
        log_error "轉換失敗: $fname"
        FAIL=$((FAIL + 1))
    fi

    # 清理暫存檔
    [[ "$md_file" == /tmp/merged_* ]] && rm -f "$md_file"
    [[ -n "$rendered_md" && "$rendered_md" == /tmp/mermaid_out_* ]] && rm -f "$rendered_md"
done

echo ""
echo "  Pandoc 轉換: $((COUNT - FAIL)) / $TOTAL 成功"

# ══════════════════════════════════════════════════════════════
#  Phase 3：python-docx 後處理
# ══════════════════════════════════════════════════════════════
echo -e "\n${CYAN}Phase 3：後處理（表格框線 + TOC + 標題列底色）${NC}"
python3 "$DIR/postprocess_docx.py" "$OUTPUT_DIR"

# ══════════════════════════════════════════════════════════════
#  Phase 4：格式排查驗證
# ══════════════════════════════════════════════════════════════
echo -e "\n${CYAN}Phase 4：格式排查驗證${NC}"
python3 "$DIR/audit_docx_format.py"

# ── 結果摘要 ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  轉換完成${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""
echo "  輸出目錄: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR"/*.docx 2>/dev/null | awk '{print "    " $5 "\t" $NF}'
echo ""
echo -e "${YELLOW}提示: 開啟 Word 後按 Ctrl+A → F9 (Mac: Cmd+A → Fn+F9) 更新目錄頁碼${NC}"
echo ""
