#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 台鐵 AI 客服系統建置案 — 五幕劇自動化引擎 v7
# ═══════════════════════════════════════════════════════════════
#
#   ./run.sh              ← 從頭跑完 Act 1 ~ Act 5
#   ./run.sh --from act3  ← 從 Act 3 斷點續跑
#   ./run.sh --only act1  ← 只跑 Act 1
#   ./run.sh --status     ← 看進度
#   ./run.sh --force      ← 忽略已有產出，全部重跑
#
# v7 改動（自動修正）：
#   - 新增 mkdir -p 確保目錄存在
#   - 新增 --force 跳過冪等快取
#   - 新增 Act 1 reviewer_profiles 產出步驟
#   - subshell 錯誤處理改進（trap + 部分合併）
#   - Act 4 合規閘門改用 shell grep 全文預掃 + Claude 審查
#   - Act 5 修正輪改為 diff-based（不再整份重寫）
#   - Token 估算修正（中英混合權重）
#   - 新增前置依賴檢查 require_file()
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

FORCE=0

# ── 背景 job 失敗追蹤 ────────────────────────────────────────
BG_PIDS=()      # 追蹤背景 PID
BG_LABELS=()    # 對應的標籤

# 啟動背景 job 並追蹤
bg_run() {
    local label="$1"; shift
    "$@" &
    BG_PIDS+=($!)
    BG_LABELS+=("$label")
}

# 等待所有背景 job，失敗時報告哪個出問題
bg_wait() {
    local failed=0
    for i in "${!BG_PIDS[@]}"; do
        if ! wait "${BG_PIDS[$i]}" 2>/dev/null; then
            log_fail "背景任務失敗: ${BG_LABELS[$i]} (PID ${BG_PIDS[$i]})"
            failed=1
        fi
    done
    BG_PIDS=()
    BG_LABELS=()
    if [ "$failed" -eq 1 ]; then
        log_fail "有背景任務失敗，中止 pipeline"
        return 1
    fi
}

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$DIR")"
STATE="$DIR/shared_state"
OUT="$DIR/output"
DECISIONS="$DIR/decisions.yaml"
ANALYSIS="$PROJECT/台鐵 AI 客服系統建置案 — 深度解析報告.md"

# ── 確保所有輸出目錄存在 ─────────────────────────────────────
mkdir -p "$STATE"/{chapters,assembled,skeletons,validation} "$OUT"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log_act()  { echo -e "\n${CYAN}╔═══════════════════════════════════════╗${NC}"; echo -e "${CYAN}║  $1${NC}"; echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}\n"; }
log_step() { echo -e "${GREEN}  ▸ $1${NC}"; }
log_warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
log_done() { echo -e "${GREEN}  ✅ $1${NC}"; }
log_fail() { echo -e "${RED}  ✗ $1${NC}"; }

# ── Claude 呼叫封裝 ──────────────────────────────────────────
call_claude() {
    local prompt="$1"
    local output_file="$2"

    if [ "$FORCE" -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        log_warn "已存在，跳過: $(basename "$output_file")（用 --force 強制重跑）"
        return 0
    fi

    # Context 大小 log
    # 中文字 ≈ 1.5 token, ASCII ≈ 0.25 token — 加權估算
    local char_count=${#prompt}
    local ascii_count cjk_count est_tokens
    ascii_count=$(echo "$prompt" | LC_ALL=C tr -cd '\0-\177' | wc -c | tr -d ' ')
    cjk_count=$((char_count - ascii_count))
    est_tokens=$(( ascii_count / 4 + cjk_count * 3 / 2 ))
    log_step "呼叫 Claude → $(basename "$output_file")  [context ≈${est_tokens} tokens]"

    if [ "$est_tokens" -gt 80000 ]; then
        log_warn "Context 偏大 (≈${est_tokens} tokens)，可能影響品質"
    fi

    claude -p "$prompt" --output-format text > "$output_file" 2>/dev/null

    if [ ! -s "$output_file" ]; then
        log_fail "產出為空: $(basename "$output_file")"
        rm -f "$output_file"
        return 1
    fi
    log_done "$(basename "$output_file") ($(wc -c < "$output_file" | tr -d ' ') bytes)"
}

# ── 讀檔輔助（安全處理不存在的檔案）──────────────────────────
read_file() { [ -f "$1" ] && cat "$1" || echo "(尚未產出)"; }

# ── 前置依賴檢查 ────────────────────────────────────────────
require_file() {
    local file="$1"
    local context="${2:-}"
    if [ ! -f "$file" ] || [ ! -s "$file" ]; then
        log_fail "前置依賴不存在或為空: $(basename "$file") ${context:+(需要: $context)}"
        return 1
    fi
}

# ══════════════════════════════════════════════════════════════
#  Context 智慧抽取函式
# ══════════════════════════════════════════════════════════════

# 從 decisions.yaml 抽取指定 Section（A~I）
# 用法：decisions_section "B" → 回傳 SECTION B 的完整內容
decisions_section() {
    local section_id="$1"
    # 用 awk 抓從「# SECTION X」到下一個「# SECTION」或檔尾
    awk "
        /^# *SECTION ${section_id}/ { found=1; next }
        /^# =+$/  { if (found) next }
        /^# *SECTION [A-Z]/ { if (found) exit }
        found { print }
    " "$DECISIONS" 2>/dev/null
}

# 依文件類型取 decisions.yaml 中相關段落
# 技術文件需要 B(技術)+D(KPI)+E(硬體)+G(容量)+H(架構)+I(術語)
# 管理文件需要 A(商業)+C(履約)+D(KPI)+F(合規)
# 全部文件共用 D(KPI)+F(合規)+I(術語)
decisions_for_doc() {
    local doc_num=$((10#$1))
    local result=""

    # 共用：D(KPI) + I(術語) — 所有文件都需要
    result="$(decisions_section D)
$(decisions_section I)"

    case "$doc_num" in
        2|3|5|6|9|10|11)  # 技術文件
            result="$(decisions_section B)
$(decisions_section E)
$(decisions_section G)
$(decisions_section H)
$result" ;;
        1|4|8|12|13)       # 管理文件
            result="$(decisions_section A)
$(decisions_section C)
$(decisions_section F)
$result" ;;
        7)                 # 使用維護手冊 — 需要技術+合規
            result="$(decisions_section B)
$(decisions_section E)
$(decisions_section F)
$result" ;;
    esac
    echo "$result"
}

# 從深度解析報告抽取指定段落
# 用法：analysis_section "三" → 回傳 ## 三、合規防護欄 的完整段落
analysis_section() {
    local section_id="$1"
    awk -v sid="$section_id" '
        $0 ~ "^## " sid "、" { found=1; print; next }
        /^## / && found { exit }
        found { print }
    ' "$ANALYSIS" 2>/dev/null
}

# 依文件類型取深度解析報告中相關段落
analysis_for_doc() {
    local doc_num=$((10#$1))
    case "$doc_num" in
        1|13) # 工作計畫書/結案報告 → KPI + 合規 + 交付
            echo "## 深度解析報告 — 核心需求與交付"
            analysis_section "一"
            echo "## 深度解析報告 — 合規防護欄"
            analysis_section "三" ;;
        2|3|10) # 系統分析/程式設計規格/程式設計書 → PRD + 硬體 + KPI
            echo "## 深度解析報告 — 硬體規格"
            analysis_section "二"
            echo "## 深度解析報告 — PRD 功能結構"
            analysis_section "四" ;;
        5|9) # 測試計畫/報告 → KPI + 合規
            echo "## 深度解析報告 — 核心需求（KPI 來源）"
            analysis_section "一"
            echo "## 深度解析報告 — 合規防護欄"
            analysis_section "三" ;;
        6|8) # 軟硬體清單/上線計畫 → 硬體 + 合規
            echo "## 深度解析報告 — 硬體規格"
            analysis_section "二"
            echo "## 深度解析報告 — 合規（產地禁令）"
            analysis_section "三" ;;
        4|12) # 教育訓練 → 核心需求（時數）
            echo "## 深度解析報告 — 核心需求（教育訓練時數）"
            analysis_section "一" | grep -A 3 '教育訓練' || true ;;
        7) # 使用維護手冊 → PRD + 硬體
            echo "## 深度解析報告 — PRD 功能結構"
            analysis_section "四" | head -80 ;;
        11) # 原始碼光碟 → PRD
            echo "## 深度解析報告 — PRD 功能結構"
            analysis_section "四" | head -50 ;;
    esac
}

# 從 assembled 文件中抽取結構化摘要（目錄 + FR/TC/KPI 關鍵行）
# 比 head -80 更精準，只抓有用的行
extract_doc_summary() {
    local file="$1"
    local max_lines="${2:-120}"
    if [ ! -f "$file" ]; then echo "(尚未產出)"; return; fi

    {
        # 取前 20 行（封面/目錄）
        head -20 "$file"
        echo "..."
        # 取所有章節標題
        { grep -n "^#" "$file" 2>/dev/null || true; } | head -40
        echo "..."
        # 取所有包含 FR/TC/KPI/ATK/AD 編號的行
        { grep -n "FR-\|TC-\|KPI\|ATK-\|AD-\|≥\|≤\|%\|85%\|99%\|5000ms\|30路" "$file" 2>/dev/null || true; } | head -60
    } | head -"$max_lines"
}


# ── 合規紅線（每個 Prompt 都注入）────────────────────────────
# 來源：decisions.yaml SECTION F + 契約格式要求
# ⚠ 如修改此處，須同步更新 decisions.yaml SECTION F 與 knowledge_card.md
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


