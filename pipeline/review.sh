#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 台鐵 AI 客服系統建置案 — 多角色平行審查
# ═══════════════════════════════════════════════════════════════
#
#   ./review.sh              ← 全部角色平行審查
#   ./review.sh --roles 1,3  ← 只跑指定角色（編號見下方列表）
#   ./review.sh --dry-run    ← 只印 prompt 不呼叫 Claude
#
# 角色列表：
#   1. 首席系統架構師      2. AI/ML 工程師
#   3. 專案經理            4. 資安顧問
#   5. 技術文件寫手        6. 採購合規專家
#   7. 品質管理專家        8. 格式審查員
#   9. 標案審查委員       10. 品質管理總監
#
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$DIR")"
OUT="$DIR/output"
DECISIONS="$DIR/decisions.yaml"
REVIEW_DIR="$DIR/review_results"
ANALYSIS="$PROJECT/台鐵 AI 客服系統建置案 — 深度解析報告.md"

mkdir -p "$REVIEW_DIR"

# ── 顏色 ────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log_info()  { echo -e "${CYAN}  ▸ $1${NC}"; }
log_done()  { echo -e "${GREEN}  ✅ $1${NC}"; }
log_fail()  { echo -e "${RED}  ✗ $1${NC}"; }
log_role()  { echo -e "${MAGENTA}  🔍 [$1] $2${NC}"; }

# ── 參數處理 ────────────────────────────────────────────────
DRY_RUN=0
SELECTED_ROLES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=1; shift ;;
        --roles)    SELECTED_ROLES="$2"; shift 2 ;;
        *)          echo "未知參數: $1"; exit 1 ;;
    esac
done

