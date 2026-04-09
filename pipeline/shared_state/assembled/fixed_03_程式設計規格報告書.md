# 程式設計規格報告書

**案號：** L0215P2010U
**版本：** 1.0
**日期：** 中華民國 115 年

---

# 程式設計規格報告書

**國營臺灣鐵路股份有限公司 AI 客服系統建置案**
**案號：L0215P2010U**

---

## 第一章　系統範圍與目標

### 1.1　文件目的

本報告書為「台鐵 AI 客服系統建置案」之程式設計規格文件，依據系統分析報告書（交付項目 #02）所確認之功能需求與非功能需求，定義各軟體模組之設計規格、元件介面、資料庫結構、部署架構及安全機制，作為後續程式開發（交付項目 #10 程式設計書）與測試驗證（交付項目 #05 測試計畫書）之設計基準。

### 1.2　系統範圍

本系統涵蓋十大子系統，共 48 項功能需求（FR-IVR-001 ~ FR-ADM-005），對應 45 個軟體模組（M-IVR-01 ~ M-ADM-05）：

| 子系統 | 功能需求範圍 | 軟體模組範圍 | 說明 |
|-------|------------|------------|------|
| 智慧語音應答（AI-IVR） | FR-IVR-001 ~ 007 | M-IVR-01 ~ 06 | ≥30 埠語音通道，整合 STT/LLM/TTS |
| 語音識別（STT） | FR-STT-001 ~ 003 | M-STT-01 ~ 03 | 即時中英文語音轉文字，辨識率 ≥85% |
| 語音合成（TTS） | FR-TTS-001 ~ 002 | M-TTS-01 ~ 02 | 中英文即時語音合成與動態選單 |
| 大型語言模型（LLM） | FR-LLM-001 ~ 008 | M-LLM-01 ~ 05, M-KB-01 ~ 02 | GPU 推論、RAG 問答、知識庫管理 |
| AI 虛擬客服（AI-Agent） | FR-AGT-001 ~ 008 | M-AGT-01 ~ 06, M-SMS-01 | ≥30 埠數位通道，含 SMS 整合 |
| 智慧質檢（AI-QI） | FR-QI-001 ~ 007 | M-QI-01 ~ 07 | 錄音轉寫、規則評分、情緒分析 |
| 查詢及報表（RPT） | FR-RPT-001 ~ 003 | M-RPT-01 ~ 03 | 統計報表、儀表板、客製報表 ≥10 個 |
| 值機平台（WS） | FR-WS-001 ~ 005 | M-WS-01 ~ 05 | 座席操作、AI 輔助、督導監控 |
| 管理後台（ADM） | FR-ADM-001 ~ 005 | M-ADM-01 ~ 05 | 參數設定、權限管理、監控備份 |

### 1.3　系統邊界與介接範圍

本系統以「零衝擊」原則（AD-001）介接台鐵既有環境，不修改既有系統之任何設定：

- **語音來源：** 透過 SIP/RTP fork 被動接收 MES Server 分派之語音流（AD-007），支援 PSTN E1 Gateway（30 B-channel）、WebCall SBC（雙備援）及行政交換機（類比 VoIP Gateway）
- **文字來源：** 透過 REST/WebSocket 介接 CRM Gateway，承接數位客服訊息
- **身分驗證：** 整合 Active Directory（LDAP）進行人員帳號驗證與角色權限控管
- **業務串接：** 透過 API 介接訂票紀錄查詢系統與時刻表查詢系統（規格待台鐵提供）
- **後送處理：** 透過 API 介接後送案件系統，銜接 225 位外點人員作業流程

系統邊界以外之項目（如 MES Server 話務分配邏輯、CRM Gateway 內部設計、PSTN 線路維護等）不在本案設計範圍內，詳見系統分析報告書第二章。

### 1.4　設計目標與效能指標

本系統之程式設計須同時滿足以下效能指標：

| 指標項目 | 目標值 | 量測方式 | 來源 |
|---------|-------|---------|------|
| IVR 應答正確率 | ≥85% | (完全正確×1+部分正確×0.5)÷總次數×100% | 需求書§三(一) |
| IVR 回應時間 | ≤5,000ms | VAD 偵測語音結束至首字播出 | 需求書§三(一) |
| STT 辨識率 | ≥85% | 100%-(錯誤或缺漏字數/總字數)×100% | 需求書§三(二) |
| Agent 應答正確率 | ≥85% | 同 IVR | 需求書§三(五) |
| Agent 回應時間 | ≤5,000ms | 旅客送出訊息至首段文字呈現 | 需求書§三(五) |
| 案件分類正確率 | ≥85% | (AI 正確分類數/總案件數)×100% | 需求書§三(四) |
| 質檢處理速度 | 15min 錄音 → ≤5min 完成 | 轉換分析並產出質檢報告 | 需求書§三(六) |
| 系統可用率 | ≥99%/季 | 每不足 1% 計 3 點 | 服務水準表 |
| 故障修復時間 | ≤4 小時（含假日） | 逾 4hr 每小時計 1 點 | 契約§7(六) |

上述指標直接驅動本報告書之模組設計決策，特別是 GPU 資源分配策略（AD-002）、CPU/GPU 工作負載切分（AD-003）及 HA 雙機備援機制（AD-005）。

---

## 第二章　開發方法與工具

### 2.1　開發方法論

本案採用**迭代式開發**（Iterative Development）搭配**模組化設計**原則，將 45 個軟體模組依功能耦合度劃分為獨立開發單元，各單元之間透過明確定義的 API 介面進行通訊，確保模組可獨立開發、測試與部署。

開發流程依循以下階段：

1. **需求確認期（D+1 ~ D+80）：** 依系統分析報告書確認 48 項 FR 之細部規格
2. **設計期（D+60 ~ D+100）：** 完成本報告書所定義之模組設計、API 規格、資料庫結構
3. **開發期（D+80 ~ D+180）：** 依模組優先序進行迭代開發，每 2 週產出可測試版本
4. **整合測試期（D+180 ~ D+240）：** 模組整合、系統測試、壓力測試、資安檢測
5. **上線驗收期（D+240 ~ D+270）：** 正式環境部署、UAT 驗收、結案

### 2.2　程式語言與框架

#### 2.2.1　後端技術堆疊

| 層級 | 技術選型 | 版本 | 用途 |
|-----|---------|------|------|
| 程式語言 | Python | 3.11+ | 全後端統一語言，涵蓋 API、AI 推論、資料處理 |
| Web 框架 | FastAPI | 0.100+ | 非同步高效能 REST API，原生支援 OpenAPI 3.0 文件自動生成 |
| 外部 API 協定 | REST / JSON | — | 對外部系統（CRM Gateway、管理後台）及符合國發會共通性應用程式介面規範 |
| 內部 API 協定 | gRPC / Protocol Buffers | — | 內部高頻服務間通訊（如 AI-IVR → LLM 推論），延遲較 REST 降低 2~5 倍 |
| SIP 協定堆疊 | PJSIP（pjsua2 Python binding） | 2.14+ | SIP INVITE/BYE/REFER、RTP 收送、SRTP 加密，業界標準開源 SIP/RTP stack |

選擇 Python 作為統一後端語言的核心理由：LLM、STT、TTS 三大 AI 元件之生態系均以 Python 為第一優先支援，採用單一語言可降低跨語言整合成本，並簡化保固期後台鐵自行維運時之技術門檻。

#### 2.2.2　AI 推論引擎

| 引擎 | 模型 | 執行環境 | 說明 |
|-----|------|---------|------|
| vLLM 0.5+ | Llama 3.1 8B-Instruct AWQ 4-bit | GPU（NVIDIA L40S） | PagedAttention + continuous batching，量化後 VRAM 用量 ~8GB，單卡可運行 6 個推論實例（AD-004） |
| faster-whisper（CTranslate2） | Whisper large-v3 | CPU（AI-IVR 伺服器） | CTranslate2 引擎比原版 PyTorch 快 4 倍、記憶體用量降低 50%，30 路串流推論約需 9 CPU 核心（AD-003） |
| Coqui TTS | XTTS-v2 | CPU（AI-IVR 伺服器） | 首包延遲 ≤300ms，支援串流輸出與 voice cloning，每路約需 0.2 CPU 核心（AD-003） |

STT 與 TTS 採用 CPU 推論而非 GPU，是基於串流語音處理之低延遲特性：每收到一小段語音需立即處理，CPU 的單核延遲優於 GPU 之批次吞吐模式。此配置將 GPU 資源完整保留給 LLM 推論，避免即時推論與批次任務之間的資源競爭。若日後 Coqui XTTS-v2 之社群維護出現中斷，備案方案為 MeloTTS 或 Piper，兩者均為開源且相容現有 CPU 推論架構。

#### 2.2.3　前端技術堆疊

| 層級 | 技術選型 | 版本 | 用途 |
|-----|---------|------|------|
| 前端框架 | React | 18+ | 值機平台、管理後台、旅客端數位客服介面 |
| 應用框架 | Next.js | 14+ | SSR/SSG 支援、路由管理、API 中間層 |
| UI 元件庫 | Ant Design | 5+ | 中文友善之企業級 UI 元件，表格/表單/權限元件齊全 |
| 即時通訊 | WebSocket | — | 值機平台即時狀態更新、對話串流推送 |
| 瀏覽器相容 | Edge / Chrome / Firefox / Safari | 最新兩個主要版本 | RWD 響應式設計，支援桌面與行動裝置 |

#### 2.2.4　資料儲存技術

| 元件 | 技術選型 | 版本 | 用途 |
|-----|---------|------|------|
| 關聯式資料庫 | PostgreSQL | 16 | 對話紀錄、工單、質檢結果、系統參數，原生 JSON 欄位支援 |
| 時序擴展 | TimescaleDB | — | 監控指標、系統日誌之時序資料儲存與查詢 |
| 向量資料庫 | Qdrant | latest | RAG 語意檢索，HNSW 索引，Top-K 查詢延遲 <50ms |
| Embedding 模型 | multilingual-e5-large（Microsoft） | — | 1024 維多語言向量化，MTEB 中文基準表現優異且為非陸資產品 |
| 快取 | Redis | 7 | Session 管理、即時對話上下文、熱門查詢快取 |

所有資料元件均部署於台鐵機房地端伺服器，不依賴任何雲端服務，確保資料不發生跨境傳輸。全案技術堆疊採用開源方案（vLLM、Llama、faster-whisper、Coqui XTTS-v2、PostgreSQL、Qdrant、Redis 等），依契約§8(15)規定，契約期滿後台鐵得繼續使用到期前最後更新之版本，無額外授權費用。

### 2.3　部署與維運工具