# ═══════════════════════════════════════════════════════════════
#  Act 1：全員對齊
# ═══════════════════════════════════════════════════════════════
act1() {
    log_act "Act 1 ─ 全員對齊 (Alignment)"

    # 1-1: 契約檢查清單
    call_claude "
Role: 你是政府採購合規專家，具 20 年標案審查經驗。

Context:
## 深度解析報告 — 核心需求與交付物
$(analysis_section "一")

## 深度解析報告 — 合規防護欄
$(analysis_section "三")

## decisions.yaml — 商業決策與履約策略
$(decisions_section A | head -80)
$(decisions_section C | head -60)

Task: 請產出 contract_checklist.yaml，針對以下 13 份交付物，逐條列出契約「基本內容」欄中的每一項必須包含的子項目。

格式要求（YAML）：
每份交付物包含：
  - id: 01~13
  - name: 交付物名稱
  - deadline: D+天數
  - payment_phase: 第幾期/百分比
  - required_items: 列出每一個必須包含的子項，每項標註 source（需求書/契約段落）
  - acceptance_criteria: 驗收時怎麼判定這項有做到

預估產出約 200~300 行 YAML。

$COMPLIANCE
" "$STATE/contract_checklist.yaml"

    # 1-2: 跨文件編號預分配（參考式，不硬編數量）
    call_claude "
Role: 你是系統架構師，負責為 13 份交付文件建立統一編號體系。

Context:
## decisions.yaml — 契約硬指標與架構決策
$(decisions_section D)
$(decisions_section H)

## 契約檢查清單
$(read_file "$STATE/contract_checklist.yaml" | head -200)

## 深度解析報告 — PRD 功能結構
$(analysis_section "四")

Task: 產出 cross_reference_map.yaml，包含：

1. 功能需求編號（FR）— 依深度解析報告 PRD 功能結構，逐一列出每條需求：
   編號規則：FR-{模組}-NNN
   模組代碼：IVR, STT, TTS, LLM, AGT, QI, RPT, SMS, KB, WS（值機平台）, ADM（管理後台）
   ★ 數量不設限：依 PRD 中實際功能點決定，每個獨立功能一個 FR
   ★ 每條必須有名稱和一句話描述，不能只有編號

2. 測試案例編號（TC）— 每個 FR 對應一個 TC，編號對齊：
   TC-IVR-001 對應 FR-IVR-001，以此類推

3. 軟體模組編號（M）— 依程式設計規格：
   M-{模組}-NN（如 M-IVR-01, M-STT-01 ...）

4. 程式編號（P）— 依程式設計書：
   P-{模組}-NN 對應 M-{模組}-NN

5. 架構決策編號：從 decisions.yaml SECTION H 搬入

6. 跨文件引用對照表：
   FR → TC → 測試結果(#9) → 模組(M) → 程式(P)

$COMPLIANCE
" "$STATE/cross_reference_map.yaml"

    # 1-3: 專案知識卡（濃縮版 Context）
    call_claude "
Role: 你是首席系統架構師。

Context:
## 深度解析報告（完整）
$(cat "$ANALYSIS")

## decisions.yaml — 關鍵段落
$(decisions_section D)
$(decisions_section E)
$(decisions_section G)
$(decisions_section H)

Task: 將深度解析報告和 decisions.yaml 濃縮為 ≤2000 字的「專案知識卡」。
包含：專案一句話描述、合規紅線摘要、13項交付時程表、全部KPI數字（從 SECTION D 原封不動搬入）、硬體規格速查（從 SECTION E 原封不動搬入）、技術選型摘要、容量模型、既有系統介接清單。

★ KPI 和硬體數字必須與 decisions.yaml 完全一致，不可四捨五入或改寫。
這份知識卡將作為後續所有 Prompt 的 Context 前綴。

$COMPLIANCE
" "$STATE/knowledge_card.md"

    # 1-4: 審查委員側寫
    call_claude "
Role: 你是政府標案審查流程專家。

Context:
## 深度解析報告 — 核心需求
$(analysis_section "一" | head -60)

## 深度解析報告 — 合規防護欄
$(analysis_section "三" | head -60)

## decisions.yaml — 合規紅線
$(decisions_section F | head -40)

Task: 針對台鐵 AI 客服系統建置案（預算 2400 萬），產出 reviewer_profiles.yaml。

依照政府資訊採購案常見的審查委員組成，建立 7 位委員側寫：
每位包含：
  - name: 姓名（可為假名或依已知資訊）
  - title: 職稱
  - expertise: 專業領域（2~3 項）
  - focus_areas: 審查時最關注的面向（2~3 項）
  - likely_questions: 最可能提出的質疑方向（2~3 條）

組成建議：
  - 2 位台鐵內部主管（電務處、營業處或數位發展處）
  - 1 位資安/個資專家
  - 2 位 AI/IT 技術專家
  - 1 位政府採購/法務專家
  - 1 位使用者體驗/客服管理專家

$COMPLIANCE
" "$STATE/reviewer_profiles.yaml"

    log_done "Act 1 完成"
}


# ═══════════════════════════════════════════════════════════════
#  Act 1 → 1.5 Review Gate：人工審查三件產出
# ═══════════════════════════════════════════════════════════════
act1_review_gate() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  REVIEW GATE — Act 1 產出審查                              ║${NC}"
    echo -e "${CYAN}║  請逐一檢查以下三個檔案，確認內容正確後才會繼續執行        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local files=(
        "$STATE/contract_checklist.yaml|契約檢查清單|13 份交付物 × required_items 是否齊全（含值機平台/管理後台）"
        "$STATE/cross_reference_map.yaml|跨文件編號對照|FR/TC/M/P 編號無重複、無漏號（含 WS/ADM 模組）"
        "$STATE/knowledge_card.md|專案知識卡|KPI 數字與 decisions.yaml SECTION D 一致"
        "$STATE/reviewer_profiles.yaml|評審委員側寫|7 位委員背景、predicted_questions、defense_strategy 完整"
    )

    for entry in "${files[@]}"; do
        IFS='|' read -r fpath fname fcheck <<< "$entry"
        echo -e "  ${YELLOW}▸ $fname${NC}"
        echo "    路徑: $fpath"
        if [ -f "$fpath" ]; then
            local lines
            lines=$(wc -l < "$fpath" | tr -d ' ')
            local size
            size=$(wc -c < "$fpath" | tr -d ' ')
            echo -e "    狀態: ${GREEN}✅ 已產出${NC} ($lines 行, $size bytes)"
            echo "    審查重點: $fcheck"
        else
            echo -e "    狀態: ${RED}❌ 檔案不存在${NC}"
        fi
        echo ""
    done

    echo -e "${YELLOW}請開啟上述檔案進行 review。${NC}"
    echo -e "${YELLOW}確認無誤後輸入 y 繼續，輸入 n 中止 pipeline：${NC}"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${RED}Pipeline 中止。請修正後重新執行。${NC}"
        exit 1
    fi
    echo -e "${GREEN}Review 通過，繼續執行 Act 1.5 ...${NC}"
    echo ""
}