# ── 收集所有主檔（排除 _ch* 分章檔）──────────────────────────
DOC_FILES=()
for f in "$OUT"/*.md; do
    fname="$(basename "$f")"
    # 跳過分章檔和品質報告
    [[ "$fname" == *_ch*.md ]] && continue
    [[ "$fname" == "品質報告.md" ]] && continue
    DOC_FILES+=("$f")
done

echo -e "\n${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  多角色平行審查 — ${#DOC_FILES[@]} 份文件          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}\n"

# ── 組合所有文件內容（供 prompt 注入）─────────────────────────
build_all_docs_context() {
    local max_lines_per_doc="${1:-300}"
    for f in "${DOC_FILES[@]}"; do
        local fname="$(basename "$f")"
        echo "════════════════════════════════════════"
        echo "📄 $fname"
        echo "════════════════════════════════════════"
        head -"$max_lines_per_doc" "$f"
        local total
        total=$(wc -l < "$f" | tr -d ' ')
        if [ "$total" -gt "$max_lines_per_doc" ]; then
            echo ""
            echo "... (截斷，共 $total 行，已顯示前 $max_lines_per_doc 行)"
        fi
        echo ""
    done
}

# ── decisions.yaml 讀取 ──────────────────────────────────────
decisions_section() {
    local section_id="$1"
    awk "
        /^# *SECTION ${section_id}/ { found=1; next }
        /^# =+$/  { if (found) next }
        /^# *SECTION [A-Z]/ { if (found) exit }
        found { print }
    " "$DECISIONS" 2>/dev/null
}

# ── 合規紅線 ────────────────────────────────────────────────
COMPLIANCE="
## 合規紅線（強制遵守）
1. 全文繁體中文，禁止簡體中文字元與大陸慣用語
2. 團隊成員不得為陸籍人士（含分包人員）
3. 不得使用大陸地區品牌或大陸地區製造之軟硬體
4. 所有資料地端部署於台鐵機房，禁止跨境傳輸
5. 符合 CNS 27001 資訊安全管理標準
6. 旅客個資須加密儲存、去識別化、存取日誌、最小權限
7. 系統異常時應能立即切換人工客服且不影響正常運作
8. 軟體授權到期後可繼續使用到期前最後更新版本
9. 文件格式 A4 直式橫書，附頁次，案號 L0215P2010U
10. 涉及共通性 API 須依國發會規範辦理
11. 廠商人員須接受適任性查核，全員簽署同意書
12. 設備須為決標日前 1 年內新品
"

# ── 預載 context ──────────────────────────────────────────────
log_info "預載文件內容..."
ALL_DOCS_CTX="$(build_all_docs_context 300)"

DECISIONS_KPI="$(decisions_section D)"
DECISIONS_HW="$(decisions_section E)"
DECISIONS_COMPLIANCE="$(decisions_section F)"
DECISIONS_ARCH="$(decisions_section H)"
DECISIONS_TERMS="$(decisions_section I)"
DECISIONS_BIZ="$(decisions_section A)"
DECISIONS_TECH="$(decisions_section B)"
DECISIONS_CONTRACT="$(decisions_section C)"
DECISIONS_CAPACITY="$(decisions_section G)"

log_done "預載完成"

# ═══════════════════════════════════════════════════════════════
#  角色定義：名稱 / 審查焦點 / 額外 context
# ═══════════════════════════════════════════════════════════════

declare -a ROLE_NAMES ROLE_DESCS ROLE_FOCUS ROLE_EXTRA_CTX

# 1. 首席系統架構師
ROLE_NAMES[1]="首席系統架構師"
ROLE_DESCS[1]="你是 20 年經驗首席系統架構師，專精 VoIP/SIP 與 AI 推論系統設計。"
ROLE_FOCUS[1]="
1. 系統架構描述是否完整（六層式架構、邏輯/實體架構圖描述）
2. 技術選型是否合理且一致（SIP trunk、WebRTC、GPU 推論、RAG）
3. 高可用設計是否到位（HA 雙機切換、負載均衡、災難復原）
4. 效能指標是否可達（STT 延遲、同時通話數、TPS）
5. 跨文件的架構描述是否一致（#02 vs #06 vs #10）
6. 介面設計是否完整（內部模組間 + 外部系統）"
ROLE_EXTRA_CTX[1]="
## decisions.yaml — 技術架構
$DECISIONS_TECH
## decisions.yaml — 硬體規格
$DECISIONS_HW
## decisions.yaml — 架構
$DECISIONS_ARCH
## decisions.yaml — 容量
$DECISIONS_CAPACITY"

# 2. AI/ML 工程師
ROLE_NAMES[2]="AI-ML 工程師"
ROLE_DESCS[2]="你是 AI/ML 工程師，專精 LLM 地端部署、NVIDIA L40S GPU 推論優化、RAG 架構。"
ROLE_FOCUS[2]="
1. LLM 地端部署架構是否合理（模型選擇、量化方案、推論框架）
2. GPU 配置是否足夠（L40S × N 的 VRAM/算力是否支撐 KPI）
3. RAG 架構是否完整（向量庫選型、chunk 策略、retrieval pipeline）
4. STT/TTS 元件選型與延遲是否合理
5. AI 模組的測試計畫是否涵蓋（準確率、回應時間、幻覺率）
6. 模型更新/微調流程是否描述"
ROLE_EXTRA_CTX[2]="
## decisions.yaml — 技術
$DECISIONS_TECH
## decisions.yaml — 硬體規格
$DECISIONS_HW
## decisions.yaml — KPI
$DECISIONS_KPI"

# 3. 專案經理
ROLE_NAMES[3]="PMP 專案經理"
ROLE_DESCS[3]="你是 PMP 認證 IT 專案經理，具 15 年政府標案履約管理經驗。"
ROLE_FOCUS[3]="
1. 工作計畫書的 WBS/甘特圖/RACI 是否完整合理
2. 四期付款里程碑是否與時程對齊
3. 270 天履約期內的關鍵路徑是否標示
4. 風險登記冊是否涵蓋主要風險（至少 10 項 + 影響 + 對策）
5. 教育訓練時數是否符合契約要求（值機≥36hr + 管理≥18hr）
6. 結案報告是否涵蓋所有交付項目的完成狀態
7. 跨文件的時程/人力數字是否一致"
ROLE_EXTRA_CTX[3]="
## decisions.yaml — 商業/履約
$DECISIONS_BIZ
$DECISIONS_CONTRACT
## decisions.yaml — KPI
$DECISIONS_KPI"

# 4. 資安顧問
ROLE_NAMES[4]="CISSP 資安顧問"
ROLE_DESCS[4]="你是 CISSP 認證資安顧問，專精弱掃、滲透測試、源碼檢測、CNS 27001。"
ROLE_FOCUS[4]="
1. CNS 27001 合規要求是否在各文件中體現
2. 資安檢測計畫是否完整（弱掃、滲透測試、源碼檢測工具與頻率）
3. 個資保護措施是否充分（PIA、加密、去識別化、存取控制）
4. 資料地端部署聲明是否明確，有無跨境傳輸風險
5. 系統異常切換人工客服的機制是否有技術細節
6. Prompt Injection 防禦是否有具體技術措施
7. 日誌與稽核軌跡是否完整描述"
ROLE_EXTRA_CTX[4]="
## decisions.yaml — 合規
$DECISIONS_COMPLIANCE
## decisions.yaml — 技術
$DECISIONS_TECH"

# 5. 技術文件寫手
ROLE_NAMES[5]="技術文件寫手"
ROLE_DESCS[5]="你是政府資訊系統技術文件寫手，熟悉 A4 直式橫書繁中格式。"
ROLE_FOCUS[5]="
1. 是否有空白/stub 章節（少於 5 行實質內容）
2. 是否有 placeholder（TODO、TBD、待補、xxx、[填入]）
3. 段落是否通順，有無語句不完整或前後矛盾
4. 專業術語使用是否正確且一致
5. 圖表是否有編號且被正文引用
6. 每份文件是否有完整的版本/案號/日期 header
7. 用語是否統一（立約商 vs 廠商 vs 我方 — 只能用一種）"
ROLE_EXTRA_CTX[5]="
## decisions.yaml — 術語表
$DECISIONS_TERMS"

# 6. 採購合規專家
ROLE_NAMES[6]="採購合規專家"
ROLE_DESCS[6]="你是政府採購合規專家，具 20 年標案審查經驗。"
ROLE_FOCUS[6]="
1. 無簡體中文字元
2. 無大陸慣用語（服務器→伺服器、信息→資訊、數據庫→資料庫 等）
3. 無大陸品牌（華為/ZTE/聯想/浪潮/H3C/阿里雲/騰訊/百度/海康/大華）
4. 無跨境傳輸描述
5. 人員國籍限制是否聲明
6. 軟體授權到期後續用條款是否明確
7. 設備新品年限要求（決標日前 1 年）是否載明
8. 共通性 API 國發會規範是否提及"
ROLE_EXTRA_CTX[6]="
$COMPLIANCE
## decisions.yaml — 合規
$DECISIONS_COMPLIANCE"

# 7. 品質管理專家
ROLE_NAMES[7]="品質管理專家"
ROLE_DESCS[7]="你是品質管理專家，專精跨文件一致性與數字正確性。"
ROLE_FOCUS[7]="
1. KPI 數字在所有文件中是否一致（以 decisions.yaml 為唯一正確來源）
2. FR 編號是否完整覆蓋（#02 定義 → #05 有 TC → #09 有結果 → #10 有程式說明）
3. 硬體型號/數量在 #02、#06、#08 是否一致
4. 模組名稱/編號跨文件是否一致
5. 人數、時數、天數等數字跨文件是否一致
6. 版本號是否 13 份一致"
ROLE_EXTRA_CTX[7]="
## decisions.yaml — KPI（唯一正確來源）
$DECISIONS_KPI
## decisions.yaml — 硬體規格（唯一正確來源）
$DECISIONS_HW"

# 8. 格式審查員
ROLE_NAMES[8]="格式審查員"
ROLE_DESCS[8]="你是技術文件格式審查員，專注文件結構與排版規範。"
ROLE_FOCUS[8]="
1. 每份文件是否有 header block（版本、案號 L0215P2010U、日期、頁次）
2. Markdown 語法是否正確（表格對齊、標題層級、程式碼區塊）
3. 標題層級是否正確（# 文件名 → ## 章 → ### 節）
4. 編號是否連續無跳號（章節、表格、圖）
5. 「詳見第X章」引用是否指向存在的章節
6. 目錄（TOC）與實際章節標題是否對應
7. 所有表格是否有表頭"
ROLE_EXTRA_CTX[8]=""

# 9. 標案審查委員
ROLE_NAMES[9]="標案審查委員"
ROLE_DESCS[9]="你是台鐵標案資深審查委員，模擬甲方最嚴格的質疑角度。"
ROLE_FOCUS[9]="
1. 站在甲方角度，有哪些地方會被質疑「空泛無實質」？
2. 哪些承諾缺乏具體實現方式或量化指標？
3. 哪些技術描述只有名詞堆疊而無架構說明？
4. 教育訓練是否有具體課表/時程/教材？
5. 測試計畫/報告是否有真實可信的數據與方法論？
6. 系統上線計畫是否有具體的回滾方案？
7. 整體而言，這套文件能否通過政府標案審查？"
ROLE_EXTRA_CTX[9]="
## decisions.yaml — 商業
$DECISIONS_BIZ
## decisions.yaml — 履約
$DECISIONS_CONTRACT"

# 10. 品質管理總監
ROLE_NAMES[10]="品質管理總監"
ROLE_DESCS[10]="你是品質管理總監，負責綜合評估所有文件的整體品質水準。"
ROLE_FOCUS[10]="
1. 13 份文件是否涵蓋契約第八條所有交付項目
2. 文件間的邏輯鏈是否完整（需求→設計→實作→測試→上線→維護）
3. 是否有明顯的「複製貼上」痕跡（不同文件出現相同的大段文字）
4. 整體專業度與可信度評估
5. 如果你是審查委員，最可能被打回的 Top 3 文件是哪些？為什麼？
6. 給出整體品質評分（0~100）與改善優先序"
ROLE_EXTRA_CTX[10]="
## decisions.yaml — KPI
$DECISIONS_KPI
## decisions.yaml — 合規
$DECISIONS_COMPLIANCE"

ALL_ROLE_IDS=(1 2 3 4 5 6 7 8 9 10)

# ── 過濾指定角色 ──────────────────────────────────────────────
if [ -n "$SELECTED_ROLES" ]; then
    IFS=',' read -ra ALL_ROLE_IDS <<< "$SELECTED_ROLES"
    log_info "只執行角色: ${ALL_ROLE_IDS[*]}"
fi

# ═══════════════════════════════════════════════════════════════
#  平行審查執行
# ═══════════════════════════════════════════════════════════════

BG_PIDS=()
BG_LABELS=()

run_role_review() {
    local role_id="$1"
    local role_name="${ROLE_NAMES[$role_id]}"
    local role_desc="${ROLE_DESCS[$role_id]}"
    local role_focus="${ROLE_FOCUS[$role_id]}"
    local role_extra="${ROLE_EXTRA_CTX[$role_id]}"
    local output_file="$REVIEW_DIR/review_$(printf '%02d' "$role_id")_${role_name}.md"

    local prompt="Role: $role_desc

Context:
$role_extra

$COMPLIANCE

## 以下是全部交付文件內容
$ALL_DOCS_CTX

Task: 以「${role_name}」的專業角度，逐份審查上方所有交付文件。

## 審查焦點
$role_focus

## 輸出格式

### 審查摘要
- 審查角色：${role_name}
- 審查文件數：${#DOC_FILES[@]}
- 審查時間：$(date '+%Y-%m-%d %H:%M')

### 致命級問題（必須修正，否則無法通過審查）
| # | 文件 | 位置 | 問題描述 | 修正建議 |
|---|------|------|----------|----------|

### 重要級問題（強烈建議修正）
| # | 文件 | 位置 | 問題描述 | 修正建議 |
|---|------|------|----------|----------|

### 一般級問題（建議改善）
| # | 文件 | 位置 | 問題描述 | 修正建議 |
|---|------|------|----------|----------|

### 角色評語
（以 ${role_name} 的角度，對整體文件品質的 2~3 句評語）

### 評分
（0~100，附評分理由）

★ 重要：只報告確實存在的問題，不要捏造。每個問題必須指出具體文件名和具體位置。
★ 如果某份文件在你的專業範圍外，可以跳過，但請說明跳過原因。"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "$prompt" > "$output_file.prompt.txt"
        log_info "[DRY-RUN] 已輸出 prompt: $(basename "$output_file.prompt.txt")"
        return 0
    fi

    log_role "$role_name" "開始審查..."

    claude -p "$prompt" --output-format text > "$output_file" 2>/dev/null

    if [ -s "$output_file" ]; then
        log_done "[$role_name] 審查完成 → $(basename "$output_file")"
    else
        log_fail "[$role_name] 審查產出為空"
        rm -f "$output_file"
        return 1
    fi
}

# 使用 & fork 子程序，自動繼承所有變數，不需要 export

# ── 啟動所有角色（背景平行）──────────────────────────────────
log_info "啟動 ${#ALL_ROLE_IDS[@]} 個角色平行審查...\n"

for role_id in "${ALL_ROLE_IDS[@]}"; do
    run_role_review "$role_id" &
    BG_PIDS+=($!)
    BG_LABELS+=("${ROLE_NAMES[$role_id]}")
done

# ── 等待所有審查完成 ──────────────────────────────────────────
FAILED=0
for i in "${!BG_PIDS[@]}"; do
    if ! wait "${BG_PIDS[$i]}" 2>/dev/null; then
        log_fail "角色審查失敗: ${BG_LABELS[$i]}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ "$FAILED" -gt 0 ]; then
    log_fail "$FAILED 個角色審查失敗"
else
    log_done "全部 ${#ALL_ROLE_IDS[@]} 個角色審查完成"
fi

# ═══════════════════════════════════════════════════════════════
#  彙整總報告
# ═══════════════════════════════════════════════════════════════

if [ "$DRY_RUN" -eq 1 ]; then
    log_info "[DRY-RUN] 跳過彙整"
    exit 0
fi

log_info "彙整審查總報告..."

# 收集所有審查結果
ALL_REVIEWS=""
for rf in "$REVIEW_DIR"/review_*.md; do
    [ -f "$rf" ] || continue
    ALL_REVIEWS="$ALL_REVIEWS
════════════════════════════════════════
## $(basename "$rf" .md)
════════════════════════════════════════
$(cat "$rf")

"
done

claude -p "Role: 你是品質管理總監，負責彙整多角色審查結果。

Context:
以下是 ${#ALL_ROLE_IDS[@]} 位專家從不同角度對同一批交付文件的審查結果：

$ALL_REVIEWS

Task: 彙整所有角色的審查結果，產出「多角色聯合審查報告」：

## 輸出格式

# 多角色聯合審查報告
- 審查日期：$(date '+%Y-%m-%d')
- 參與角色：${#ALL_ROLE_IDS[@]} 位
- 審查文件：${#DOC_FILES[@]} 份

## 1. 問題彙總統計
| 角色 | 致命 | 重要 | 一般 | 評分 |
|------|------|------|------|------|

## 2. 致命級問題清單（去重合併）
（多角色指出同一問題的合併為一條，標註「N 位專家共識」）
| # | 文件 | 問題 | 指出角色 | 修正建議 |

## 3. 重要級問題清單（去重合併）
（同上格式）

## 4. 各文件健康度
| 文件 | 致命 | 重要 | 一般 | 狀態 |
（狀態：🔴 需大改 / 🟡 需修正 / 🟢 可接受）

## 5. 修正優先序
（按影響度排序的 Top 10 修正建議）

## 6. 整體評語
（綜合所有角色意見的 3~5 句評語）

## 7. 綜合評分
（加權平均 + 各角色評分明細）

★ 去重時以問題實質相同為準，不同角色用不同措辭描述同一問題應合併。
★ 保留每個問題的具體文件名和位置資訊。
" --output-format text > "$REVIEW_DIR/consolidated_review.md" 2>/dev/null

if [ -s "$REVIEW_DIR/consolidated_review.md" ]; then
    # 複製到 output 目錄
    cp "$REVIEW_DIR/consolidated_review.md" "$OUT/多角色聯合審查報告.md"
    log_done "聯合審查報告 → pipeline/output/多角色聯合審查報告.md"
else
    log_fail "聯合審查報告產出為空"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  審查完成！結果位於：${NC}"
echo -e "${CYAN}  個別報告：pipeline/review_results/${NC}"
echo -e "${CYAN}  彙整報告：pipeline/output/多角色聯合審查報告.md${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