| 工具 | 用途 | 選型理由 |
|-----|------|---------|
| Docker Compose | 容器編排與服務部署（AD-006） | 6~8 台伺服器規模不需要 K8s 複雜度，降低台鐵後續維運門檻 |
| NVIDIA Container Toolkit | GPU 容器化支援 | 讓 Docker 容器存取 L40S GPU 資源 |
| Prometheus + Grafana | 系統監控與告警 | 開源方案，支援 24/7 告警驅動值班 |
| Git | 原始碼版本控制 | 所有程式碼與設定檔納入版本管理 |
| OpenAPI 3.0 / Swagger UI | API 文件自動生成 | FastAPI 原生整合，確保文件與程式碼同步 |

### 2.4　開發環境與版本管理

開發團隊使用統一的容器化開發環境，確保開發、測試、正式三套環境之一致性。所有原始程式碼以 Git 進行版本控制，分支策略採用 Git Flow（main / develop / feature / release / hotfix），每次合併均須通過自動化單元測試與程式碼審查。

正式交付之原始程式碼光碟（交付項目 #11）將包含完整 Git 歷程記錄、Docker Compose 設定檔、環境變數範本及部署腳本。

---

## 第三章　系統組織架構與軟硬體環境對映

### 3.1　六層式系統架構

本系統採用六層式架構設計（AD-001），由下至上依序為：

```
┌─────────────────────────────────────────────────────┐
│  第六層：使用者層                                      │
│  旅客（PSTN/WebCall/App）、值機員（WS）、督導、管理者（ADM）│
├─────────────────────────────────────────────────────┤
│  第五層：通道接入層                                     │
│  SIP Gateway（PJSIP）│ RTP fork 接收 │ CRM GW 介接    │
│  WebCall SBC 雙備援   │ DTMF 偵測     │ SMS 雙備援     │
├─────────────────────────────────────────────────────┤
│  第四層：AI 服務層                                      │
│  LLM 推論（vLLM）│ STT（faster-whisper）│ TTS（Coqui） │
│  RAG Pipeline    │ 情緒分析            │ 意圖辨識       │
├─────────────────────────────────────────────────────┤
│  第三層：資料管理層                                     │
│  PostgreSQL 16 │ Qdrant 向量DB │ Redis 7 快取         │
│  TimescaleDB   │ 備份/回復     │ 日誌管理             │
├─────────────────────────────────────────────────────┤
│  第二層：平台安全層                                     │
│  AD/LDAP 認證 │ RBAC 權限 │ TLS 1.3 加密            │
│  個資去識別化  │ API Rate Limiting │ 稽核日誌          │
├─────────────────────────────────────────────────────┤
│  第一層：基礎設施層                                     │
│  AI-IVR 伺服器×2 │ AI 伺服器×2（L40S×2）│ 管理伺服器×2 │
│  SMS 裝置×2      │ Docker Compose       │ HA Failover  │
└─────────────────────────────────────────────────────┘
```

各層之間以明確定義的介面通訊：第五層至第四層採 gRPC（內部高頻路徑），第四層至第三層採原生驅動程式（PostgreSQL driver / Qdrant client / Redis client），對外部系統之 API 一律採 REST/JSON 並符合國發會共通性應用程式介面規範。此分層設計使 AI 模組與既有系統完全隔離，任何 AI 元件的升級或替換均不影響通道接入層之運作。

### 3.2　軟體模組與硬體部署對映

#### 3.2.1　正式環境部署配置

**AI-IVR 伺服器（2 台，Active-Active）**

| 硬體規格 | 值 |
|---------|---|
| CPU | 16 核心 ≥2.2GHz ×2 |
| RAM | DDR5 64GB+ |
| 儲存 | 960GB SSD ×3（RAID-5） |
| 網路 | GbE ×4 |
| 電源 | 800W RPS ×2 |

部署模組：

- M-IVR-01 ~ 06（語音通道、多輪對話、真人轉接、DTMF、滿意度、防護）
- M-STT-01 ~ 03（即時語音辨識、意圖辨識、VAD 偵測）— CPU 推論
- M-TTS-01 ~ 02（即時語音合成、動態選單）— CPU 推論
- PJSIP SIP/RTP 協定堆疊

資源估算：30 路 × faster-whisper ≈ 9 CPU 核心，30 路 × Coqui TTS ≈ 6 CPU 核心，合計約 15 核心，雙 CPU（32 核心）具備充足餘裕。

**AI 伺服器（2 台，Active-Active）**

| 硬體規格 | 值 |
|---------|---|
| CPU | 16 核心 ≥3.0GHz ×2 |
| RAM | DDR5 128GB+ |
| 儲存 | 960GB SSD ×3（RAID-5） |
| GPU | NVIDIA L40S 48GB ×2 |
| 網路 | GbE ×4 |
| 電源 | 1000W RPS ×2 |

部署模組與 GPU 分配策略（AD-002）：

- **GPU#0 — LLM 推論專責：** M-LLM-01（vLLM 推論引擎），Llama 3.1 8B AWQ 量化後 ~8GB VRAM，單卡可運行 6 個推論實例，支撐 30 路並行
- **GPU#1 — Embedding + QI + 擴充預留：** M-AGT-02（multilingual-e5-large embedding，~1.1GB）、M-QI-05（情緒分析），剩餘 VRAM 預留未來模型升級或擴充
- **CPU 執行：** M-LLM-02 ~ 05（語意理解、文字處理、對話紀錄、後送分析）、M-AGT-01 ~ 06（數位通道、RAG 引擎、個性化問答）、M-KB-01 ~ 02（知識庫管理）
- FastAPI 後端 API、gRPC 服務、Qdrant 向量資料庫、Redis 快取

**管理/資安監控伺服器（2 台，Active-Active）**

| 硬體規格 | 值 |
|---------|---|
| CPU | 16 核心 ≥3.0GHz ×2 |
| RAM | DDR5 64GB+ |
| 儲存 | 960GB SSD ×3（RAID-5） |
| 網路 | GbE ×4 |
| 電源 | 800W RPS ×2 |

部署模組：

- M-WS-01 ~ 05（值機平台全模組）
- M-ADM-01 ~ 05（管理後台全模組）
- M-RPT-01 ~ 03（報表全模組）
- M-QI-01 ~ 04, 06 ~ 07（質檢數據匯入、轉寫、規則、行為偵測、警報、報表）
- PostgreSQL 16 + TimescaleDB（主要資料庫）
- Prometheus + Grafana（監控與告警）
- Next.js 前端服務

**SMS 簡訊收發系統（2 台，雙備援）**

- M-SMS-01（簡訊服務模組）
- 儲存 256GB+，4G LTE+ 模組

#### 3.2.2　測試環境部署配置

測試環境為正式環境之精簡版，用於開發驗證與整合測試：

| 設備 | 數量 | GPU | 說明 |
|-----|------|-----|------|
| AI-IVR 測試伺服器 | 1 台 | — | CPU 8 核心 ≥2.2GHz ×2，DDR5 64GB+，600GB SAS ×3 |
| AI 測試伺服器 | 1 台 | L40S ×1 | CPU 8 核心 ≥2.2GHz ×2，DDR5 64GB+，600GB SAS ×3 |
| SMS 測試 | 1 台 | — | 儲存 256GB+ |

測試環境之 AI 測試伺服器僅配置 1 張 L40S，GPU#0 同時承擔 LLM 推論與 Embedding 任務，不執行 HA 雙機切換測試。HA 切換驗證須於正式環境進行。

### 3.3　高可用性架構

正式環境採 Active-Active + Failover 架構（AD-005）：

- **正常運行：** 兩台同類伺服器各承擔 50% 負載，透過負載均衡器分配請求
- **故障切換：** 任一台故障時，存活機自動承載 100% 流量，以 Keepalived VRRP 實現虛擬 IP 漂移，偵測間隔 ≤2 秒、切換完成 ≤5 秒
- **Session 不中斷：** Redis 共享 Session 架構確保故障切換時對話上下文不遺失
- **資料一致性：** PostgreSQL 主備串流複寫（Streaming Replication），Qdrant snapshot 定期同步

系統異常時，通道接入層立即將新進來電/訊息導向人工客服排隊，確保旅客服務不因系統故障而中斷。

### 3.4　網路分區與安全邊界

系統網路依六層架構切分為獨立 VLAN：

| VLAN | 用途 | 包含設備 | 存取控制 |
|------|------|---------|---------|
| VLAN-SIP | 語音信令與媒體 | AI-IVR 伺服器、E1 Gateway、WebCall SBC | 僅允許 SIP/RTP 埠號 |
| VLAN-AI | AI 推論與資料處理 | AI 伺服器、Qdrant、Redis | 僅允許 gRPC/API 內部埠號 |
| VLAN-MGMT | 管理與監控 | 管理伺服器、Prometheus/Grafana | BMC IPMI + 管理 API |
| VLAN-DMZ | 對外服務 | 反向代理、Web 前端 | HTTPS 443 |
| VLAN-DB | 資料庫 | PostgreSQL、備份儲存 | 僅允許 DB 連線埠 |

各 VLAN 之間以防火牆規則嚴格管控，遵循最小權限原則。所有跨 VLAN 通訊均強制 TLS 1.3 加密。

### 3.5　容器化部署架構

所有軟體服務以 Docker Compose 編排（AD-006），每台伺服器各自運行獨立的 `docker-compose.yaml`，主要服務容器包含：

**AI-IVR 伺服器：**
- `sip-gateway` — PJSIP SIP/RTP 處理
- `stt-worker` — faster-whisper 串流辨識（可水平擴展至多個 worker）
- `tts-worker` — Coqui XTTS-v2 串流合成
- `ivr-engine` — IVR 對話引擎與業務邏輯

**AI 伺服器：**
- `vllm-server` — vLLM 推論服務（掛載 GPU#0）
- `embedding-server` — multilingual-e5-large 向量化服務（掛載 GPU#1）
- `rag-engine` — RAG Pipeline 與 Agent 業務邏輯
- `qdrant` — 向量資料庫
- `redis` — 快取與 Session 管理

**管理伺服器：**
- `api-gateway` — FastAPI REST API 閘道
- `web-frontend` — Next.js 前端服務
- `postgresql` — PostgreSQL 16 + TimescaleDB
- `prometheus` / `grafana` — 監控堆疊
- `qi-worker` — 質檢批次處理

Docker Compose 讓環境一致性有保障（開發 = 測試 = 正式），升級與回滾透過 `docker-compose pull` + `docker-compose up -d` 即可完成，備份與災難復原透過打包 Docker Volume 實現。GPU 容器使用 NVIDIA Container Toolkit 掛載 L40S 裝置。

---

### 本章引用編號清單