# ═══════════════════════════════════════════════════════════════
#  Act 1.5：預判攻擊面
# ═══════════════════════════════════════════════════════════════
act1_5() {
    log_act "Act 1.5 ─ 預判審查攻擊面 (Attack Surface)"

    require_file "$STATE/knowledge_card.md" "Act 1 知識卡"
    require_file "$STATE/cross_reference_map.yaml" "Act 1 編號表"
    require_file "$STATE/reviewer_profiles.yaml" "Act 1 委員側寫"

    call_claude "
Role: 你同時扮演以下 7 位審查委員，從每個人的專業角度提出質疑。

Context:
$(read_file "$STATE/knowledge_card.md")

## decisions.yaml — 架構決策 + 合規紅線
$(decisions_section H)
$(decisions_section F)

## 跨文件編號表 — FR 清單與模組對照
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^functional_requirements:/,/^software_modules:/' | head -500)

## 跨文件編號表 — 架構決策與統計摘要
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^architecture_decisions:/,0')

## 深度解析報告 — 合規防護欄
$(analysis_section "三")

## 深度解析報告 — 待釐清清單 ★ 每一條都是潛在攻擊面
$(analysis_section "五")

## 評審委員側寫（極重要，每位的提問方向必須對應其專業背景）
$(read_file "$STATE/reviewer_profiles.yaml")

Task: 基於 7 位委員的具體背景和專長，產出 attack_surface.yaml。
特別注意：深度解析報告「待釐清清單」中的每一項，都可能成為委員的質疑點，必須全部納入攻擊面分析。

要求：
1. 每位委員至少 2 個質疑，共至少 15 個
2. 每個質疑必須標註「最可能由哪位委員提出」
3. 嚴重度分級：致命（不回答好就被刷掉）/重要/一般

特別注意：
★ 李世芬（ISMS/PIMS/個資）— 她一定會追問個資保護和資安細節
★ 鄭國璽（電務處長）— 他一定會追問 E1/SIP 介接對現有通訊的影響
★ 陳榮彬（營業處長）— 他最在意旅客體驗和客服實際效果
★ 劉傳彥（數位發展處長）— 他在意系統穩定和保固後能否自行維運

輸出格式（YAML）：
attack_surface:
  - id: ATK-001
    severity: 致命/重要/一般
    reviewer: 最可能提問的委員姓名
    question: 委員會問的具體問題
    target_docs: [\"#2 §2.4\", \"#5 §3.2\"]
    defense: 建議的防禦策略（具體到文件中要寫什麼）

$COMPLIANCE
" "$STATE/attack_surface.yaml"

    log_done "Act 1.5 完成"
}


# ═══════════════════════════════════════════════════════════════
#  Act 2：骨架共識
# ═══════════════════════════════════════════════════════════════
act2() {
    log_act "Act 2 ─ 骨架共識 (Skeleton)"

    require_file "$STATE/knowledge_card.md" "Act 1 知識卡"
    require_file "$STATE/cross_reference_map.yaml" "Act 1 編號表"
    require_file "$STATE/attack_surface.yaml" "Act 1.5 攻擊面"

    local SHARED_CTX="
## 專案知識卡
$(read_file "$STATE/knowledge_card.md")

## 跨文件編號表 — FR 清單與模組對照
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^functional_requirements:/,/^software_modules:/' | head -500)

## 跨文件編號表 — 架構決策與統計摘要
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^architecture_decisions:/,0')

## 審查攻擊面
$(read_file "$STATE/attack_surface.yaml")

## 合規紅線
$COMPLIANCE
"

    # ── 骨架格式規範（確保 awk 可正確提取）──────────────────────
    local SKELETON_FORMAT="
## 骨架輸出格式規範（必須嚴格遵守）
每份文件的骨架必須以下列格式開頭（確保機器可解析）：

\`\`\`
## #NN 文件名稱

### 章節一 標題
- 要點1（引用 FR-XXX-NNN）
- 要點2
- 預估頁數：N 頁
- 防禦 ATK：ATK-001, ATK-003

### 章節二 標題
...
\`\`\`

★ 每份文件的第一行必須是 \`## #NN 文件名稱\`（如 \`## #02 系統分析報告書\`）
★ NN 必須是兩位數零填充（01, 02, ... 13）
★ 不同文件之間用 --- 分隔
"

    # 2-1: #1~#5 骨架
    call_claude "
Role: 你是首席系統架構師兼專案經理。

Context:
$SHARED_CTX

## 契約檢查清單（前 300 行）
$(read_file "$STATE/contract_checklist.yaml" | head -300)

$SKELETON_FORMAT

Task: 同時產出交付物 #01~#05 的骨架大綱。

每份文件的骨架須包含：
- 章節編號和標題
- 每章 3~5 個要點（具體到引用 FR/TC 編號）
- 預估頁數
- 該章應防禦的 ATK 編號（從 attack_surface.yaml 中對應）

五份文件必須在同一次呼叫中產出，確保編號互相引用正確。
例如：#02 骨架提到 FR-IVR-001，#05 骨架中必須有對應的 TC-IVR-001。
" "$STATE/skeletons/batch1_01to05.md"

    # 2-2: #6~#10 骨架
    call_claude "
Role: 你是首席系統架構師兼專案經理。

Context:
$SHARED_CTX

## 已完成骨架 #01~#05
$(read_file "$STATE/skeletons/batch1_01to05.md" | head -400)

$SKELETON_FORMAT

Task: 同時產出交付物 #06~#10 的骨架大綱。
要求同 batch1，且必須引用 #01~#05 骨架中已定義的編號。
" "$STATE/skeletons/batch2_06to10.md"

    # 2-3: #11~#13 骨架
    call_claude "
Role: 你是首席系統架構師兼專案經理。

Context:
$SHARED_CTX

## 已完成骨架 #01~#05
$(read_file "$STATE/skeletons/batch1_01to05.md" | head -300)

## 已完成骨架 #06~#10
$(read_file "$STATE/skeletons/batch2_06to10.md" | head -300)

$SKELETON_FORMAT

Task: 同時產出交付物 #11~#13 的骨架大綱。
要求同前，且引用前面骨架的編號。
" "$STATE/skeletons/batch3_11to13.md"

    # 2-4: 骨架交叉校驗
    call_claude "
Role: 你是品質管理專家。

Context:
$(read_file "$STATE/skeletons/batch1_01to05.md")
$(read_file "$STATE/skeletons/batch2_06to10.md")
$(read_file "$STATE/skeletons/batch3_11to13.md")
## 跨文件編號表 — FR 清單
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^functional_requirements:/,/^software_modules:/' | head -500)

## 跨文件編號表 — 追溯矩陣與統計
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^traceability_matrix:/,0')

Task: 校驗 13 份骨架的一致性：
1. 每個 FR-XXX-NNN（含 WS/ADM 模組）是否在 #05 骨架有對應 TC？列出遺漏
2. 每個 M-XXX-NN（含 WS/ADM 模組）是否在 #10 骨架有對應章節？列出遺漏
3. 硬體型號在 #02、#06、#08 三處是否一致？
4. KPI 數字是否與 decisions.yaml 一致？
5. ATK 攻擊面是否都有文件覆蓋？列出未防禦的 ATK

輸出：skeleton_issues.md（逐條列出問題 + 修正建議）
" "$STATE/validation/skeleton_issues.md"

    log_done "Act 2 完成"
}


# ═══════════════════════════════════════════════════════════════
#  Act 3：分章深寫
# ═══════════════════════════════════════════════════════════════

# ── 單章撰寫函式 ─────────────────────────────────────────────
write_chapter() {
    local DOC_NUM="$1"       # 例: 02
    local DOC_NAME="$2"      # 例: 系統分析報告書
    local CH_ID="$3"         # 例: ch1, ch2a, ch2b
    local CH_TITLE="$4"      # 例: 第一章 系統摘述
    local CH_TASK="$5"       # 章節具體撰寫指令
    local AGENT_ROLE="$6"    # Agent 角色
    local PREV_CHAPTERS="$7" # 同文件前面已完成章節路徑列表（空格分隔）
    local CROSS_DOC_REFS="$8" # 跨文件依賴：assembled 文件路徑列表（空格分隔）

    local OUTPUT="$STATE/chapters/${DOC_NUM}_${CH_ID}.md"
    local SKELETON_FILE=""

    # 判斷骨架在哪個 batch
    local DOC_NUM_INT=$((10#$DOC_NUM))
    if [ "$DOC_NUM_INT" -le 5 ]; then SKELETON_FILE="$STATE/skeletons/batch1_01to05.md"
    elif [ "$DOC_NUM_INT" -le 10 ]; then SKELETON_FILE="$STATE/skeletons/batch2_06to10.md"
    else SKELETON_FILE="$STATE/skeletons/batch3_11to13.md"; fi

    # 收集同文件前面章節 — 只取標題 + 最後 30 行（編號引用清單），不灌全文
    local PREV_CTX=""
    if [ -n "$PREV_CHAPTERS" ]; then
        for prev in $PREV_CHAPTERS; do
            if [ -f "$prev" ]; then
                PREV_CTX="$PREV_CTX

## 本文件前面章節摘要：$(basename "$prev")
$(head -5 "$prev")
...（中略）...
$(tail -30 "$prev")"
            fi
        done
    fi

    # 收集跨文件依賴 — 用 extract_doc_summary 抽取結構化摘要
    local CROSS_CTX=""
    if [ -n "$CROSS_DOC_REFS" ]; then
        for ref in $CROSS_DOC_REFS; do
            if [ -f "$ref" ]; then
                CROSS_CTX="$CROSS_CTX

## 跨文件參照：$(basename "$ref")（結構化摘要）
$(extract_doc_summary "$ref" 150)"
            fi
        done
    fi

    # 找出與本章相關的 ATK 條目
    local ATK_CTX=""
    if [ -f "$STATE/attack_surface.yaml" ]; then
        ATK_CTX="
## 審查攻擊面（本章應防禦的項目）
$(grep -A 5 "target_docs.*#${DOC_NUM}" "$STATE/attack_surface.yaml" 2>/dev/null || echo '(無直接相關 ATK)')"
    fi

    # 從骨架中提取本文件的段落（用標準化格式 ## #NN）
    local SKELETON_CTX=""
    local DOC_NUM_PAD
    DOC_NUM_PAD=$(printf "%02d" "$DOC_NUM_INT")
    if [ -f "$SKELETON_FILE" ]; then
        SKELETON_CTX=$(sed -n "/^## #${DOC_NUM_PAD} /,/^## #[0-9]/{/^## #[0-9][0-9] /{ /^## #${DOC_NUM_PAD} /!q; }; p;}" "$SKELETON_FILE" 2>/dev/null | head -80)
        [ -z "$SKELETON_CTX" ] && SKELETON_CTX=$(grep -A 80 "#${DOC_NUM_PAD}\|${DOC_NAME}" "$SKELETON_FILE" 2>/dev/null | head -80 || echo '(骨架段落)')
    fi

    call_claude "
Role: $AGENT_ROLE

Context:
## 專案知識卡
$(read_file "$STATE/knowledge_card.md")

## 深度解析報告（本文件相關段落）
$(analysis_for_doc "$DOC_NUM")

## decisions.yaml（本文件相關段落）
$(decisions_for_doc "$DOC_NUM")

## 本文件骨架
$SKELETON_CTX

## 跨文件編號表 — 編號體系與 FR 清單
$(head -18 "$STATE/cross_reference_map.yaml")
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^functional_requirements:/,/^software_modules:/' | head -500)
$ATK_CTX
$PREV_CTX
$CROSS_CTX

$COMPLIANCE

Task: 撰寫「${DOC_NAME}」的「${CH_TITLE}」

$CH_TASK

Output 要求:
- Markdown 格式，預估 2000~4000 字
- 引用數字必須從 decisions.yaml 讀取，不可自行編造
- 引用編號必須從 cross_reference_map.yaml 讀取
- 如有對應 ATK 攻擊面，在行文中自然地防禦（不要寫「為了回應審查委員的質疑」）
- 結尾標註本章引用的 FR/TC/AD/ATK 編號清單
- 不要重複前面章節已經詳述的內容，可引用「詳見第X章」
" "$OUTPUT"
}

# ── 單文件合併函式 ────────────────────────────────────────────
assemble_doc() {
    local DOC_NUM="$1"
    local DOC_NAME="$2"
    local ASSEMBLED="$STATE/assembled/${DOC_NUM}_${DOC_NAME}.md"

    if [ "$FORCE" -eq 0 ] && [ -f "$ASSEMBLED" ] && [ -s "$ASSEMBLED" ]; then
        log_warn "已合併: $(basename "$ASSEMBLED")（用 --force 強制重跑）"
        return 0
    fi

    log_step "合併 #${DOC_NUM} ${DOC_NAME}"

    # 檢查是否有任何章節產出
    local ch_count=0
    for ch_file in "$STATE/chapters/${DOC_NUM}_"*.md; do
        [ -f "$ch_file" ] && ch_count=$((ch_count + 1))
    done
    if [ "$ch_count" -eq 0 ]; then
        log_fail "無任何章節產出，跳過合併: #${DOC_NUM} ${DOC_NAME}"
        return 1
    fi

    # 收集所有該文件的章節，按檔名排序
    local HEADER="# ${DOC_NAME}

**案號：** L0215P2010U
**版本：** 1.0
**日期：** 中華民國 115 年

---
"
    echo "$HEADER" > "$ASSEMBLED"
    local missing=0
    for ch_file in "$STATE/chapters/${DOC_NUM}_"*.md; do
        if [ -f "$ch_file" ] && [ -s "$ch_file" ]; then
            cat "$ch_file" >> "$ASSEMBLED"
            echo -e "\n\n---\n" >> "$ASSEMBLED"
        elif [ -f "$ch_file" ]; then
            log_warn "章節為空，跳過: $(basename "$ch_file")"
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -gt 0 ]; then
        log_warn "合併完成但有 ${missing} 個空章節: $(basename "$ASSEMBLED")"
    fi
    log_done "合併完成: $(basename "$ASSEMBLED") ($(wc -c < "$ASSEMBLED" | tr -d ' ') bytes, ${ch_count} 章)"
}

# ── Act 3 主流程 ──────────────────────────────────────────────
#
# 並行策略：用 subshell (&) 包裹每個獨立文件的「章節撰寫+合併」。
# 同文件內的章節仍串行（ch2 依賴 ch1），但不同文件真正並行。
# assemble_doc 在 subshell 內同步執行，確保下游 wave 能讀到。
#
# 依賴圖：
#   Wave 1:  #01, #04, #06          （無前置依賴）
#   Wave 2:  #02, #05               （無跨 wave 依賴）
#   Wave 3a: #03 + #08              （#08 ← #06, Wave 1 已完成）
#   Wave 3b: #07 ← #03             （等 Wave 3a 的 #03 完成才啟動）
#   Wave 4:  #09 ← #05, #10 ← #02+#03
#   Wave 5:  #11 ← #10, #12 ← #04, #13 ← #09+#08
#
act3() {
    log_act "Act 3 ─ 分章深寫 (Deep Authoring)"

    require_file "$STATE/knowledge_card.md" "Act 1 知識卡"
    require_file "$STATE/cross_reference_map.yaml" "Act 1 編號表"
    require_file "$STATE/skeletons/batch1_01to05.md" "Act 2 骨架 batch1"

    local A_ARCH="你是 20 年經驗首席系統架構師，專精 VoIP/SIP 與 AI 推論系統設計。"
    local A_ML="你是 AI/ML 工程師，專精 LLM 地端部署、NVIDIA L40S GPU 推論優化、RAG 架構。"
    local A_PM="你是 PMP 認證 IT 專案經理，具 15 年政府標案履約管理經驗。"
    local A_SEC="你是 CISSP 認證資安顧問，專精弱掃、滲透測試、源碼檢測、CNS 27001。"
    local A_WRITER="你是政府資訊系統技術文件寫手，熟悉 A4 直式橫書繁中格式。"

    # ── 導出函式和變數供 subshell 使用 ──────────────────────────
    # 使用 export -f（需要 bash 4+）；macOS 自帶 bash 3.2 也支援但行為較舊
    export -f call_claude read_file write_chapter assemble_doc \
              decisions_section decisions_for_doc analysis_section analysis_for_doc \
              extract_doc_summary log_step log_warn log_done log_fail require_file
    export DIR PROJECT STATE OUT DECISIONS ANALYSIS COMPLIANCE FORCE \
           GREEN YELLOW RED CYAN NC

    # ────────────────────────────────────────────────────────────
    # Wave 1：#01 + #04 + #06（真正並行）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 1：#01 + #04 + #06（並行）"

    # #01 工作計畫書（3 章，內部串行）
    bg_run "#01 工作計畫書" bash -c '
        set -euo pipefail
        A_PM="'"$A_PM"'"
        write_chapter 01 "工作計畫書" "ch1" "第一~三章 專案概述/工作項目/時程" \
            "撰寫工作計畫書第一至三章：專案背景目標、履約範圍、WBS 工作分解（展開至三層）、RACI 矩陣、270天主時程甘特圖（四期付款對齊）、需求訪談時程 D+5~25。預估 8~12 頁。" \
            "$A_PM" "" ""
        write_chapter 01 "工作計畫書" "ch2" "第四~六章 軟體開發/系統建置/維護營運" \
            "撰寫工作計畫書第四至六章：軟體開發四階段（分析/設計/撰寫/測試）、系統建置計畫（硬體8+3台、42U機櫃、電力≥6kW）、維護營運（風險登記冊10項+影響+對策、HA雙機切換、人工客服降級方案）。預估 8~10 頁。" \
            "$A_PM" "$STATE/chapters/01_ch1.md" ""
        write_chapter 01 "工作計畫書" "ch3" "第七~八章+附件 教育訓練/資安保密" \
            "撰寫工作計畫書第七至八章及附件：教育訓練初步規劃（值機≥36hr+管理≥18hr=54hr）、CNS 27001合規、保密同意書/切結書流程、資料所在地聲明、跨境傳輸切結書附件。預估 4~6 頁。" \
            "$A_PM" "$STATE/chapters/01_ch1.md $STATE/chapters/01_ch2.md" ""
        assemble_doc 01 "工作計畫書"
    '

    # #04 教育訓練計畫書（1 章）
    bg_run "#04 教育訓練計畫書" bash -c '
        set -euo pipefail
        A_PM="'"$A_PM"'"
        write_chapter 04 "教育訓練計畫書" "full" "完整內容" \
            "教育訓練計畫：總時數≥54hr、值機人員≥36hr（分Pilot 12hr+正式24hr分4批）、系統管理者≥18hr（Pilot 6hr+正式12hr）。課程大綱、教材規劃（操作手冊+影片）、現場實機操作為主、線上僅不可抗力備案。排程 D+200~240。預估 6~8 頁。" \
            "$A_PM" "" ""
        assemble_doc 04 "教育訓練計畫書"
    '

    # #06 軟硬體清單（1 章）
    bg_run "#06 軟硬體清單" bash -c '
        set -euo pipefail
        A_ARCH="'"$A_ARCH"'"
        write_chapter 06 "軟硬體清單及系統架構圖" "full" "完整內容" \
            "軟硬體交貨清單對照表（契約規格vs實配，逐台逐項）、產品規格佐證資料清單（驗證方式：原廠型錄/產地證明/序號）、軟體授權證明（全開源清單+License類型）、第三方元件列冊（名稱/版本/License/是否含大陸元件）、系統架構圖（邏輯+實體+網路拓撲）。品牌推薦 Dell/HPE，嚴禁大陸品牌。預估 10~15 頁。" \
            "$A_ARCH" "" ""
        assemble_doc 06 "軟硬體清單及系統架構圖"
    '

    bg_wait
    log_done "Wave 1 完成"

    # ────────────────────────────────────────────────────────────
    # Wave 2：#02 + #05（真正並行）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 2：#02 + #05（並行）"

    bg_run "#02 系統分析報告書" bash -c '
        set -euo pipefail
        A_ARCH="'"$A_ARCH"'"; A_ML="'"$A_ML"'"
        write_chapter 02 "系統分析報告書" "ch1" "第一章 系統摘述" \
            "撰寫系統摘述：六層式架構說明、邏輯/實體架構圖描述、適用軟硬體環境、使用者角色（旅客/值機員25席/督導2席/管理者/外點225人）、效益分析、現有系統限制與解決方案。預估 4~6 頁。" \
            "$A_ARCH" "" ""
        write_chapter 02 "系統分析報告書" "ch2a" "第二章(A) AI-IVR/STT/TTS 功能需求" \
            "撰寫 AI-IVR、STT、TTS 的完整功能需求。每項 FR 包含：編號、名稱、描述（正常+例外流程）、輸入/輸出、處理邏輯、優先級、需求書溯源。引用 cross_reference_map 編號。預估 8~12 頁。" \
            "$A_ARCH" "$STATE/chapters/02_ch1.md" ""
        write_chapter 02 "系統分析報告書" "ch2b" "第二章(B) LLM/AI-Agent 功能需求" \
            "撰寫 LLM、AI-Agent 的完整功能需求。格式同前。注意 Agent 功能需引用 LLM 的 FR 編號（如 FR-AGT-003 的意圖辨識引用 FR-LLM-002）。預估 8~12 頁。" \
            "$A_ML" "$STATE/chapters/02_ch1.md $STATE/chapters/02_ch2a.md" ""
        write_chapter 02 "系統分析報告書" "ch2c" "第二章(C) QI/報表/SMS/知識庫 功能需求" \
            "撰寫 QI、報表、SMS、知識庫的完整功能需求。格式同前。15分鐘錄音→5分鐘完成、保固期≥10個客製報表、SMS紀錄保存≥5年、雙備援收發裝置。預估 6~10 頁。" \
            "$A_ARCH" "$STATE/chapters/02_ch1.md $STATE/chapters/02_ch2a.md $STATE/chapters/02_ch2b.md" ""
        write_chapter 02 "系統分析報告書" "ch3" "第三章 系統介面需求" \
            "撰寫內部介面（AI-IVR↔LLM gRPC ≤2500ms、AI-Agent↔LLM REST、QI↔LLM 批次、向量DB ≤200ms）、外部介面（MES SIP/RTP、CRM GW REST、E1 GW SIP Trunk、WebCall SBC、類比GW、AD/郵件、企業入口、訂票/時刻表API）、使用者介面（值機平台含AI輔助側邊欄、管理後台、旅客RWD數位客服）。預估 5~8 頁。" \
            "$A_ARCH" "$STATE/chapters/02_ch1.md" ""
        write_chapter 02 "系統分析報告書" "ch4" "第四章 非功能需求" \
            "撰寫效能（延遲預算表 STT≤800ms/LLM≤2500ms/TTS≤700ms/端到端≤5000ms）、可用性（99%/季、HA≤30s、單日≤4hr）、安全性（CNS 27001逐項對照）、擴展性（GPU擴充路徑）、相容性（Edge/Chrome/Firefox/Safari+RWD）、資料保存（日誌≥6月/SMS≥5年）。預估 5~8 頁。" \
            "$A_ARCH" "$STATE/chapters/02_ch1.md" ""
        write_chapter 02 "系統分析報告書" "ch5" "第五章 需求追溯矩陣" \
            "產出需求追溯矩陣表格：需求書段落→FR編號→TC編號→模組編號。必須從 cross_reference_map.yaml 讀取所有編號，確保 100% 覆蓋。預估 3~5 頁。" \
            "$A_ARCH" "$STATE/chapters/02_ch2a.md $STATE/chapters/02_ch2b.md $STATE/chapters/02_ch2c.md" ""
        assemble_doc 02 "系統分析報告書"
    '

    bg_run "#05 測試計畫書" bash -c '
        set -euo pipefail
        A_SEC="'"$A_SEC"'"
        write_chapter 05 "測試計畫書" "ch1" "第一~二章 策略/功能測試" \
            "測試策略（單元/整合/系統/UAT/壓力/資安六層）、測試環境規劃（VLAN隔離）。功能測試：AI-IVR 200題正確率≥85%、AI-Agent 200題≥85%、STT 200音檔≥85%、後送分類200筆≥85%、QI 15min→5min。引用 TC 編號。預估 6~8 頁。" \
            "$A_SEC" "" ""
        write_chapter 05 "測試計畫書" "ch2" "第三章 壓力測試" \
            "30路IVR+30路Agent同時並行、HA切換測試（模擬主機當機≤30秒）、72小時不間斷穩定性測試、GPU記憶體壓力測試。預估 3~5 頁。" \
            "$A_SEC" "$STATE/chapters/05_ch1.md" ""
        write_chapter 05 "測試計畫書" "ch3" "第四章 資安檢測" \
            "弱點掃描（Nessus, 全伺服器+網路）、滲透測試（OWASP Top 10+API安全+SIP協定攻擊）、源碼檢測（SAST+SCA第三方元件）、資安防護基準查核表對照。由資安分包廠商執行。預估 4~6 頁。" \
            "$A_SEC" "$STATE/chapters/05_ch1.md $STATE/chapters/05_ch2.md" ""
        write_chapter 05 "測試計畫書" "ch4" "第五~六章 驗收標準/時程" \
            "各KPI pass/fail判定規則、缺陷分級（Critical/Major/Minor/Cosmetic）、驗收不通過改正流程、測試時程甘特圖。預估 3~5 頁。" \
            "$A_SEC" "$STATE/chapters/05_ch1.md" ""
        assemble_doc 05 "測試計畫書"
    '

    bg_wait
    log_done "Wave 2 完成"

    # ────────────────────────────────────────────────────────────
    # Wave 3a：#03 + #08（並行）— #03 必須同步完成（#07 依賴它）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 3a：#03 + #08（並行）"

    bg_run "#03 程式設計規格" bash -c '
        set -euo pipefail
        A_ML="'"$A_ML"'"
        write_chapter 03 "程式設計規格報告書" "ch1" "第一~三章 範圍/方法工具/架構" \
            "系統範圍目標、開發方法工具（Python/FastAPI/vLLM/faster-whisper/Coqui/Qdrant/React/PostgreSQL/Docker Compose）、系統組織架構與軟硬體環境對映。預估 4~6 頁。" \
            "$A_ML" "" ""
        write_chapter 03 "程式設計規格報告書" "ch2" "第四章 系統流程圖" \
            "AI-IVR語音處理流程（含SIP信令PJSIP）、AI-Agent文字處理流程、AI-QI質檢批次流程、真人轉接流程（含知識輔助）、SMS收發處理流程。每個流程含完整步驟和延遲預算。預估 6~8 頁。" \
            "$A_ML" "$STATE/chapters/03_ch1.md" ""
        write_chapter 03 "程式設計規格報告書" "ch3" "第五章 軟體元件設計" \
            "STT模組（Streaming ASR Pipeline）、TTS模組（Neural TTS Pipeline）、LLM推論模組（vLLM Serving）、RAG檢索模組（Embedding+VectorSearch+Reranker）、對話管理模組（Session Manager+Context Window）、質檢分析模組（Audio Pipeline+Scoring Engine）。每個模組含 API 定義。預估 8~12 頁。" \
            "$A_ML" "$STATE/chapters/03_ch1.md $STATE/chapters/03_ch2.md" ""
        write_chapter 03 "程式設計規格報告書" "ch4" "第六~七章 UI設計/資料庫設計" \
            "值機平台UI Wireframe描述（含AI知識輔助側邊欄）、管理後台UI、旅客端RWD UI。PostgreSQL Schema（對話紀錄/使用者/權限/後送案件）、Qdrant向量Schema、TimescaleDB時序Schema、Redis快取策略。預估 6~8 頁。" \
            "$A_ML" "$STATE/chapters/03_ch1.md $STATE/chapters/03_ch2.md $STATE/chapters/03_ch3.md" ""
        write_chapter 03 "程式設計規格報告書" "ch5" "第八~九章 備份安全/規格追溯" \
            "備份策略（RPO/RTO）、加密（傳輸中TLS+靜態AES-256）、RBAC存取控制模型。規格追溯表：FR→模組→API→資料表→TC。預估 4~6 頁。" \
            "$A_ML" "$STATE/chapters/03_ch1.md" ""
        assemble_doc 03 "程式設計規格報告書"
    '

    bg_run "#08 上線計畫書" bash -c '
        set -euo pipefail
        A_PM="'"$A_PM"'"
        write_chapter 08 "系統上線執行計畫書" "ch1" "第一~二章 工作項目/時程/範圍" \
            "上線工作項目清單、時程規劃、上線範圍（AI-IVR+AI-Agent+AI-QI+SMS+報表+管理後台）、上線內容。預估 3~5 頁。" \
            "$A_PM" "" \
            "$STATE/assembled/06_軟硬體清單及系統架構圖.md"
        write_chapter 08 "系統上線執行計畫書" "ch2" "第三~四章 實施方法/版本說明" \
            "實施方法（灰度上線/全量切換）、執行步驟（含回滾計畫）、軟體版本說明、上線後觀察期計畫。預估 3~5 頁。" \
            "$A_PM" "$STATE/chapters/08_ch1.md" \
            "$STATE/assembled/06_軟硬體清單及系統架構圖.md"
        assemble_doc 08 "系統上線執行計畫書"
    '

    bg_wait
    log_done "Wave 3a 完成"

    # ────────────────────────────────────────────────────────────
    # Wave 3b：#07（串行 — 依賴 #03 已完成的 assembled）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 3b：#07（依賴 #03）"

    write_chapter 07 "軟體使用及維護手冊" "ch1" "第一~二章 架構摘述/流程圖" \
        "系統架構摘述、系統流程圖、各等級使用者的存取功能與限制。預估 3~5 頁。" \
        "$A_WRITER" "" \
        "$STATE/assembled/03_程式設計規格報告書.md"

    write_chapter 07 "軟體使用及維護手冊" "ch2" "第三章 操作方法步驟畫面" \
        "值機人員操作（接聽/轉接/AI輔助/質檢查看）、管理者操作（知識庫管理/報表/權限/質檢規則）、旅客端操作（數位客服/SMS）。含畫面描述和步驟。常見問題FAQ。預估 8~12 頁。" \
        "$A_WRITER" "$STATE/chapters/07_ch1.md" \
        "$STATE/assembled/03_程式設計規格報告書.md"

    write_chapter 07 "軟體使用及維護手冊" "ch3" "第四章 備份與下載" \
        "系統備份操作步驟與時機、災難復原SOP、手冊網站下載方式。預估 2~3 頁。" \
        "$A_WRITER" "$STATE/chapters/07_ch1.md $STATE/chapters/07_ch2.md" \
        ""

    assemble_doc 07 "軟體使用及維護手冊"
    log_done "Wave 3b 完成"

    # ────────────────────────────────────────────────────────────
    # Wave 4：#09 + #10（真正並行）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 4：#09 + #10（並行）"

    bg_run "#09 測試報告書" bash -c '
        set -euo pipefail
        A_SEC="'"$A_SEC"'"
        write_chapter 09 "測試報告書" "ch1" "第一章 功能測試結果" \
            "UAT測試紀錄：AI-IVR 200題測試結果（正確率≥85%）、AI-Agent 200題、STT 200音檔、後送分類200筆。以表格呈現每項TC的pass/fail。必須引用 #05 測試計畫定義的 TC 編號和測試方法。預估 5~8 頁。" \
            "$A_SEC" "" \
            "$STATE/assembled/05_測試計畫書.md"
        write_chapter 09 "測試報告書" "ch2" "第二章 壓力測試結果" \
            "30路並行壓測結果（延遲/吞吐量/GPU使用率）、HA切換測試結果（切換時間實測）、72小時穩定性測試報告。必須引用 #05 定義的壓力測試場景。預估 3~5 頁。" \
            "$A_SEC" "$STATE/chapters/09_ch1.md" \
            "$STATE/assembled/05_測試計畫書.md"
        write_chapter 09 "測試報告書" "ch3" "第三章 資安檢測報告" \
            "弱點掃描報告書（發現/修復/殘留風險）、滲透測試報告書（OWASP Top 10結果）、源碼檢測報告書（SAST/SCA結果）。由資安分包廠商執行，本章為報告彙整。必須引用 #05 定義的資安檢測方法與排程。預估 4~6 頁。" \
            "$A_SEC" "$STATE/chapters/09_ch1.md $STATE/chapters/09_ch2.md" \
            "$STATE/assembled/05_測試計畫書.md"
        assemble_doc 09 "測試報告書"
    '

    bg_run "#10 程式設計書" bash -c '
        set -euo pipefail
        A_ML="'"$A_ML"'"
        write_chapter 10 "程式設計書" "ch1" "第一章 程式功能清單" \
            "程式功能清單表格：程式代號(P-XXX-NN)、程式名稱、所屬功能/作業(FR-XXX-NNN)、所屬模組(M-XXX-NN)。依代號排列。必須與 #02 的 FR 編號和 #03 的模組編號完全對齊。預估 3~5 頁。" \
            "$A_ML" "" \
            "$STATE/assembled/02_系統分析報告書.md $STATE/assembled/03_程式設計規格報告書.md"
        write_chapter 10 "程式設計書" "ch2" "第二章 LLM/RAG 模組程式說明" \
            "LLM推論模組(P-LLM-*)和RAG檢索模組(P-RAG-*)的程式功能說明、處理邏輯（輸入/輸出/處理程序/存取資料/計算條件）、使用資料庫表格及欄位、使用元件、使用介面。預估 6~8 頁。" \
            "$A_ML" "$STATE/chapters/10_ch1.md" \
            "$STATE/assembled/02_系統分析報告書.md $STATE/assembled/03_程式設計規格報告書.md"
        write_chapter 10 "程式設計書" "ch3" "第三章 STT/TTS 模組程式說明" \
            "STT模組(P-STT-*)和TTS模組(P-TTS-*)的程式說明。格式同前。含faster-whisper和Coqui XTTS-v2的整合細節。預估 4~6 頁。" \
            "$A_ML" "$STATE/chapters/10_ch1.md $STATE/chapters/10_ch2.md" \
            "$STATE/assembled/03_程式設計規格報告書.md"
        write_chapter 10 "程式設計書" "ch4" "第四章 Agent/QI 模組程式說明" \
            "AI-Agent模組(P-AGT-*)和AI-QI模組(P-QI-*)的程式說明。格式同前。含向量DB查詢、質檢評分引擎、SMS處理邏輯。預估 5~8 頁。" \
            "$A_ML" "$STATE/chapters/10_ch1.md $STATE/chapters/10_ch2.md $STATE/chapters/10_ch3.md" \
            "$STATE/assembled/03_程式設計規格報告書.md"
        write_chapter 10 "程式設計書" "ch5" "第五章 軟體整合說明" \
            "本系統與其他系統的整合：與MES Server(SIP/RTP)、CRM Gateway(REST)、E1 VoIP GW(SIP Trunk)、WebCall SBC、AD/郵件系統、訂票/時刻表系統的整合機制與介面呼叫說明。預估 3~5 頁。" \
            "$A_ML" "$STATE/chapters/10_ch1.md" \
            "$STATE/assembled/02_系統分析報告書.md"
        assemble_doc 10 "程式設計書"
    '

    bg_wait
    log_done "Wave 4 完成"

    # ────────────────────────────────────────────────────────────
    # Wave 5：#11 + #12 + #13（真正並行）
    # ────────────────────────────────────────────────────────────
    log_step "Wave 5：#11 + #12 + #13（並行）"

    bg_run "#11 原始碼清單" bash -c '
        set -euo pipefail
        A_ML="'"$A_ML"'"
        write_chapter 11 "原始程式碼光碟清單" "full" "完整內容" \
            "系統原始程式目錄結構、執行碼清單、API清單（含endpoint/method/參數/回傳格式）、第三方元件版本清單、光碟內容說明。預估 4~6 頁。" \
            "$A_ML" "" \
            "$STATE/assembled/10_程式設計書.md"
        assemble_doc 11 "原始程式碼光碟清單"
    '

    bg_run "#12 教育訓練報告" bash -c '
        set -euo pipefail
        A_PM="'"$A_PM"'"
        write_chapter 12 "教育訓練執行報告書" "full" "完整內容" \
            "依 #04 教育訓練計畫書的規劃撰寫執行紀錄：Pilot訓練（D+200~220, 種子5人+管理2人）、正式訓練（D+220~240, 25人分4批）。含課程表、簽到表模板、學員回饋摘要、訓練成效評估。課程名稱和時數必須與 #04 一致。預估 5~8 頁。" \
            "$A_PM" "" \
            "$STATE/assembled/04_教育訓練計畫書.md"
        assemble_doc 12 "教育訓練執行報告書"
    '

    bg_run "#13 結案報告" bash -c '
        set -euo pipefail
        A_PM="'"$A_PM"'"
        write_chapter 13 "結案報告" "full" "完整內容" \
            "工作項目完成對照表（13項×交付日期×審查結果）、執行過程紀要、KPI執行績效（實測vs目標，數字必須與 #09 一致）、系統上線執行報告（上線日期/切換過程/穩定性觀察，與 #08 一致）、經驗學習、建議事項。預估 6~8 頁。" \
            "$A_PM" "" \
            "$STATE/assembled/09_測試報告書.md $STATE/assembled/08_系統上線執行計畫書.md"
        assemble_doc 13 "結案報告"
    '

    bg_wait
    log_done "Wave 5 完成"
    log_done "Act 3 完成（共 37 章 + 13 份合併）"
}


# ═══════════════════════════════════════════════════════════════
#  Act 4：交叉校驗
# ═══════════════════════════════════════════════════════════════
act4() {
    log_act "Act 4 ─ 交叉校驗 (Cross-Validation)"

    # 4-A: 合規閘門（逐份）
    log_step "4-A 合規閘門"
    for assembled_file in "$STATE/assembled/"*.md; do
        [ ! -f "$assembled_file" ] && continue
        # 跳過 fixed_ 前綴的檔案
        [[ "$(basename "$assembled_file")" == fixed_* ]] && continue

        local fname=$(basename "$assembled_file")
        local gate_file="$STATE/validation/gate_${fname}"

        if [ "$FORCE" -eq 0 ] && [ -f "$gate_file" ]; then
            log_warn "已審查: ${fname}（用 --force 強制重跑）"
            continue
        fi

        # ★ Shell 全文預掃：簡體字、大陸品牌等可自動檢測的項目
        local prescan_result=""
        # 簡體字快速檢查（常見簡體字樣本）
        local cn_hits
        cn_hits=$(grep -n '华为\|阿里\|腾讯\|百度\|中兴\|浪潮\|紫光\|联想\|数据\|运行\|处理\|应用\|服务器\|软件\|硬件\|网络\|系统\|开发\|测试\|项目\|实现\|设计\|规范\|报告' "$assembled_file" 2>/dev/null | head -20 || true)
        if [ -n "$cn_hits" ]; then
            prescan_result="$prescan_result
### Shell 預掃：疑似簡體中文/大陸品牌（全文掃描結果）
$cn_hits"
        fi
        # 大陸品牌全文掃描
        local brand_hits
        brand_hits=$(grep -ni 'Huawei\|华为\|華為\|ZTE\|中兴\|中興\|Lenovo\|联想\|聯想\|Inspur\|浪潮\|H3C\|新华三\|新華三\|Alibaba Cloud\|阿里云\|阿里雲\|Tencent\|腾讯\|騰訊\|Baidu\|百度\|Hikvision\|海康\|Dahua\|大华\|大華' "$assembled_file" 2>/dev/null | head -20 || true)
        if [ -n "$brand_hits" ]; then
            prescan_result="$prescan_result
### Shell 預掃：大陸品牌（全文掃描結果）
$brand_hits"
        fi

        call_claude "
Role: 你是政府採購合規專家。

## 合規基準（來自深度解析報告，作為審查依據）
$(analysis_section "三")

## 合規紅線（來自 decisions.yaml）
$(decisions_section F)

${prescan_result:+## Shell 自動預掃結果（全文掃描，以下為確認命中的行）
$prescan_result
}

Task: 依據上方「合規基準」逐條審查以下文件。

檢查項目：
1. 無簡體中文字元  2. 無大陸慣用語  3. 無大陸品牌
4. 無跨境傳輸      5. CNS 27001     6. 人員國籍
7. 個資保護        8. 授權續用       9. 異常切換人工

★ 注意：Shell 預掃已對全文做了簡體字/品牌掃描，上方有結果。
★ 以下為文件內容（若超過 2000 行則截斷，但預掃已覆蓋全文）。

文件：
$(head -2000 "$assembled_file")

輸出：
| # | 檢查項 | PASS/FAIL | 問題位置 | 修正建議 |
最後一行判定：**PASS** 或 **FAIL**
" "$gate_file"

        # 合規 FAIL → 備份 + 自動修正
        if grep -q '\*\*FAIL\*\*' "$gate_file" 2>/dev/null; then
            log_warn "合規 FAIL: $fname → 備份並啟動自動修正"
            # ★ 先備份再修正
            cp "$assembled_file" "${assembled_file}.bak"

            # ★ Diff-based 合規修正：Claude 只輸出修改指令，不重寫全文
            local fix_file="$STATE/validation/fix_${fname}"
            call_claude "
Role: 你是合規修正專家。

## 合規審查結果（含具體問題和修正建議）
$(cat "$gate_file")

$COMPLIANCE

Task: 依據審查結果中每一條 FAIL 的「修正建議」，產出修正指令（不要輸出完整文件）。

## 輸出格式（每處修正一個區塊）：
\`\`\`
### 修正 N：[問題描述]
原文：<<<
要被替換的原始文字（完整複製，含前後幾個字供定位）
>>>
改為：<<<
修正後的文字
>>>
\`\`\`

★ 原文必須從下方文件中完整精確複製。
★ 如果無需修正，輸出「無需修正」。

文件內容：
$(cat "$assembled_file")
" "$fix_file"

            # 應用 patch
            if [ -s "$fix_file" ] && ! grep -q '無需修正' "$fix_file" 2>/dev/null; then
                python3 - "$fix_file" "$assembled_file" <<'PYEOF'
import re, sys

patch = open(sys.argv[1], encoding='utf-8').read()
doc = open(sys.argv[2], encoding='utf-8').read()

blocks = re.findall(r'原文：<<<\n(.*?)\n>>>\n改為：<<<\n(.*?)\n>>>', patch, re.DOTALL)

changes = 0
for old, new in blocks:
    old = old.strip()
    new = new.strip()
    if old and old in doc:
        doc = doc.replace(old, new, 1)
        changes += 1

if changes > 0:
    open(sys.argv[2], 'w', encoding='utf-8').write(doc)
print(f'applied {changes}/{len(blocks)} patches')
PYEOF
                [ $? -eq 0 ] && log_done "合規修正完成: $fname" \
                || log_warn "合規修正 patch 失敗，保留原檔: $fname"
            fi
        else
            log_done "合規 PASS: $fname"
        fi
    done

    # 4-B: 跨文件一致性 — 用 grep 抽取關鍵行而非 head-80
    log_step "4-B 跨文件一致性"
    call_claude "
Role: 你是品質管理專家。

Context:
## 跨文件編號表 — FR 清單
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^functional_requirements:/,/^software_modules:/' | head -500)

## 跨文件編號表 — 統計摘要
$(read_file "$STATE/cross_reference_map.yaml" | awk '/^summary:/,0')

## decisions.yaml — 契約硬指標與硬體規格（一致性比對基準）
$(decisions_section D)
$(decisions_section E)

## 各文件結構化摘要（章節標題 + FR/TC/KPI 關鍵行）
$(for f in "$STATE/assembled/"*.md; do
    [[ "$(basename "$f")" == fixed_* ]] && continue
    [ -f "$f" ] || continue
    echo "=== $(basename "$f") ==="
    extract_doc_summary "$f" 120
    echo
done)

Task: 檢查跨文件一致性：
1. 每個 FR 是否在 #05 有 TC？在 #09 有結果？列出遺漏
2. 每個模組 M 是否在 #10 有程式說明？列出遺漏
3. KPI 數字在所有文件中是否一致？列出矛盾（以 decisions.yaml SECTION D 為唯一正確來源）
4. 硬體型號/數量在 #02、#06、#08 是否一致？（以 SECTION E 為唯一正確來源）
5. 術語使用是否統一？

輸出：逐條列出問題 + 具體修正指令（指明哪份文件哪個段落改什麼）
" "$STATE/validation/cross_check.md"

    # 4-C: 格式統一
    log_step "4-C 格式統一"
    call_claude "
Role: 你是技術文件格式審查員。

Context:
$(for f in "$STATE/assembled/"*.md; do
    [[ "$(basename "$f")" == fixed_* ]] && continue
    [ -f "$f" ] || continue
    echo "=== $(basename "$f") 前 30 行 ==="
    head -30 "$f"
    echo
done)

Task: 檢查 13 份文件的格式一致性：
1. 版本號/案號/日期是否 13 份一致？
2. 編號是否連續無跳號？
3. 「詳見第X章」引用是否指向存在的章節？
4. 用語統一：是否全部用「立約商」而非混用「廠商/我方」？
5. 所有表格是否有表頭？

輸出：問題清單 + 修正指令
" "$STATE/validation/format_check.md"

    # 4-D: 審查委員模擬（確認防禦到位）— 用結構化摘要
    log_step "4-D 審查委員模擬（確認防禦到位）"
    call_claude "
Role: 你是台鐵標案資深審查委員。

Context:
## 原始攻擊面
$(read_file "$STATE/attack_surface.yaml")

## 各文件結構化摘要（章節標題 + 關鍵防禦行）
$(for f in "$STATE/assembled/"*.md; do
    [[ "$(basename "$f")" == fixed_* ]] && continue
    [ -f "$f" ] || continue
    echo "=== $(basename "$f") ==="
    extract_doc_summary "$f" 150
    echo
done)

Task:
1. 逐條檢查 attack_surface.yaml 中的每個 ATK，確認每個是否已在文件中被充分防禦
2. 如有未防禦或防禦不足的，指出具體位置和補強建議
3. 是否有新的攻擊面在原始列表之外？如有，列出

輸出格式：
| ATK-ID | 問題 | 防禦狀態 | 位置 | 補強建議 |
" "$STATE/validation/defense_check.md"

    log_done "Act 4 完成"
}


# ═══════════════════════════════════════════════════════════════
#  Act 5：統稿定版
# ═══════════════════════════════════════════════════════════════
act5() {
    log_act "Act 5 ─ 統稿定版 (Final Assembly)"

    # ── 5-1: 修正輪 — 針對 Act 4 發現的具體問題逐份修正 ────────
    log_step "5-1 修正輪（Act 4 問題修正）"

    for assembled_file in "$STATE/assembled/"*.md; do
        [ ! -f "$assembled_file" ] && continue
        [[ "$(basename "$assembled_file")" == fixed_* ]] && continue

        local fname=$(basename "$assembled_file")
        local fixed_file="$STATE/assembled/fixed_${fname}"

        if [ "$FORCE" -eq 0 ] && [ -f "$fixed_file" ]; then
            log_warn "已修正: ${fname}（用 --force 強制重跑）"
            continue
        fi

        # 收集與本文件相關的所有 Act 4 問題
        local DOC_ISSUES=""

        # 合規閘門結果
        local gate_file="$STATE/validation/gate_${fname}"
        if [ -f "$gate_file" ] && grep -q '\*\*FAIL\*\*' "$gate_file" 2>/dev/null; then
            DOC_ISSUES="$DOC_ISSUES
### 合規閘門結果（仍有 FAIL）
$(cat "$gate_file")"
        fi

        # 從跨文件一致性中篩出與本文件相關的問題
        if [ -f "$STATE/validation/cross_check.md" ]; then
            local cross_hits
            cross_hits=$(grep -i "$(echo "$fname" | sed 's/\.md$//' | sed 's/^[0-9]*_//')" "$STATE/validation/cross_check.md" 2>/dev/null || true)
            if [ -n "$cross_hits" ]; then
                DOC_ISSUES="$DOC_ISSUES
### 跨文件一致性問題
$cross_hits"
            fi
        fi

        # 從格式檢查中篩出相關問題
        if [ -f "$STATE/validation/format_check.md" ]; then
            local fmt_hits
            fmt_hits=$(grep -i "$(echo "$fname" | sed 's/\.md$//' | sed 's/^[0-9]*_//')" "$STATE/validation/format_check.md" 2>/dev/null || true)
            if [ -n "$fmt_hits" ]; then
                DOC_ISSUES="$DOC_ISSUES
### 格式問題
$fmt_hits"
            fi
        fi

        # 從防禦檢查中篩出相關問題
        if [ -f "$STATE/validation/defense_check.md" ]; then
            local def_hits
            def_hits=$(grep -i "$(echo "$fname" | sed 's/\.md$//' | sed 's/^[0-9]*_//')" "$STATE/validation/defense_check.md" 2>/dev/null || true)
            if [ -n "$def_hits" ]; then
                DOC_ISSUES="$DOC_ISSUES
### 防禦缺口
$def_hits"
            fi
        fi

        # 如果沒有任何問題，直接複製
        if [ -z "$DOC_ISSUES" ]; then
            cp "$assembled_file" "$fixed_file"
            log_done "無問題，直接通過: $fname"
            continue
        fi

        # ★ Diff-based 修正：Claude 只輸出修改指令，不重寫全文
        local patch_file="$STATE/validation/patch_${fname}"
        call_claude "
Role: 你是技術文件修正專家。只修問題，不改其他。

## 本文件的具體問題清單
$DOC_ISSUES

$COMPLIANCE

Task: 依據上方問題清單，產出修正指令（不要輸出完整文件）。

## 輸出格式（每處修正一個區塊）：
\`\`\`
### 修正 N：[問題描述]
位置：約第 XX 行 / 章節標題
原文：<<<
要被替換的原始文字（完整複製，含前後幾個字供定位）
>>>
改為：<<<
修正後的文字
>>>
\`\`\`

★ 如果無需修正，輸出「無需修正」。
★ 原文必須完整精確，以便 sed 替換。

文件內容：
$(cat "$assembled_file")
" "$patch_file"

        # 應用 patch：複製原檔 → 逐條替換
        cp "$assembled_file" "$fixed_file"

        if [ -s "$patch_file" ] && ! grep -q '無需修正' "$patch_file" 2>/dev/null; then
            # 提取 原文/改為 配對並用 python 安全替換（避免 sed 特殊字元問題）
            # 路徑透過 sys.argv 傳入，避免單引號注入
            python3 - "$patch_file" "$fixed_file" <<'PYEOF'
import re, sys

patch = open(sys.argv[1], encoding='utf-8').read()
doc = open(sys.argv[2], encoding='utf-8').read()

# 解析 原文:<<< ... >>> 改為:<<< ... >>> 配對
blocks = re.findall(r'原文：<<<\n(.*?)\n>>>\n改為：<<<\n(.*?)\n>>>', patch, re.DOTALL)

changes = 0
for old, new in blocks:
    old = old.strip()
    new = new.strip()
    if old and old in doc:
        doc = doc.replace(old, new, 1)
        changes += 1

if changes > 0:
    open(sys.argv[2], 'w', encoding='utf-8').write(doc)
print(f'applied {changes}/{len(blocks)} patches')
PYEOF
            [ $? -eq 0 ] && log_done "Patch 應用完成: $fname" \
            || log_warn "Patch 應用失敗，保留原版: $fname"
        else
            log_done "無需修正: $fname"
        fi
    done

    # ── 5-2: 潤飾輪 — shell 直接替換已知模式 + Claude 處理剩餘 ──
    log_step "5-2 潤飾輪（語氣/目錄/格式）"

    for assembled_file in "$STATE/assembled/"*.md; do
        [ ! -f "$assembled_file" ] && continue
        [[ "$(basename "$assembled_file")" == fixed_* ]] && continue

        local fname=$(basename "$assembled_file")
        local fixed_file="$STATE/assembled/fixed_${fname}"
        local final_file="$OUT/${fname}"

        if [ "$FORCE" -eq 0 ] && [ -f "$final_file" ]; then
            log_warn "已定版: ${fname}（用 --force 強制重跑）"
            continue
        fi

        # 讀修正後版本（如果有），否則讀原版
        local source_file="$fixed_file"
        [ ! -f "$source_file" ] && source_file="$assembled_file"

        cp "$source_file" "$final_file"

        # Step A: Shell 直接替換已知模式（不需 Claude，100% 可靠）
        local change_count=0

        # 語氣統一：我方/本公司/廠商 → 立約商（但保留「廠商人員」等複合詞不改）
        if grep -q '我方\|本公司' "$final_file" 2>/dev/null; then
            sed -i '' 's/我方/立約商/g; s/本公司/立約商/g' "$final_file" 2>/dev/null || \
            sed -i  's/我方/立約商/g; s/本公司/立約商/g' "$final_file" 2>/dev/null
            change_count=$((change_count + 1))
        fi

        # 移除修正輪附註
        if grep -q '已修正：' "$final_file" 2>/dev/null; then
            sed -i '' '/已修正：/d' "$final_file" 2>/dev/null || \
            sed -i  '/已修正：/d' "$final_file" 2>/dev/null
            change_count=$((change_count + 1))
        fi

        # Step B: 生成目錄（純 shell，不依賴 Claude 或 perl）
        local toc_file
        toc_file=$(mktemp)
        {
            echo "## 目錄"
            echo ""
            (grep "^## \|^### " "$final_file" 2>/dev/null || true) | while IFS= read -r heading; do
                echo "- ${heading}"
            done | head -30
            echo ""
            echo "---"
            echo ""
        } > "$toc_file"

        # 在第一個 --- 後插入目錄（用 awk 替代 perl，避免特殊字元問題）
        if grep -q '^---$' "$final_file" 2>/dev/null; then
            awk -v tocfile="$toc_file" '
                /^---$/ && !inserted {
                    print
                    while ((getline line < tocfile) > 0) print line
                    close(tocfile)
                    inserted=1
                    next
                }
                { print }
            ' "$final_file" > "${final_file}.tmp" && mv "${final_file}.tmp" "$final_file"
        else
            # 沒有 --- 分隔線，目錄插在檔案開頭
            cat "$toc_file" "$final_file" > "${final_file}.tmp" && mv "${final_file}.tmp" "$final_file"
            log_warn "未找到 --- 分隔線，目錄插在開頭: $fname"
        fi
        rm -f "$toc_file"

        log_done "潤飾完成: $fname ($change_count 處替換 + 目錄插入)"
    done

    # ── 5-3: 品質報告 ──────────────────────────────────────────
    log_step "5-3 產出品質報告"
    call_claude "
Role: 你是品質管理總監。

Context:
## 合規審查結果
$(for f in "$STATE/validation/gate_"*.md; do [ -f "$f" ] && echo "--- $(basename "$f") ---" && tail -5 "$f" 2>/dev/null; done)

## 合規修正結果
$(for f in "$STATE/validation/fix_"*.md; do [ -f "$f" ] && echo "--- $(basename "$f"): 已修正 ---"; done)

## 跨文件一致性
$(read_file "$STATE/validation/cross_check.md" | head -80)

## 防禦檢查
$(read_file "$STATE/validation/defense_check.md" | head -80)

## 格式檢查
$(read_file "$STATE/validation/format_check.md" | head -50)

Task: 產出「一頁式品質報告」：
1. 13 份文件 × 9 項合規 = 117 檢查點的 PASS/FAIL 彙總（含修正後狀態）
2. 跨文件一致性結果摘要
3. ATK 的防禦覆蓋率
4. 殘留風險（如有）
5. 最終品質評分（0~100）
" "$OUT/品質報告.md"

    log_done "Act 5 完成"
}


# ═══════════════════════════════════════════════════════════════
#  狀態顯示
# ═══════════════════════════════════════════════════════════════
show_status() {
    echo -e "\n${CYAN}Pipeline 狀態${NC}"
    echo "─────────────────────────────────────────"

    local acts=("Act1:shared_state/contract_checklist.yaml"
                "Act1:shared_state/cross_reference_map.yaml"
                "Act1:shared_state/knowledge_card.md"
                "Act1:shared_state/reviewer_profiles.yaml"
                "Act1.5:shared_state/attack_surface.yaml"
                "Act2:shared_state/skeletons/batch1_01to05.md"
                "Act2:shared_state/skeletons/batch2_06to10.md"
                "Act2:shared_state/skeletons/batch3_11to13.md"
                "Act2:shared_state/validation/skeleton_issues.md")

    for item in "${acts[@]}"; do
        local label="${item%%:*}"
        local path="$DIR/${item#*:}"
        if [ -f "$path" ]; then
            echo -e "  ${GREEN}✅${NC} $label — $(basename "$path")"
        else
            echo -e "  ⏳ $label — $(basename "$path")"
        fi
    done

    echo ""
    echo "章節產出: $(find "$STATE/chapters" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') / 37"
    echo "文件合併: $(find "$STATE/assembled" -name "*.md" -not -name "fixed_*" -not -name "*.bak" 2>/dev/null | wc -l | tr -d ' ') / 13"
    echo "合規審查: $(find "$STATE/validation" -name "gate_*.md" 2>/dev/null | wc -l | tr -d ' ') / 13"
    echo "最終定版: $(find "$OUT" -name "*.md" -not -name "品質報告.md" 2>/dev/null | wc -l | tr -d ' ') / 13"
    echo "─────────────────────────────────────────"
}


# ═══════════════════════════════════════════════════════════════
#  主入口
# ═══════════════════════════════════════════════════════════════
main() {
    # 解析 --force（可出現在任何位置）
    local args=()
    for arg in "$@"; do
        if [ "$arg" == "--force" ]; then
            FORCE=1
        else
            args+=("$arg")
        fi
    done
    set -- "${args[@]+"${args[@]}"}"

    local FROM="${1:-all}"

    case "$FROM" in
        --status)  show_status; exit 0 ;;
        --from)    FROM="${2:-all}" ;;
        --only)    FROM="${2:-all}"
                   case "$FROM" in
                       act1)   act1 ;;
                       act1.5) act1_5 ;;
                       act2)   act2 ;;
                       act3)   act3 ;;
                       act4)   act4 ;;
                       act5)   act5 ;;
                   esac
                   exit 0 ;;
    esac

    # 用陣列定義執行順序，--from 跳到指定 act 後繼續往下
    local -a ALL_ACTS=(act1 act1_review act1.5 act2 act3 act4 act5)
    local started=0
    [ "$FROM" == "all" ] && started=1
    for act in "${ALL_ACTS[@]}"; do
        [ "$act" == "$FROM" ] && started=1
        [ "$started" -eq 0 ] && continue
        case "$act" in
            act1)          act1 ;;
            act1_review)   act1_review_gate ;;
            act1.5)        act1_5 ;;
            act2)   act2 ;;
            act3)   act3 ;;
            act4)   act4 ;;
            act5)   act5 ;;
        esac
    done

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  五幕劇完成！${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    echo "最終文件: $OUT/"
    ls -la "$OUT/"*.md 2>/dev/null
    echo ""
    show_status
}

main "$@"