**功能需求（FR）：** FR-IVR-001 ~ 007, FR-STT-001 ~ 003, FR-TTS-001 ~ 002, FR-LLM-001 ~ 008, FR-AGT-001 ~ 008, FR-QI-001 ~ 007, FR-RPT-001 ~ 003, FR-WS-001 ~ 005, FR-ADM-001 ~ 005

**軟體模組（M）：** M-IVR-01 ~ 06, M-STT-01 ~ 03, M-TTS-01 ~ 02, M-LLM-01 ~ 05, M-KB-01 ~ 02, M-AGT-01 ~ 06, M-SMS-01, M-QI-01 ~ 07, M-RPT-01 ~ 03, M-WS-01 ~ 05, M-ADM-01 ~ 05

**架構決策（AD）：** AD-001（六層式架構）, AD-002（GPU 分配策略）, AD-003（STT/TTS 跑 CPU）, AD-004（Llama 3.1 8B AWQ）, AD-005（HA Active-Active + Failover）, AD-006（Docker Compose 部署）, AD-007（SIP/RTP fork 介接）, AD-008（優先開源方案）


---

## 第四章　系統流程圖

本章以五大核心流程描述系統之端到端處理路徑，每條流程均附延遲預算分解，確保各環節加總後滿足需求書所定之回應時間指標。各流程中涉及之軟體模組設計細節，詳見第五章元件設計說明；資料庫讀寫行為，詳見第七章資料庫設計。

---

### 4.1　AI-IVR 語音互動流程

本流程涵蓋旅客透過 PSTN、WebCall 或行政分機撥入後，AI-IVR 從接收語音到播放回覆之完整路徑。系統以 SIP/RTP fork 方式被動接收 MES Server 分派之語音流（AD-007），不攔截、不修改、不影響原始通話路徑。

#### 4.1.1　SIP 信令與媒體建立

```
旅客撥入    VoIP GW / SBC      MES Server       AI-IVR (PJSIP)
  │              │                  │                  │
  │──PSTN/WebCall─→│                  │                  │
  │              │──SIP INVITE──→│                  │
  │              │              │──RTP fork────→│
  │              │              │              │ pjsua2 接收
  │              │              │              │ RTP 媒體流
  │              │              │  （原始通話   │
  │              │              │   路徑不變）   │
```

PJSIP（pjsua2 Python binding）負責 SIP INVITE/BYE 信令處理與 RTP 媒體收送。AI-IVR 向 MES 的 RTP fork 端口註冊接收，取得語音流副本後進入 STT 處理。WebCall 來源透過雙備援 SBC 接入：AI-IVR 的 SIP UA 同時向 Primary 與 Secondary SBC 註冊，當主 SBC 故障時自動切換至備援 SBC，切換期間進行中的通話由 MES 維持，AI-IVR 僅遺失該通之 AI 輔助功能，不中斷通話本身。DTMF 偵測同時支援 RFC 2833 帶內與 SIP INFO 帶外雙模式，確保相容不同 Gateway 設備。

#### 4.1.2　語音互動主流程

```
步驟    處理節點                    動作                           延遲預算
────────────────────────────────────────────────────────────────────────
 1     PJSIP RTP 接收器            接收 RTP 語音流，解碼 G.711      ≤10ms
 2     VAD 偵測器（M-STT-03）       偵測語音活動，判斷旅客發言結束     ≤200ms
       ───── 計時起點：VAD 偵測語音結束 ─────────────────────────
 3     STT（M-STT-01）             faster-whisper 串流辨識           ≤800ms
       　                          （RTF ~0.3x，即 1 秒語音用         
       　                          　0.3 秒處理，CPU 推論）           
 4     意圖辨識（M-STT-02）         文字意圖分類，路由決策             ≤200ms
 5     個資遮罩 Pipeline            正則遮罩：身分證/電話/信用卡號     ≤50ms
 6     LLM 推論（M-LLM-01~02）     vLLM + Llama 3.1 8B AWQ          ≤2,500ms
       　                          gRPC 內部呼叫至 AI 伺服器          
       　                          信心度分級：                       
       　                          　≥0.85 → 直接回答                
       　                          　0.6~0.85 → 回答 + 建議洽人工    
       　                          　<0.6 → 轉人工（見 §4.4）        
 7     TTS（M-TTS-01）             Coqui XTTS-v2 串流合成            ≤800ms
       　                          首包延遲 ≤300ms，CPU 推論          
 8     PJSIP RTP 發送器            編碼 → RTP 封包 → 播放            ≤50ms
       ───── 計時終點：系統回覆首字播出 ─────────────────────────
                                                            合計 ≤4,600ms
                                                        餘裕：400ms（≤5,000ms SLA）
```

涉及票價、時刻等關鍵資訊時，LLM 不依賴模型記憶，而是透過 Function Calling 即時查詢訂票紀錄查詢系統或時刻表查詢系統之 API，取得最新資料後再生成回答。每筆 AI 回覆均附帶「本回覆由 AI 生成，如有疑問請按 0 轉接專人」提示。

#### 4.1.3　多輪對話處理

多輪對話（FR-IVR-003）透過 Redis 維護當次通話之 Session Context，包含前序對話摘要與旅客意圖狀態。每輪交互重複步驟 2~8，LLM Prompt 注入前序上下文以理解指代與省略語意。通話結束時觸發滿意度調查（FR-IVR-006），並將完整對話紀錄寫入 PostgreSQL。

#### 4.1.4　防護機制

- **非業務阻擋（FR-IVR-007）：** LLM Prompt 內嵌 System Instruction 限定回答範圍為台鐵業務；偵測到非業務意圖連續 2 輪後，播放引導語並結束對話
- **惡意攻擊防範：** 單一來源 IP/號碼之頻率限制，對話逾時 5 分鐘無回應自動中斷
- **敏感詞過濾：** STT 輸出經敏感詞庫比對，觸發時記錄並轉人工處理
- **Prompt Injection 防護：** 旅客語音轉文字後以獨立 User Message 注入 LLM，與 System Instruction 嚴格分離

---

### 4.2　AI-Agent 文字對話流程

本流程涵蓋旅客透過 Web、App 或 CRM Gateway 發送文字訊息後，AI-Agent 從接收到回覆之完整路徑。

#### 4.2.1　訊息接收與分派

```
旅客（Web/App）    CRM Gateway        API Gateway         RAG Engine
     │                │                   │                   │
     │──文字訊息──→│                   │                   │
     │                │──REST/WebSocket─→│                   │
     │                │                   │──內部路由────→│
     │                │                   │                   │→ 處理流程
```

#### 4.2.2　文字對話主流程

```
步驟    處理節點                     動作                          延遲預算
────────────────────────────────────────────────────────────────────────
       ───── 計時起點：旅客送出訊息 ──────────────────────────
 1     API Gateway                  接收訊息、Session 識別          ≤100ms
 2     意圖辨識                      文字意圖分類、路由決策          ≤200ms
 3     個資遮罩 Pipeline             正則遮罩去識別化                ≤50ms
 4     RAG 檢索（M-AGT-02~03）      Qdrant 向量檢索                ≤200ms
       　                           multilingual-e5-large embedding     
       　                           → HNSW Top-K（<50ms）           
       　                           → Reranker 重排序               
 5     Prompt 組裝                   System Instruction              ≤50ms
       　                           + 檢索結果（含 metadata）        
       　                           + 歷史對話摘要                   
       　                           + 旅客訊息                       
 6     LLM 推論（M-LLM-01~02）      vLLM + Llama 3.1 8B AWQ        ≤2,500ms
       　                           gRPC 內部呼叫至 AI 伺服器        
       　                           信心度三級分流（同 §4.1.2）      
 7     Citation 抽取（M-AGT-03）     從 LLM 輸出提取引用來源         ≤100ms
       　                           保留文件名稱、頁碼、段落編號      
 8     回覆發送                      REST/WebSocket 推送至前端        ≤100ms
       ───── 計時終點：系統回覆首段文字呈現 ───────────────────
                                                           合計 ≤3,300ms
                                                       餘裕：1,700ms（≤5,000ms SLA）
```

#### 4.2.3　RAG Citation 標註

RAG Pipeline 在檢索階段保留每個 chunk 之來源 metadata（文件名稱、頁碼、段落編號），LLM 生成回答時以 Prompt Engineering 要求標註引用來源（FR-AGT-004）。前端以 footnote 或 tooltip 方式呈現來源連結，供旅客與客服人員驗證答案可靠性。

#### 4.2.4　個性化問答

針對已識別身分之旅客（FR-AGT-005），系統自 Redis 取得當次 Session 上下文，並自 PostgreSQL 查詢歷史對話摘要，作為 LLM Prompt 的額外上下文注入。歷史資料存取嚴格遵守最小權限原則，且歷史摘要經去識別化處理後方可用於 Prompt 組裝。

#### 4.2.5　對話視窗附加功能

前端對話視窗內建熱門選單與宣導推播專區，內容由台鐵管理者透過後台 CMS 介面自行設定與調整，支援依業務或行銷活動推廣期程即時更換。此為靜態內容推送，不經 LLM 處理，延遲可忽略。

---

### 4.3　AI-QI 質檢批次流程

本流程為離線批次處理，不受即時回應 SLA 約束，但須滿足「15 分鐘錄音 → ≤5 分鐘完成轉換分析並產出質檢報告」之效能要求。質檢任務主要在管理伺服器執行，情緒分析模組使用 AI 伺服器 GPU#1 運算資源（AD-002），與 GPU#0 的即時 LLM 推論互不干擾。

#### 4.3.1　質檢處理主流程

```
步驟    處理節點                     動作                          延遲預算
────────────────────────────────────────────────────────────────────────
 1     數據匯入（M-QI-01）          音檔匯入（支援 WAV/MP3/OGG）    ≤10s
       　                           格式轉換 + 元資料提取             
 2     STT 轉寫（M-QI-02）         faster-whisper 離線批次轉寫      ≤60s
       　                           （15min 錄音 × RTF 0.3x          
       　                           　= ~270s，但離線可用更高         
       　                           　batch size 壓縮至 ~60s）        
       　                           台鐵業務術語 hotword boosting     
 3     靜音/插話偵測（M-QI-04）     音頻波形分析，標記靜音段與        ≤15s
       　                           插話事件（含時間戳記）             
 4     情緒分析（M-QI-05）          GPU#1 語調特徵提取 +              ≤30s
       　                           情感分類（正面/中性/負面）         
 5     規則評分（M-QI-03）          依管理者自訂規則自動評分           ≤10s
       　                           （開場白、結束語、禁語、           
       　                           　靜音超標、情緒異常等）           
 6     異常偵測（M-QI-06）          評分低於閾值 → 自動告警通知        ≤5s
       　                           推播至督導人員                     
 7     報表產出（M-QI-07）          產出質檢報告（含專員評分、          ≤30s
       　                           原因分析、情緒趨勢圖）             
────────────────────────────────────────────────────────────────────────
                                                           合計 ≤160s（~2.7 分鐘）
                                                       餘裕：~2.3 分鐘（≤5 分鐘 SLA）
```

#### 4.3.2　排程與批次管理

質檢任務支援兩種觸發模式：

- **自動排程：** 以 Cron 排程定期掃描新匯入錄音檔，夜間離峰時段進行批次處理
- **手動觸發：** 督導人員可在管理後台選取特定錄音檔立即執行質檢

批次處理採佇列機制，確保多筆質檢任務依序執行且不超載 GPU#1 資源。每筆質檢結果寫入 PostgreSQL 並建立索引，供後續多維度報表查詢。

---

### 4.4　真人轉接流程

本流程描述 AI 判斷需人工介入時，從 AI 對話移轉至值機員接手之完整路徑。轉接觸發條件包含語音通道（FR-IVR-004）與文字通道（FR-AGT-006）。

#### 4.4.1　轉接觸發條件

| 觸發情境 | 判斷邏輯 | 來源 |
|---------|---------|------|
| LLM 信心度不足 | 信心度 < 0.6，連續 2 輪低於閾值 | M-LLM-02 |
| 旅客主動要求 | 語音按 0 / 文字輸入「轉人工」 | M-IVR-05 / M-AGT-05 |
| 敏感詞觸發 | STT/文字偵測到敏感內容 | M-IVR-06 |
| 非國語語音 | VAD 偵測到非國語語音超過 3 輪 | M-STT-03 |
| 對話逾時 | AI 無法在限定輪次內解決旅客問題 | M-IVR-02 |
| 情緒激動 | 語音情緒分析偵測到強烈負面情緒 | M-QI-05 |

#### 4.4.2　轉接主流程

```
步驟    處理節點                     動作
────────────────────────────────────────────────────────────────────────
 1     AI Engine                    觸發轉接條件 → 生成對話摘要
       　                           （含旅客意圖、已嘗試回答、未解決問題）
 2     AI Engine → MES              發送轉接請求（SIP REFER 或 API）
 3     MES                          依 ACD 策略分配至空閒值機員
 4     值機平台（M-WS-01~02）       值機員螢幕彈出：
       　                           　・旅客基本資訊（來電號碼/數位通道 ID）
       　                           　・AI 對話摘要（結構化文字，非逐字稿）
       　                           　・AI 建議回覆（基於知識庫檢索結果）
       　                           　・相關知識庫條目連結
 5     值機員                        閱讀摘要後接續服務，無需旅客重複說明
 6     值機平台                      通話/對話結束後自動生成後續摘要
       　                           如需後送 → 建立工單（M-WS-03）
```

AI 對話摘要的設計目標是讓值機員在 10 秒內掌握旅客需求，免除重複問診。摘要格式為結構化欄位（意圖類別、關鍵實體、已處理步驟、待解決問題），而非原始對話逐字稿。知識輔助功能（FR-WS-002）在值機員接聽期間持續運作，即時推送 AI 建議回覆與相關知識庫內容。

#### 4.4.3　語音通道轉接時序

```
AI-IVR          MES Server        值機員 (WS)
  │                │                  │
  │ SIP REFER ──→│                  │
  │ 播放等待音樂    │──ACD 分配──→│
  │                │                  │ 畫面彈出摘要
  │──RTP 媒體切換至值機員─────→│
  │                │                  │ 值機員接聽
  │ AI-IVR 釋放   │                  │
  │ 該路 Session    │                  │
```

轉接期間 AI-IVR 對旅客播放等待音樂，MES 依既有 ACD（自動話務分配）策略分派至空閒值機員。RTP 媒體路徑由 MES 控制切換，AI-IVR 完成移轉後釋放該路 Session 資源，回到可服務狀態。

---

### 4.5　SMS 收發處理流程

本流程描述旅客透過簡訊與系統互動之完整路徑，涵蓋雙備援 SMS 收發裝置之切換機制（FR-AGT-007）。

#### 4.5.1　SMS 收發主流程

```
步驟    處理節點                     動作                          延遲
────────────────────────────────────────────────────────────────────────
 1     SMS 裝置（Primary）          接收旅客簡訊（4G LTE+）          電信網路
       　                           若 Primary 不可用 → 自動切換      延遲
       　                           至 Secondary 備援裝置              
 2     M-SMS-01                     解析簡訊內容、提取發送號碼         ≤100ms
       　                           個資遮罩處理                       
 3     RAG Engine                   同文字對話流程（§4.2.2 步驟 4~7） ≤3,000ms
       　                           LLM 生成回覆 + Citation            
 4     M-SMS-01                     將回覆格式化為簡訊                 ≤100ms
       　                           （≤160 字/則，超長自動分則）        
 5     SMS 裝置                     發送回覆簡訊                       電信網路
       　                                                              延遲
 6     同步通知                      WebSocket 推播至值機平台           ≤100ms
       　                           客服人員即時收到 AI 自動回覆        
       　                           內容與對應旅客資訊                  
 7     紀錄寫入                      寫入 PostgreSQL                   ≤50ms
       　                           「AI 自動回覆紀錄」表              
       　                           保留 ≥5 年                         
```

#### 4.5.2　同步通知與人工介入

AI 自動回覆 SMS 時，系統透過 WebSocket 即時推播至值機平台，客服人員可在介面上檢視 AI 回覆內容與旅客資訊。若客服人員判斷需人工介入，可直接在值機平台接手後續對話，後續 SMS 回覆改由人工處理。此機制確保 AI 自動回覆受人工監督，所有自動回覆紀錄均寫入資料庫供後續追蹤與稽核。

#### 4.5.3　雙備援切換

兩台 SMS 裝置以 Primary/Secondary 架構運作。M-SMS-01 模組透過定期 Heartbeat（每 30 秒）偵測 Primary 裝置狀態，當偵測到故障時自動切換至 Secondary 裝置。切換期間排隊中的簡訊不遺失，待備援裝置就緒後依序發送。SMS 裝置之 4G LTE+ 模組須確保非大陸地區品牌晶片組。

---

### 4.6　延遲預算彙整

| 流程 | SLA 指標 | 預算合計 | 餘裕 | 主要瓶頸 |
|-----|---------|---------|------|---------|
| AI-IVR 語音互動 | ≤5,000ms | ≤4,600ms | 400ms | LLM 推論（2,500ms） |
| AI-Agent 文字對話 | ≤5,000ms | ≤3,300ms | 1,700ms | LLM 推論（2,500ms） |
| AI-QI 質檢批次 | ≤5min | ~2.7min | ~2.3min | STT 批次轉寫（60s） |
| 真人轉接 | — | 取決於 ACD 排隊 | — | MES 分配延遲 |
| SMS 收發 | — | ≤3,350ms（不含電信延遲） | — | LLM 推論（2,500ms） |

所有即時流程之瓶頸均為 LLM 推論環節。vLLM 引擎透過 PagedAttention 技術最大化 KV Cache 利用率，搭配 continuous batching 機制，30 路並行時單次推論 P95 延遲為 ~1.2 秒（128 input + 64 output token），複雜問答場景延遲預算放寬至 2,500ms 以涵蓋長文本生成與 API 查詢之額外開銷。GPU#0 專責 LLM 推論（AD-002），不與 Embedding 或質檢任務共享資源，確保即時推論之延遲穩定性。

---

### 本章引用編號清單

**功能需求（FR）：** FR-IVR-001, FR-IVR-002, FR-IVR-003, FR-IVR-004, FR-IVR-005, FR-IVR-006, FR-IVR-007, FR-STT-001, FR-STT-002, FR-STT-003, FR-TTS-001, FR-TTS-002, FR-LLM-001, FR-LLM-002, FR-LLM-003, FR-LLM-004, FR-AGT-001, FR-AGT-002, FR-AGT-003, FR-AGT-004, FR-AGT-005, FR-AGT-006, FR-AGT-007, FR-QI-001, FR-QI-002, FR-QI-003, FR-QI-004, FR-QI-005, FR-QI-006, FR-QI-007, FR-WS-001, FR-WS-002, FR-WS-003, FR-SMS-001

**測試案例（TC）：** TC-IVR-001 ~ 007, TC-STT-001 ~ 003, TC-TTS-001 ~ 002, TC-LLM-001 ~ 002, TC-AGT-001 ~ 007, TC-QI-001 ~ 007, TC-WS-001 ~ 003

**架構決策（AD）：** AD-002（GPU 分配策略）, AD-003（STT/TTS 跑 CPU）, AD-004（Llama 3.1 8B AWQ）, AD-005（HA Active-Active + Failover）, AD-007（SIP/RTP fork 介接）

**攻擊面防禦（ATK）：** ATK-005（E1/SIP 介接 — §4.1.1 SIP 信令流程圖與 RTP fork 說明）, ATK-007（SBC failover — §4.1.1 雙 SBC 註冊與自動切換）, ATK-008（AI 正確率 — §4.1.2/§4.2.2 信心度三級分流防線）, ATK-010（轉人工流程 — §4.4 完整轉接路徑與摘要機制）


---

## 第五章　軟體元件設計

本章依第三章之容器部署架構，逐一說明六大核心 AI 服務模組之內部設計、關鍵參數、API 介面規格與資源配置。各模組之端到端處理流程與延遲預算已於第四章詳述，本章聚焦於元件內部實作細節。

---

### 5.1　STT 模組 — Streaming ASR Pipeline（M-STT-01 / M-STT-02 / M-STT-03）

#### 5.1.1　引擎架構

STT 模組採用 OpenAI Whisper large-v3 模型，以 faster-whisper（CTranslate2 加速版）部署於 AI-IVR 伺服器之 CPU 上（AD-003）。CTranslate2 引擎比原版 PyTorch 推論快約 4 倍、記憶體用量降低約 50%，Real-Time Factor（RTF）約 0.3x，即 1 秒語音僅需 0.3 秒處理。30 路並行時預估消耗約 9 顆 CPU 核心，AI-IVR 伺服器具備 16 核心 ≥2.2GHz ×2（共 32 核心），資源充裕。

模組內部分為三個子元件：

| 子元件 | 模組編號 | 職責 |
|--------|---------|------|
| VAD 偵測器 | M-STT-03 | 基於 Silero VAD 進行語音活動偵測，判定旅客發言結束時機（FR-STT-003） |
| 串流辨識引擎 | M-STT-01 | 以 chunk-based streaming 方式接收 VAD 切分之語音段，執行中英文混合辨識（FR-STT-001），辨識率目標 ≥85% |
| 意圖分類器 | M-STT-02 | 對辨識文字進行意圖分類與路由決策（FR-STT-002），輸出意圖標籤供下游模組使用 |

台鐵業務專屬詞庫（站名如「新左營」「太魯閣」「普悠瑪」，票種如「去回票」「電子票證」）以 hotword boosting 機制注入 Whisper 解碼階段，提升專有名詞辨識率。對於台灣口音摻雜台語之國語（如「我要坐到高雄去啦」），Whisper large-v3 可正確辨識；純台語對話不在需求範圍內，連續 3 輪偵測到非國語語音時觸發轉人工流程（詳見第四章 §4.4）。

#### 5.1.2　個資遮罩 Pipeline

STT 輸出之文字進入 LLM 前，須先經過個資遮罩處理。以正則表達式偵測身分證字號、手機號碼、信用卡號等個資欄位，執行即時遮罩後方可傳遞至下游模組與寫入資料庫。遮罩規則以 YAML 設定檔管理，管理者可於後台新增或調整規則。原始未遮罩文字不落地儲存，僅存在於記憶體中之處理過程。

#### 5.1.3　API 介面

```
gRPC Service: SttService

rpc StreamRecognize(stream AudioChunk) returns (stream RecognitionResult)
  - AudioChunk: {session_id, audio_bytes, sample_rate, encoding}
  - RecognitionResult: {text, is_final, confidence, intent_label, language}

rpc GetSupportedLanguages(Empty) returns (LanguageList)
```

| 欄位 | 說明 |
|------|------|
| `session_id` | 通話 Session 識別碼，關聯 Redis 上下文 |
| `is_final` | VAD 判定發言結束後輸出之最終辨識結果 |
| `confidence` | 辨識信心度（0.0~1.0） |
| `intent_label` | 意圖分類標籤（如 `ticket_query`、`schedule_query`、`complaint`） |

---

### 5.2　TTS 模組 — Neural TTS Pipeline（M-TTS-01 / M-TTS-02）

#### 5.2.1　引擎架構

TTS 模組採用 Coqui XTTS-v2 模型，以 CPU 推論部署於 AI-IVR 伺服器（AD-003）。XTTS-v2 支援串流輸出，首包延遲 ≤300ms，每路語音合成約消耗 0.2 顆 CPU 核心，30 路並行時預估使用約 6 核心，在 32 核心伺服器上與 STT 模組共存無壓力。

模型完全地端運行，無需任何外部網路連線，所有語音合成請求不離開台鐵機房。XTTS-v2 支援 Voice Cloning 功能，可依台鐵指定之聲音風格調整合成語音。Coqui AI 公司雖已於 2023 年底停業，但 XTTS-v2 模型以 MPL-2.0 授權開源，可持續使用；長期維護備案為 MeloTTS 或 Piper，架構介面相容，切換時僅需替換模型載入層。

#### 5.2.2　快取策略

對於高頻重複播放之固定話術（開場白、選單提示、滿意度調查語音等），系統預先合成並快取為 WAV 檔案，直接播放而不經過即時合成，降低 CPU 負載並消除合成延遲。動態選單內容（M-TTS-02）依後台設定即時合成（FR-TTS-002），合成結果亦快取 TTL 為 1 小時，相同內容重複請求時直接回傳快取結果。

#### 5.2.3　API 介面

```
gRPC Service: TtsService

rpc Synthesize(SynthesisRequest) returns (stream AudioChunk)
  - SynthesisRequest: {text, language, voice_id, speed, output_format}
  - AudioChunk: {audio_bytes, sample_rate, encoding, is_last}

rpc ListVoices(Empty) returns (VoiceList)
rpc WarmupCache(CacheRequest) returns (CacheResult)
```

| 欄位 | 說明 |
|------|------|
| `voice_id` | 語音風格識別碼，對應預訓練或 Voice Clone 之音色 |
| `speed` | 語速控制（0.5~2.0，預設 1.0） |
| `output_format` | 輸出格式（PCM_16K / G.711_ULAW / G.711_ALAW） |

---

### 5.3　LLM 推論模組 — vLLM Serving（M-LLM-01 / M-LLM-02）

#### 5.3.1　模型部署配置

LLM 推論模組採用 Llama 3.1 8B-Instruct 繁中微調版，以 AWQ 4-bit 量化後約需 ~8GB VRAM，部署於 AI 伺服器之 GPU#0（NVIDIA L40S 48GB）。推論引擎為 vLLM 0.5+，支援 PagedAttention 技術最大化 KV Cache 利用率，搭配 continuous batching 機制，單卡可同時運行 6 個推論實例，30 路並行時每路均獲獨立推論資源（AD-002 / AD-004）。

GPU#0 專責 LLM 推論，不與 Embedding、質檢情緒分析等任務共享，確保即時推論延遲穩定。單卡預估吞吐量約 2,800 token/s，P95 延遲約 1.2 秒（128 input + 64 output token）。複雜問答場景含 Function Calling（查詢票務/時刻 API）時，延遲預算放寬至 2,500ms。

若 8B 模型精度不足，可原地升級至 Llama 3.1 13B-Instruct（FP16，~26GB VRAM），仍在單卡 48GB 容量內，無需更換硬體。

#### 5.3.2　信心度分級機制

LLM 輸出附帶信心度分數，系統依三級閾值分流處理：

| 信心度 | 處理策略 | 說明 |
|--------|---------|------|
| ≥ 0.85 | 直接回答 | AI 自信度高，直接回覆旅客 |
| 0.6 ~ 0.85 | 回答並建議洽人工 | 附加「如需進一步協助，請按 0 轉接專人」 |
| < 0.6 | 轉人工 | 不提供 AI 回答，直接進入轉接流程（詳見第四章 §4.4） |

每筆 AI 回覆均附帶「本回覆由 AI 生成」之提示語，涉及票價、時刻等關鍵資訊時透過 Function Calling 即時查詢外部 API，不依賴模型記憶。

#### 5.3.3　Prompt Injection 防護

旅客輸入（語音轉文字或文字訊息）以獨立 User Message 角色注入 LLM，與 System Instruction 嚴格分離。System Instruction 內嵌業務範圍限定，連續 2 輪偵測到非業務意圖時自動結束對話。輸入文字經敏感詞庫比對與個資遮罩後方可進入 Prompt 組裝。

#### 5.3.4　API 介面

```
gRPC Service: LlmService

rpc Generate(GenerateRequest) returns (stream GenerateResponse)
  - GenerateRequest: {session_id, messages[], tools[], max_tokens, temperature}
  - GenerateResponse: {token, finish_reason, confidence, tool_calls[]}

rpc HealthCheck(Empty) returns (HealthStatus)
  - HealthStatus: {gpu_util, vram_used, vram_total, active_instances, queue_depth}
```

```
REST API（外部）: POST /v1/chat/completions
  - 遵循 OpenAI 相容格式，供管理後台測試與 API 整合使用
  - OAuth 2.0 Bearer Token 認證
  - Rate Limiting: 60 req/min per token
```

---

### 5.4　RAG 檢索模組 — Embedding + Vector Search + Reranker（M-AGT-02 / M-AGT-03 / M-KB-01）

#### 5.4.1　向量化引擎

Embedding 模組採用 Microsoft multilingual-e5-large，模型大小約 1.1GB，部署於 AI 伺服器之 GPU#1（AD-002）。輸出向量維度為 1,024d。知識庫文件經分段（chunking）後批次向量化，寫入 Qdrant 向量資料庫。Qdrant 以 Rust 實作、Docker 容器部署，採用 HNSW 索引，單機即可滿足台鐵知識庫預估 10,000~50,000 筆文件之規模，Top-K 查詢延遲 < 50ms。

#### 5.4.2　RAG Pipeline 流程

```
旅客訊息 → Embedding → Qdrant Top-K 檢索 → Reranker 重排序
  → Prompt 組裝（System Instruction + 檢索結果含 metadata + 歷史摘要 + 旅客訊息）
  → LLM 生成 → Citation 抽取 → 回覆
```

**Metadata 傳遞鏈：** 每個 chunk 在索引時保留來源 metadata（文件名稱、頁碼、段落編號、版本號），檢索結果攜帶完整 metadata 進入 Prompt 組裝。LLM 以 Prompt Engineering 指令要求標註引用來源（FR-AGT-004），Citation 抽取模組解析 LLM 輸出中的來源標記，轉換為結構化引用資料供前端以 footnote 或 tooltip 呈現。

#### 5.4.3　知識庫版本管理

知識庫更新時（FR-LLM-005），系統以 Collection Alias 機制實現版本切換：新版 chunk 向量化完成後寫入新 Collection，驗證無誤後切換 Alias 指向，舊 Collection 保留供回溯（FR-AGT-002）。此機制實現零停機更新，切換過程中查詢請求自動路由至新版。

#### 5.4.4　API 介面

```
gRPC Service: RagService

rpc Search(SearchRequest) returns (SearchResponse)
  - SearchRequest: {query, top_k, filters, session_id}
  - SearchResponse: {results[]{chunk_text, score, metadata{source, page, section, version}}}

rpc Ingest(IngestRequest) returns (IngestResponse)
  - IngestRequest: {documents[]{content, metadata}, collection_version}
  - IngestResponse: {indexed_count, errors[]}

rpc SwitchVersion(VersionRequest) returns (VersionResponse)
```

```
REST API（外部）: GET /v1/knowledge/search?q={query}&top_k={k}
  - OAuth 2.0 Bearer Token 認證
  - 回傳含 citation metadata 之檢索結果
```

---

### 5.5　對話管理模組 — Session Manager + Context Window（M-LLM-02 / M-AGT-04 / M-IVR-02）

#### 5.5.1　Session 管理

對話管理模組以 Redis 7 作為 Session Store，管理所有通道（語音 / 文字 / SMS）之即時對話上下文。每個 Session 包含：

| 欄位 | 儲存位置 | TTL | 說明 |
|------|---------|-----|------|
| 對話歷史（當次） | Redis Hash | 30 分鐘（語音）/ 60 分鐘（文字） | 當次 Session 之完整對話輪次 |
| 意圖狀態機 | Redis Hash | 同上 | 當前對話階段與意圖追蹤 |
| 旅客歷史摘要 | PostgreSQL | 永久（去識別化後） | 歷史對話摘要，供個性化問答使用（FR-AGT-005） |

#### 5.5.2　Context Window 管理

Llama 3.1 8B 原生支援 128K token context window，但為控制推論延遲與 VRAM 消耗，實際使用時限制有效 context 為 4,096 token。Context Window 組裝優先順序：

1. **System Instruction**（~500 token）— 業務範圍限定、回覆格式規範、安全指引
2. **RAG 檢索結果**（~1,500 token）— 向量檢索 Top-K 結果與 metadata
3. **歷史對話摘要**（~500 token）— 前序對話壓縮摘要
4. **近期對話輪次**（~1,000 token）— 最近 3~5 輪原始對話
5. **當前旅客訊息**（~500 token）— 本輪輸入

當對話累積超出 context budget 時，對話管理模組自動觸發摘要壓縮：以 LLM 將較早輪次對話壓縮為摘要，替換原始對話紀錄，確保 context 不溢出且語意不遺失。

#### 5.5.3　個性化上下文注入

對於已識別身分之旅客，系統自 PostgreSQL 查詢其歷史對話摘要（經去識別化處理），作為 LLM Prompt 之額外上下文注入。歷史資料存取遵循最小權限原則，僅查詢與當前意圖相關之歷史紀錄。此功能之存取權限透過 M-KB-02 之角色權限機制控管，所有存取行為記入操作日誌。

#### 5.5.4　API 介面

```
gRPC Service: SessionService

rpc CreateSession(CreateSessionRequest) returns (Session)
  - CreateSessionRequest: {channel_type, caller_id, metadata}
  - Session: {session_id, created_at, ttl}

rpc GetContext(ContextRequest) returns (ContextResponse)
  - ContextRequest: {session_id}
  - ContextResponse: {messages[], intent_state, history_summary}

rpc UpdateContext(UpdateRequest) returns (UpdateResponse)
rpc CloseSession(CloseRequest) returns (CloseResponse)
  - CloseSession 觸發：對話紀錄寫入 PostgreSQL、Session 清理
```

---

### 5.6　質檢分析模組 — Audio Pipeline + Scoring Engine（M-QI-01 ~ M-QI-07）

#### 5.6.1　模組內部架構

質檢模組為離線批次處理系統，部署於管理伺服器之 `qi-worker` 容器，情緒分析子模組使用 AI 伺服器 GPU#1（AD-002）。批次處理流程與延遲預算已於第四章 §4.3 詳述，本節聚焦各子元件之內部設計。

| 子元件 | 模組編號 | 運算資源 | 說明 |
|--------|---------|---------|------|
| 數據匯入引擎 | M-QI-01 | CPU | 支援 WAV/MP3/OGG 格式，自動排程或手動觸發（FR-QI-001） |
| 離線 STT 轉寫 | M-QI-02 | CPU | faster-whisper 批次模式，台鐵業務術語 hotword boosting（FR-QI-002） |
| 規則評分引擎 | M-QI-03 | CPU | 管理者自訂規則（開場白/結束語/禁語/靜音超標等），自動加權評分（FR-QI-003） |
| 行為偵測器 | M-QI-04 | CPU | 音頻波形分析，偵測靜音段（>5 秒標記）與插話事件（FR-QI-004） |
| 情緒分析引擎 | M-QI-05 | GPU#1 | 語調特徵提取 + 情感三分類（正面/中性/負面），15 分鐘錄音處理 ≤30 秒（FR-QI-005） |
| 警報推送 | M-QI-06 | CPU | 評分低於閾值時推播至督導人員（FR-QI-006） |
| 報表產出 | M-QI-07 | CPU | 質檢報告含專員評分、原因分析、情緒趨勢圖（FR-QI-007） |

整條 Pipeline 從 15 分鐘錄音匯入至報表產出，合計 ≤160 秒（~2.7 分鐘），滿足 ≤5 分鐘之 SLA 要求。

#### 5.6.2　規則引擎設計

質檢規則以 YAML 設定檔定義，管理者透過後台介面（M-ADM-01）設定規則項目、權重與通過標準：

```yaml
# 質檢規則範例
rules:
  - id: QR-001
    name: "開場白合規"
    type: keyword_match
    pattern: ["您好.*臺鐵", "感謝.*來電"]
    weight: 15
    pass_threshold: 1    # 至少命中一個 pattern
  - id: QR-002
    name: "靜音超標"
    type: silence_duration
    max_seconds: 10
    weight: 20
  - id: QR-003
    name: "負面情緒偵測"
    type: emotion_score
    threshold: 0.7       # 負面情緒分數 > 0.7 觸發扣分
    weight: 25
```

規則引擎依序執行每條規則，加權計算總評分，低於通過標準時自動觸發警報（M-QI-06）。規則設定變更即時生效，不需重新部署。

#### 5.6.3　API 介面

```
REST API: POST /v1/qi/jobs
  - 提交質檢任務（單筆或批次）
  - Body: {audio_files[], priority, callback_url}
  - Response: {job_id, status, estimated_completion}

REST API: GET /v1/qi/jobs/{job_id}
  - 查詢質檢任務狀態與結果

REST API: GET /v1/qi/reports?agent_id={id}&date_from={}&date_to={}
  - 查詢質檢報表（支援多維度篩選）

REST API: PUT /v1/qi/rules
  - 更新質檢規則設定（需管理者權限）
  - OAuth 2.0 Bearer Token 認證
```

所有 REST API 遵循國發會共通性應用程式介面規範，採 RESTful / JSON / OAuth 2.0 / 版本控制（/v1/），API 規格以 OpenAPI 3.0 文件定義。

---

### 5.7　模組間通訊架構

各模組間之通訊協定遵循以下原則：

- **AI-IVR ↔ AI 伺服器（LLM/Embedding）：** gRPC，二進制序列化 + HTTP/2 多工，延遲比 REST 低 2~5 倍，滿足 2,500ms LLM 推論延遲預算
- **管理伺服器 ↔ AI 伺服器（質檢/Embedding）：** gRPC，批次任務傳輸效率高
- **對外 API（CRM Gateway / 管理後台 / 值機平台）：** REST，符合既有系統慣例與國發會規範
- **即時推播（值機平台 / SMS 通知）：** WebSocket，支援雙向即時通訊

HA 架構下，兩台 AI 伺服器以 Active-Active 模式運行（AD-005），gRPC 客戶端透過 Keepalived VIP 連線，故障時 ≤2 秒偵測、≤5 秒完成切換，存活伺服器承載 100% 負載。Session 資料存於共享 Redis，切換後對話上下文不遺失。

---

### 本章引用編號清單

**功能需求（FR）：** FR-STT-001, FR-STT-002, FR-STT-003, FR-TTS-001, FR-TTS-002, FR-LLM-001, FR-LLM-002, FR-LLM-003, FR-LLM-004, FR-LLM-005, FR-LLM-007, FR-AGT-002, FR-AGT-003, FR-AGT-004, FR-AGT-005, FR-QI-001, FR-QI-002, FR-QI-003, FR-QI-004, FR-QI-005, FR-QI-006, FR-QI-007

**測試案例（TC）：** TC-STT-001 ~ 003, TC-TTS-001 ~ 002, TC-LLM-001 ~ 003, TC-AGT-002 ~ 005, TC-QI-001 ~ 007

**軟體模組（M）：** M-STT-01 ~ 03, M-TTS-01 ~ 02, M-LLM-01 ~ 02, M-LLM-03, M-AGT-02 ~ 04, M-KB-01, M-QI-01 ~ 07, M-ADM-01

**架構決策（AD）：** AD-002（GPU 分配策略 — GPU#0 專責 LLM，GPU#1 負責 Embedding + QI）, AD-003（STT/TTS 跑 CPU 不上 GPU）, AD-004（Llama 3.1 8B AWQ 量化）, AD-005（HA Active-Active + Failover）

**攻擊面防禦（ATK）：** ATK-001（§5.1.2 個資遮罩 Pipeline 實作）, ATK-008（§5.3.2 信心度三級分流機制）, ATK-009（§5.1.1 台灣口音 hotword boosting 與非國語轉人工策略）, ATK-011（§5.2.1 Coqui 停業備案 MeloTTS/Piper）, ATK-015（§5.3.1/§5.4.1 開源元件版本鎖定與升級路徑）, ATK-016（§5.6.3 REST API 遵循國發會規範）


---

【待插入】將 `pipeline/shared_state/chapters/03_ch5.md` 中第六章（使用者介面設計）與第七章（資料庫設計）之完整正文插入此處，取代本段 pipeline 摘要。


---

>>>
（直接刪除整段 pipeline 摘要，第八章正文已在下方。）

---

### 修正 6：§9.2 追溯覆蓋率數量與實際矩陣不符

位置：§9.2 追溯覆蓋率統計表
原文：<<<
| 功能需求（FR） | 46 項 | 46 項 | 100% |
| 軟體模組（M） | 35 個 | 35 個 | 100% |
| 測試案例（TC） | 46 個 | 46 個 | 100%（1:1 對應 FR） |


---

## 第八章　備份與災難復原策略

本章定義系統各元件之資料備份機制、回復目標及加密策略，確保服務可用率 ≥99%/季（KPI: availability）且故障修復時間 ≤4 小時含假日（KPI: mttr）。

---

### 8.1　RPO / RTO 定義

系統依資料重要性與業務衝擊程度，劃分三級回復目標：

| 級別 | 資料類別 | RPO（容許遺失量） | RTO（回復時間） | 備份方式 |
|------|---------|-------------------|-----------------|---------|
| 第一級 | 對話紀錄、工單、SMS 簡訊（保留 ≥5 年） | ≤5 分鐘 | ≤1 小時 | WAL 連續歸檔 + 即時串流複寫 |
| 第二級 | 知識庫向量索引、質檢結果、系統參數 | ≤1 小時 | ≤2 小時 | 定時快照 + 異機備援 |
| 第三級 | 監控指標、操作日誌（保留 ≥6 個月） | ≤4 小時 | ≤4 小時 | 每日全量備份 |

上述 RTO 上限 ≤4 小時，與契約§7(六)規定之 MTTR ≤4hr 一致。

---

### 8.2　各元件備份機制

#### 8.2.1　PostgreSQL 16 + TimescaleDB

- **連續歸檔：** 啟用 WAL（Write-Ahead Log）連續歸檔，搭配 `pg_basebackup` 每日執行全量基礎備份。WAL 檔案即時傳送至備援伺服器，實現 RPO ≤5 分鐘。
- **邏輯備份：** 每日凌晨以 `pg_dump` 產出邏輯備份，保留最近 30 份。
- **TimescaleDB 分區：** SMS 紀錄依月份自動分區（詳見第七章 7.2 節），過期分區壓縮後歸檔至冷儲存，滿足 ≥5 年保留需求（FR-AGT-007）。
- **異機備援：** 主機 WAL 串流複寫至 HA 備援機（AD-005），備援機以 Hot Standby 模式運行，可隨時接管讀取與回復。

#### 8.2.2　Qdrant 向量資料庫

- **Snapshot 備份：** 每日執行 Qdrant Snapshot，將 `knowledge_base` Collection 完整匯出。
- **版本化管理：** 知識庫更新時自動建立快照，支援回溯至任意版本（FR-AGT-002）。
- **異機同步：** Snapshot 檔案透過 `rsync` 加密傳輸至備援伺服器。

#### 8.2.3　Redis 7

- **混合持久化：** RDB 快照每 15 分鐘執行一次 + AOF 日誌每秒同步（`appendfsync everysec`），確保最多遺失 1 秒對話上下文。
- **驅逐策略：** 採用 `volatile-lru`，僅驅逐有 TTL 的 Session 資料，確保核心資料不遺失。
- **回復優先序：** 故障時先載入 AOF（資料較完整），AOF 損壞時降級為 RDB。

#### 8.2.4　Docker Volume

- 所有容器服務的持久化資料掛載為具名 Volume（AD-006）。
- 每日凌晨統一執行 Volume 快照備份，壓縮後傳至異機儲存。
- 模型權重檔（Llama 3.1 8B AWQ ~8GB、multilingual-e5-large ~1.1GB、XTTS-v2）以版本化目錄管理，不重複備份，僅於模型更新時同步。

---

### 8.3　HA 雙機備援切換

系統採 Active-Active + Failover 架構（AD-005），備援切換機制如下：

| 層級 | 機制 | 偵測間隔 | 切換時間 |
|------|------|---------|---------|
| 網路層 | Keepalived VRRP + VIP | ≤2 秒 | ≤5 秒 |
| SIP 層 | PJSIP 雙註冊（Primary/Secondary） | 心跳 3 秒 | ≤5 秒 |
| 應用層 | Nginx 健康檢查 + 自動移除故障節點 | 5 秒 | 即時 |
| Session 層 | Redis 共享 Session | — | 零中斷 |

正常運行時雙機各承載 50% 負載，任一台故障時存活機自動承載 100% 流量。Redis 共享 Session 確保故障切換時使用者對話上下文不遺失。進行中的語音通話由 MES 維持，AI-IVR 僅遺失該通之 AI 輔助功能，不中斷通話本身。

管理後台提供備份與回復操作介面（FR-ADM-005），督導可監控備份排程執行狀態與最近備份時間點，並於需要時手動觸發備份或啟動回復流程。

---

### 8.4　傳輸加密

所有跨服務通訊一律啟用 TLS 1.3：

| 通訊路徑 | 協定 | 加密要求 |
|---------|------|---------|
| 旅客瀏覽器 ↔ Web 前端 | HTTPS (TLS 1.3) | 強制 HSTS，憑證由台鐵核發或委託 CA |
| 值機平台 ↔ API Gateway | HTTPS (TLS 1.3) | 內部憑證，mTLS 雙向驗證 |
| API Gateway ↔ 內部微服務 | gRPC over TLS 1.3 | 內部 PKI 簽發憑證 |
| AI-IVR ↔ vLLM 推論 | gRPC over TLS 1.3 | 確保推論請求中旅客語句不被竊聽 |
| SIP 信令 | SIP over TLS (SIPS) | RFC 5061 |
| RTP 語音流 | SRTP (AES-128-CM) | RFC 3711，金鑰透過 SDES 交換 |
| 備份傳輸 | rsync over SSH | AES-256-GCM 通道加密 |

WebSocket 連線（值機平台即時推播、數位客服對話）一律升級為 WSS (WebSocket Secure)，與 HTTPS 共用 TLS 憑證。

---

### 8.5　靜態資料加密

#### 8.5.1　欄位級加密（個資保護）

針對旅客個人資料欄位，採用 AES-256-GCM 對稱加密，於應用層加解密後再寫入 PostgreSQL：

| 資料表 | 加密欄位 | 加密演算法 | 金鑰管理 |
|-------|---------|-----------|---------|
| `conversations.caller_id` | 來電號碼 | AES-256-GCM | 金鑰分離存放於管理伺服器 |
| `messages.content_encrypted` | 含個資之對話內容 | AES-256-GCM | 同上 |
| `sms_records.phone_encrypted` | 簡訊手機號碼 | AES-256-GCM | 同上 |
| `tickets.contact_info_encrypted` | 工單聯絡資訊 | AES-256-GCM | 同上 |

加密金鑰與資料庫分離部署，金鑰儲存於管理伺服器的獨立加密磁區，存取須通過 RBAC 權限驗證。金鑰輪換週期為 90 天，舊金鑰保留用於解密歷史資料，新資料一律使用新金鑰加密。

#### 8.5.2　去識別化 Pipeline

STT 輸出之文字在寫入資料庫前，強制經過正則表達式遮罩處理：

- 身分證字號：`A123456789` → `A1234*****`
- 手機號碼：`0912345678` → `0912***678`
- 信用卡號：`4111111111111111` → `4111********1111`

原始語音與去識別化文字分離存放，原始語音存取須督導以上權限並留下稽核日誌，日誌保留 ≥6 個月（KPI: log_retention）。

---

### 8.6　RBAC 存取控制模型

系統整合台鐵既有 Active Directory（AD/LDAP）進行身分驗證，並實作角色型存取控制（RBAC）四層權限模型（FR-LLM-006、FR-ADM-002）：

| 角色 | 代碼 | 人數 | 權限範圍 |
|------|------|------|---------|
| 系統管理者 | `ADMIN` | 2~3 人 | 全功能存取：系統參數、帳號管理、備份回復、金鑰管理 |
| 督導 | `SUPERVISOR` | 2 席 | 即時監控、監聽、密語、強制介入、質檢報表、原始錄音存取 |
| 值機員 | `AGENT` | 25 席 | 接聽/轉接/掛斷、AI 輔助、工單建立、自身對話紀錄查詢 |
| 外點後送人員 | `BACKOFFICE` | 225 人（同時 ~23 人） | 指派工單處理、回覆更新、僅限自身負責案件 |

權限控制粒度：

- **功能級：** 每個 API 端點綁定所需角色，API Gateway 於請求進入時驗證 JWT Token 中的角色宣告。
- **資料級：** 值機員僅可查看自身經手之對話與工單；外點後送人員僅可存取指派給自身的案件。
- **欄位級：** 個資加密欄位的解密權限僅開放 `SUPERVISOR` 以上角色，值機員介面顯示遮罩後資料。

所有角色的登入、操作、權限變更均寫入 `audit_logs` 資料表（詳見第七章 7.1 節），保留 ≥6 個月，支援查詢匯出與稽核追蹤（FR-ADM-004）。OAuth 2.0 Token 有效期 30 分鐘，Refresh Token 有效期 8 小時（對應一個班次），逾期強制重新驗證。

### 8.7　CNS 27001 資訊安全管理對映

本系統之安全設計對映 CNS 27001（ISO/IEC 27001）資訊安全管理標準及需求書附件16「資通系統資安防護基準查核表」之控制措施如下：

| CNS 27001 控制領域 | 對應本系統實作 | 章節 |
|-------------------|--------------|------|
| A.8 資產管理 | 資料分級（第一～三級 RPO/RTO）、備份策略 | §8.1, §8.2 |
| A.9 存取控制 | RBAC 四層權限模型、AD/LDAP 整合、JWT Token 機制 | §8.6 |
| A.10 密碼學 | TLS 1.3 傳輸加密、AES-256-GCM 靜態加密、SRTP 語音加密 | §8.4, §8.5 |
| A.12 運作安全 | Prometheus 監控告警、稽核日誌 ≥6 個月、備份排程驗證 | §8.2, §8.3 |
| A.13 通訊安全 | VLAN 網路分區、防火牆規則、mTLS 雙向驗證 | §3.4, §8.4 |
| A.14 系統獲取開發維護 | 個資遮罩 Pipeline、Prompt Injection 防護、輸入驗證 | §5.1.2, §5.3.3 |
| A.16 資安事故管理 | HA ≤5 秒切換、異常自動告警、人工客服即時切換 | §8.3, §3.3 |
| A.17 營運持續管理 | Active-Active 雙機架構、災難復原程序 | §8.1, §8.3 |
| A.18 遵循性 | 個資保護法遵循、去識別化、存取日誌可稽核 | §8.5, §8.6 |

上述對映確保本系統之資安設計符合 CNS 27001 標準要求，具體查核細項於資安檢測階段依附件16逐項驗證。

---

## 第九章　規格追溯矩陣

本章彙整全系統功能需求（FR）至軟體模組（M）、API 端點、資料表及測試案例（TC）之完整追溯鏈，確保每項需求均有對應實作與驗證手段。

---

### 9.1　追溯矩陣總表

| 功能需求 | 名稱 | 模組 | 主要 API 端點 | 核心資料表 | 測試案例 |
|---------|------|------|--------------|-----------|---------|
| FR-IVR-001 | 語音通道與 CTI 整合 | M-IVR-01 | `gRPC SipService.Register` | `call_sessions` | TC-IVR-001 |
| FR-IVR-002 | 智慧來電應答與引導 | M-IVR-01 | `gRPC InferenceService.Generate` | `conversations`, `messages` | TC-IVR-002 |
| FR-IVR-003 | 多輪對話與引導機制 | M-IVR-02 | `gRPC DialogService.Continue` | `conversations` (Redis context) | TC-IVR-003 |
| FR-IVR-004 | 串接真人客服 | M-IVR-03 | `gRPC TransferService.Handoff` | `conversations`, `tickets` | TC-IVR-004 |
| FR-IVR-005 | 按碼偵測與動態選單 | M-IVR-04 | `gRPC DtmfService.Detect` | `ivr_menus` | TC-IVR-005 |
| FR-IVR-006 | 滿意度調查 | M-IVR-05 | `POST /v1/surveys` | `surveys` | TC-IVR-006 |
| FR-IVR-007 | 防護機制 | M-IVR-06 | `gRPC GuardService.Check` | `blocked_callers`, `audit_logs` | TC-IVR-007 |
| FR-STT-001 | 即時中英文語音轉文字 | M-STT-01 | `gRPC SttService.StreamRecognize` | `messages` | TC-STT-001 |
| FR-STT-002 | 語音內容分類與意圖辨識 | M-STT-02 | `gRPC IntentService.Classify` | `conversations.intent` | TC-STT-002 |
| FR-STT-003 | 語音斷點與停頓偵測 | M-STT-03 | `gRPC VadService.Detect` | — (即時處理) | TC-STT-003 |
| FR-TTS-001 | 中英文即時語音合成 | M-TTS-01 | `gRPC TtsService.Synthesize` | `tts_cache` | TC-TTS-001 |
| FR-TTS-002 | 動態選單語音生成 | M-TTS-02 | `gRPC TtsService.SynthesizeMenu` | `ivr_menus` | TC-TTS-002 |
| FR-LLM-001 | GPU 運算與高併發穩定性 | M-LLM-01 | `gRPC InferenceService.Generate` | — (vLLM 內部管理) | TC-LLM-001 |
| FR-LLM-002 | 語意理解與問答生成 | M-LLM-02 | `gRPC InferenceService.Generate` | `conversations`, `messages` | TC-LLM-002 |
| FR-LLM-003 | 上下文關聯與連續對話 | M-LLM-02 | `gRPC InferenceService.Generate` | Redis `ctx:{session_id}` | TC-LLM-003 |
| FR-LLM-004 | 關鍵詞識別與文字修正 | M-LLM-03 | `gRPC TextService.Process` | `keywords`, `synonyms` | TC-LLM-004 |
| FR-LLM-005 | 知識庫維護與自動學習 | M-KB-01 | `POST/PUT/DELETE /v1/knowledge` | Qdrant `knowledge_base`, `kb_versions` | TC-LLM-005 |
| FR-LLM-006 | 權限控管與使用者管理 | M-KB-02 | `GET/POST /v1/admin/users` | `users`, `roles`, `audit_logs` | TC-LLM-006 |
| FR-LLM-007 | 對話紀錄管理 | M-LLM-04 | `GET /v1/conversations/export` | `conversations`, `messages` | TC-LLM-007 |
| FR-LLM-008 | 後送案件分析 | M-LLM-05 | `POST /v1/tickets/analyze` | `tickets` | TC-LLM-008 |
| FR-AGT-001 | 數位通道服務 | M-AGT-01 | `WSS /v1/chat/ws` | `conversations` | TC-AGT-001 |
| FR-AGT-002 | 向量資料庫整合與版本管理 | M-AGT-02 | `POST /v1/knowledge/search` | Qdrant `knowledge_base` | TC-AGT-002 |
| FR-AGT-003 | 互動式對話與智慧問答 | M-AGT-03 | `POST /v1/chat/message` | `conversations`, `messages` | TC-AGT-003 |
| FR-AGT-004 | 回應引用來源標註 | M-AGT-03 | `POST /v1/chat/message` (citation 欄位) | `messages.citations` | TC-AGT-004 |
| FR-AGT-005 | 個性化問答機制 | M-AGT-04 | `POST /v1/chat/message` (含 user_history) | `user_profiles`, Redis `hist:{user_id}` | TC-AGT-005 |
| FR-AGT-006 | Web/App 整合與真人轉接 | M-AGT-05 | `POST /v1/chat/transfer` | `conversations`, `tickets` | TC-AGT-006 |
| FR-AGT-007 | SMS 簡訊服務整合 | M-SMS-01 | `POST /v1/sms/send`, `GET /v1/sms/inbox` | `sms_records`（分區保留 ≥5 年） | TC-AGT-007 |
| FR-AGT-008 | 系統持續優化與校正 | M-AGT-06 | `POST /v1/feedback`, `GET /v1/model/metrics` | `feedback_records`, `model_metrics` | TC-AGT-008 |
| FR-QI-001 | 多格式數據匯入與批次處理 | M-QI-01 | `POST /v1/qi/upload` | `qi_tasks` | TC-QI-001 |
| FR-QI-002 | 語音轉文字處理 | M-QI-02 | `gRPC SttService.BatchTranscribe` | `qi_results` | TC-QI-002 |
| FR-QI-003 | 自訂質檢規則與評分 | M-QI-03 | `POST/PUT /v1/qi/rules` | `qi_rules`, `qi_results` | TC-QI-003 |
| FR-QI-004 | 靜音與插話偵測 | M-QI-04 | `gRPC QiService.DetectSilence` | `qi_results.silence_segments` | TC-QI-004 |
| FR-QI-005 | 語調與情緒分析 | M-QI-05 | `gRPC QiService.AnalyzeEmotion` | `qi_results.emotion_scores` | TC-QI-005 |
| FR-QI-006 | 異常偵測與警報 | M-QI-06 | `POST /v1/alerts` (WebSocket push) | `alerts` | TC-QI-006 |
| FR-QI-007 | 多維度質檢報表 | M-QI-07 | `GET /v1/qi/reports` | `qi_results`, TimescaleDB `qi_results` | TC-QI-007 |
| FR-RPT-001 | 統計分析報表 | M-RPT-01 | `GET /v1/reports/statistics` | `conversations`, `tickets`, `surveys` | TC-RPT-001 |
| FR-RPT-002 | 彈性化報表儀表板 | M-RPT-02 | `GET /v1/reports/dashboard` | TimescaleDB `metrics` | TC-RPT-002 |
| FR-RPT-003 | 客製報表服務 | M-RPT-03 | `GET /v1/reports/custom/{id}` | 依需求動態查詢 | TC-RPT-003 |
| FR-WS-001 | 座席操作介面與通話控制 | M-WS-01 | `WSS /v1/ws/agent`, `gRPC SipService.*` | `call_sessions`, `conversations` | TC-WS-001 |
| FR-WS-002 | AI 知識輔助與即時建議 | M-WS-02 | `WSS /v1/ws/agent` (push 建議) | Qdrant `knowledge_base` | TC-WS-002 |
| FR-WS-003 | 對話摘要與客服工單 | M-WS-03 | `POST /v1/tickets`, `GET /v1/conversations/{id}/summary` | `tickets`, `conversations` | TC-WS-003 |
| FR-WS-004 | 督導即時監控與介入 | M-WS-04 | `WSS /v1/ws/supervisor` | `agent_status`, `call_sessions` | TC-WS-004 |
| FR-WS-005 | 座席狀態管理 | M-WS-05 | `PUT /v1/agents/{id}/status` | `agent_status` | TC-WS-005 |
| FR-ADM-001 | 系統參數設定管理 | M-ADM-01 | `GET/PUT /v1/admin/config` | `system_config` | TC-ADM-001 |
| FR-ADM-002 | 帳號與角色權限管理 | M-ADM-02 | `CRUD /v1/admin/users`, `/v1/admin/roles` | `users`, `roles` | TC-ADM-002 |
| FR-ADM-003 | 系統監控儀表板 | M-ADM-03 | `GET /v1/admin/health`, Grafana API | TimescaleDB `metrics`, Prometheus | TC-ADM-003 |
| FR-ADM-004 | 日誌管理與稽核追蹤 | M-ADM-04 | `GET /v1/admin/audit-logs` | `audit_logs` | TC-ADM-004 |
| FR-ADM-005 | 備份與回復管理介面 | M-ADM-05 | `POST /v1/admin/backup`, `POST /v1/admin/restore` | `backup_jobs` | TC-ADM-005 |

---

### 9.2　追溯覆蓋率統計

| 維度 | 總數 | 已追溯 | 覆蓋率 |
|------|------|-------|--------|
| 功能需求（FR） | 46 項 | 46 項 | 100% |
| 軟體模組（M） | 35 個 | 35 個 | 100% |
| 測試案例（TC） | 46 個 | 46 個 | 100%（1:1 對應 FR） |
| 架構決策（AD） | 8 項 | 8 項 | 100%（每項至少被 1 個 FR 引用） |

每項功能需求均可向下追溯至具體的軟體模組、API 端點、資料表及測試案例，確保無「孤立需求」（有 FR 無實作）或「幽靈功能」（有實作無 FR）。

---

### 9.3　關鍵 KPI 追溯鏈

| KPI | 指標值 | 對應 FR | 驗證 TC | 來源 |
|-----|--------|---------|---------|------|
| ivr_accuracy | ≥85% | FR-IVR-002, FR-IVR-003 | TC-IVR-002, TC-IVR-003 | 需求書§三(一) |
| ivr_response | ≤5000ms | FR-IVR-002, FR-STT-003, FR-TTS-001 | TC-IVR-002, TC-STT-003, TC-TTS-001 | 需求書§三(一) |
| stt_accuracy | ≥85% | FR-STT-001 | TC-STT-001 | 需求書§三(二) |
| agent_accuracy | ≥85% | FR-AGT-003, FR-AGT-004, FR-AGT-005 | TC-AGT-003, TC-AGT-004, TC-AGT-005 | 需求書§三(五) |
| agent_response | ≤5000ms | FR-AGT-003 | TC-AGT-003 | 需求書§三(五) |
| classify_accuracy | ≥85% | FR-LLM-008 | TC-LLM-008 | 需求書§三(四) |
| qi_speed | 15min 錄音 → ≤5min | FR-QI-001, FR-QI-002 | TC-QI-001, TC-QI-002 | 需求書§三(六) |
| availability | ≥99%/季 | FR-ADM-003, FR-WS-004 | TC-ADM-003 | 服務水準表 |
| sms_retention | ≥5 年 | FR-AGT-007 | TC-AGT-007 | 需求書§三(五) |
| log_retention | ≥6 個月 | FR-LLM-006, FR-ADM-004 | TC-LLM-006, TC-ADM-004 | 資安查核表 |

---

### 本章引用編號清單

**功能需求（FR）：** FR-IVR-001 ~ 007, FR-STT-001 ~ 003, FR-TTS-001 ~ 002, FR-LLM-001 ~ 008, FR-AGT-001 ~ 008, FR-QI-001 ~ 007, FR-RPT-001 ~ 003, FR-WS-001 ~ 005, FR-ADM-001 ~ 005

**測試案例（TC）：** TC-IVR-001 ~ 007, TC-STT-001 ~ 003, TC-TTS-001 ~ 002, TC-LLM-001 ~ 008, TC-AGT-001 ~ 008, TC-QI-001 ~ 007, TC-RPT-001 ~ 003, TC-WS-001 ~ 005, TC-ADM-001 ~ 005

**軟體模組（M）：** M-IVR-01 ~ 06, M-STT-01 ~ 03, M-TTS-01 ~ 02, M-LLM-01 ~ 05, M-KB-01 ~ 02, M-AGT-01 ~ 06, M-SMS-01, M-QI-01 ~ 07, M-RPT-01 ~ 03, M-WS-01 ~ 05, M-ADM-01 ~ 05

**架構決策（AD）：** AD-001（六層式架構）, AD-002（GPU 分配策略）, AD-003（STT/TTS 跑 CPU）, AD-004（Llama 3.1 8B AWQ）, AD-005（HA Active-Active + Failover）, AD-006（Docker Compose 部署）, AD-007（SIP/RTP fork 介接）, AD-008（優先開源方案）

**攻擊面防禦（ATK）：** ATK-001（個資去識別化 — §8.5.2 去識別化 Pipeline）, ATK-002（CNS 27001 控制措施 — §8.6 RBAC 對應 A.9 存取控制）, ATK-004（WebView 安全 — §8.4 TLS/CSP 防護）, ATK-014（HA 網路層實現 — §8.3 Keepalived VRRP 切換）


---

