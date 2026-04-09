# 第十一章　原始程式碼光碟

**案號：** L0215P2010U
**版本：** 1.0
**日期：** 中華民國 115 年

---

## 11.1　光碟內容說明與目錄結構

本光碟收錄台鐵 AI 客服系統全部原始程式碼、AI 模型權重、組態檔、部署腳本及開源授權文件，供台鐵完整保有系統重建能力。光碟標籤格式依契約規定標註案號 L0215P2010U、版本號、燒錄日期與內容摘要；交付份數為正本 2 份、副本 1 份。

### 光碟總目錄結構

```
L0215P2010U-SOURCE/
├── README.md                          # 光碟說明文件（本章內容）
├── CHECKSUMS.sha256                   # 全檔案 SHA-256 校驗清單
├── src/                               # 原始程式碼
│   ├── backend/                       # 後端服務（Python 3.11+ / FastAPI）
│   │   ├── services/
│   │   │   ├── llm_engine/            # P-LLM-01~05  LLM 推論與分析
│   │   │   ├── stt_engine/            # P-STT-01~03  語音辨識
│   │   │   ├── tts_engine/            # P-TTS-01~02  語音合成
│   │   │   ├── rag_pipeline/          # P-AGT-02~03  RAG 檢索增強生成
│   │   │   ├── ivr_gateway/           # P-IVR-01~06  SIP/RTP 語音接入
│   │   │   ├── agent_service/         # P-AGT-01,04~06  數位客服
│   │   │   ├── qi_engine/             # P-QI-01~07   智慧質檢
│   │   │   ├── sms_service/           # P-SMS-01     簡訊服務
│   │   │   ├── report_engine/         # P-RPT-01~03  報表引擎
│   │   │   ├── kb_manager/            # P-KB-01~02   知識庫管理
│   │   │   ├── ws_platform/           # P-WS-01~05   值機平台後端
│   │   │   └── admin_service/         # P-ADM-01~05  管理後台後端
│   │   ├── common/                    # 共用模組（認證、日誌、工具）
│   │   ├── db/
│   │   │   ├── migrations/            # PostgreSQL Schema Migration（Alembic）
│   │   │   ├── qdrant_init/           # Qdrant Collection 定義與初始化
│   │   │   └── redis_config/          # Redis 快取策略與預熱腳本
│   │   ├── api/                       # API Gateway 與路由定義
│   │   └── tests/                     # 單元測試與整合測試原始碼
│   └── frontend/                      # 前端原始碼（React 18+ / Next.js / Ant Design）
│       ├── workstation/               # 值機平台 UI（P-WS-01~05）
│       ├── admin/                     # 管理後台 UI（P-ADM-01~05）
│       ├── agent-widget/              # AI-Agent 數位客服嵌入元件（P-AGT-01~06）
│       ├── kb-console/                # 知識庫管理 UI（P-KB-01~02）
│       ├── dashboard/                 # 報表儀表板 UI（P-RPT-01~03）
│       └── shared/                    # 共用元件與樣式
├── models/                            # AI 模型權重（詳見 §11.3）
├── config/                            # 組態檔與環境變數範本
├── deploy/                            # Docker 映像定義與部署腳本（詳見 §11.4）
├── licenses/                          # 開源軟體授權文件（詳見 §11.5）
├── docs/
│   ├── openapi.yaml                   # OpenAPI 3.0 API 規格檔
│   └── build-from-source.md           # 從光碟重建系統之步驟說明
└── tools/                             # 開發與測試工具
    ├── lint/                          # Linting 規則（Ruff / ESLint）
    ├── ci/                            # CI 配置檔
    └── scripts/
        └── detect_simplified_cn.py    # 簡體中文偵測腳本
```

目錄結構對應 #03 程式設計規格報告書 §3.2~3.8 各元件設計之模組劃分。每個子目錄均包含該模組的 `README.md`，標註對應之 FR 編號、所屬模組編號（M-*）、程式語言及行數統計。

---

## 11.2　原始程式碼清單

系統共計 **11 個子系統、45 支程式**，對應 48 項功能需求（FR）。3 支程式因功能高度耦合採合併實作（詳見 #10 程式設計書 §1.3）：P-IVR-01 合併 FR-IVR-001 + 002；P-LLM-02 合併 FR-LLM-002 + 003；P-AGT-03 合併 FR-AGT-003 + 004。

### 11.2.1　後端程式清單（Python 3.11+ / FastAPI）

**AI 服務層**

| 程式代號 | 程式名稱 | 對應 FR | 所屬模組 | 目錄路徑 | 語言 |
|---------|---------|---------|---------|---------|------|
| P-LLM-01 | LLM 推論引擎 | FR-LLM-001 | M-LLM-01 | `src/backend/services/llm_engine/inference.py` | Python |
| P-LLM-02 | 語意理解與對話引擎 | FR-LLM-002, 003 | M-LLM-02 | `src/backend/services/llm_engine/dialogue.py` | Python |
| P-LLM-03 | 關鍵詞識別與文字修正 | FR-LLM-004 | M-LLM-03 | `src/backend/services/llm_engine/text_proc.py` | Python |
| P-LLM-04 | 對話紀錄管理 | FR-LLM-007 | M-LLM-04 | `src/backend/services/llm_engine/history.py` | Python |
| P-LLM-05 | 後送案件分析 | FR-LLM-008 | M-LLM-05 | `src/backend/services/llm_engine/case_analysis.py` | Python |
| P-STT-01 | 即時語音辨識 | FR-STT-001 | M-STT-01 | `src/backend/services/stt_engine/recognizer.py` | Python |
| P-STT-02 | 意圖辨識 | FR-STT-002 | M-STT-02 | `src/backend/services/stt_engine/intent.py` | Python |
| P-STT-03 | VAD 語音活動偵測 | FR-STT-003 | M-STT-03 | `src/backend/services/stt_engine/vad.py` | Python |
| P-TTS-01 | 語音合成引擎 | FR-TTS-001 | M-TTS-01 | `src/backend/services/tts_engine/synthesizer.py` | Python |
| P-TTS-02 | 動態選單語音生成 | FR-TTS-002 | M-TTS-02 | `src/backend/services/tts_engine/menu_gen.py` | Python |

**通道接入層**

| 程式代號 | 程式名稱 | 對應 FR | 所屬模組 | 目錄路徑 | 語言 |
|---------|---------|---------|---------|---------|------|
| P-IVR-01 | SIP Gateway 與 CTI 整合 | FR-IVR-001, 002 | M-IVR-01 | `src/backend/services/ivr_gateway/sip_cti.py` | Python |
| P-IVR-02 | 多輪對話引擎 | FR-IVR-003 | M-IVR-02 | `src/backend/services/ivr_gateway/dialogue.py` | Python |
| P-IVR-03 | 真人轉接 | FR-IVR-004 | M-IVR-03 | `src/backend/services/ivr_gateway/transfer.py` | Python |
| P-IVR-04 | DTMF 與動態選單 | FR-IVR-005 | M-IVR-04 | `src/backend/services/ivr_gateway/dtmf.py` | Python |
| P-IVR-05 | 滿意度調查 | FR-IVR-006 | M-IVR-05 | `src/backend/services/ivr_gateway/survey.py` | Python |
| P-IVR-06 | 通話防護機制 | FR-IVR-007 | M-IVR-06 | `src/backend/services/ivr_gateway/guard.py` | Python |
| P-AGT-01 | 數位通道管理 | FR-AGT-001 | M-AGT-01 | `src/backend/services/agent_service/channel.py` | Python |
| P-SMS-01 | SMS 簡訊服務 | FR-AGT-007 | M-SMS-01 | `src/backend/services/sms_service/gateway.py` | Python |

**業務邏輯層**

| 程式代號 | 程式名稱 | 對應 FR | 所屬模組 | 目錄路徑 | 語言 |
|---------|---------|---------|---------|---------|------|
| P-AGT-02 | 向量資料庫整合 | FR-AGT-002 | M-AGT-02 | `src/backend/services/rag_pipeline/vectordb.py` | Python |
| P-AGT-03 | 智慧問答與 Citation | FR-AGT-003, 004 | M-AGT-03 | `src/backend/services/rag_pipeline/qa_engine.py` | Python |
| P-AGT-04 | 個性化問答 | FR-AGT-005 | M-AGT-04 | `src/backend/services/agent_service/personalize.py` | Python |
| P-AGT-05 | Web/App 整合與真人轉接 | FR-AGT-006 | M-AGT-05 | `src/backend/services/agent_service/web_bridge.py` | Python |
| P-AGT-06 | 持續優化校正 | FR-AGT-008 | M-AGT-06 | `src/backend/services/agent_service/optimizer.py` | Python |
| P-QI-01 | 質檢數據匯入 | FR-QI-001 | M-QI-01 | `src/backend/services/qi_engine/ingest.py` | Python |
| P-QI-02 | 質檢語音轉寫 | FR-QI-002 | M-QI-02 | `src/backend/services/qi_engine/transcribe.py` | Python |
| P-QI-03 | 質檢規則引擎 | FR-QI-003 | M-QI-03 | `src/backend/services/qi_engine/rules.py` | Python |
| P-QI-04 | 靜音與插話偵測 | FR-QI-004 | M-QI-04 | `src/backend/services/qi_engine/silence_detect.py` | Python |
| P-QI-05 | 情緒分析 | FR-QI-005 | M-QI-05 | `src/backend/services/qi_engine/emotion.py` | Python |
| P-QI-06 | 質檢警報 | FR-QI-006 | M-QI-06 | `src/backend/services/qi_engine/alert.py` | Python |
| P-QI-07 | 質檢報表 | FR-QI-007 | M-QI-07 | `src/backend/services/qi_engine/report.py` | Python |
| P-RPT-01 | 統計分析報表 | FR-RPT-001 | M-RPT-01 | `src/backend/services/report_engine/analytics.py` | Python |
| P-RPT-02 | 儀表板引擎 | FR-RPT-002 | M-RPT-02 | `src/backend/services/report_engine/dashboard.py` | Python |
| P-RPT-03 | 客製報表 | FR-RPT-003 | M-RPT-03 | `src/backend/services/report_engine/custom.py` | Python |
| P-KB-01 | 知識庫管理 | FR-LLM-005 | M-KB-01 | `src/backend/services/kb_manager/crud.py` | Python |
| P-KB-02 | 知識庫權限管理 | FR-LLM-006 | M-KB-02 | `src/backend/services/kb_manager/acl.py` | Python |

**平台層**

| 程式代號 | 程式名稱 | 對應 FR | 所屬模組 | 目錄路徑 | 語言 |
|---------|---------|---------|---------|---------|------|
| P-WS-01 | 座席操作與通話控制（後端） | FR-WS-001 | M-WS-01 | `src/backend/services/ws_platform/seat_ctrl.py` | Python |
| P-WS-02 | AI 知識輔助（後端） | FR-WS-002 | M-WS-02 | `src/backend/services/ws_platform/ai_assist.py` | Python |
| P-WS-03 | 對話摘要與工單（後端） | FR-WS-003 | M-WS-03 | `src/backend/services/ws_platform/ticket.py` | Python |
| P-WS-04 | 督導監控（後端） | FR-WS-004 | M-WS-04 | `src/backend/services/ws_platform/supervisor.py` | Python |
| P-WS-05 | 座席狀態管理（後端） | FR-WS-005 | M-WS-05 | `src/backend/services/ws_platform/status.py` | Python |
| P-ADM-01 | 系統參數設定 | FR-ADM-001 | M-ADM-01 | `src/backend/services/admin_service/config.py` | Python |
| P-ADM-02 | 帳號與角色權限 | FR-ADM-002 | M-ADM-02 | `src/backend/services/admin_service/auth.py` | Python |
| P-ADM-03 | 系統監控儀表板（後端） | FR-ADM-003 | M-ADM-03 | `src/backend/services/admin_service/monitor.py` | Python |
| P-ADM-04 | 日誌管理與稽核 | FR-ADM-004 | M-ADM-04 | `src/backend/services/admin_service/audit.py` | Python |
| P-ADM-05 | 備份與回復管理 | FR-ADM-005 | M-ADM-05 | `src/backend/services/admin_service/backup.py` | Python |

### 11.2.2　前端程式清單（React 18+ / Next.js / Ant Design）

| 前端模組 | 對應程式 | 目錄路徑 | 語言 |
|---------|---------|---------|------|
| 值機平台 UI | P-WS-01~05 | `src/frontend/workstation/` | TypeScript/React |
| 督導監控 UI | P-WS-04 | `src/frontend/workstation/supervisor/` | TypeScript/React |
| 管理後台 UI | P-ADM-01~05 | `src/frontend/admin/` | TypeScript/React |
| 知識庫管理 UI | P-KB-01~02 | `src/frontend/kb-console/` | TypeScript/React |
| 報表儀表板 UI | P-RPT-01~03 | `src/frontend/dashboard/` | TypeScript/React |
| AI-Agent 嵌入元件 | P-AGT-01~06 | `src/frontend/agent-widget/` | TypeScript/React |

### 11.2.3　程式統計摘要

| 子系統 | 後端程式數 | 前端模組數 | 對應 FR 數 |
|--------|-----------|-----------|-----------|
| AI-IVR（語音應答） | 6 | — | 7 |
| STT（語音辨識） | 3 | — | 3 |
| TTS（語音合成） | 2 | — | 2 |
| LLM（語言模型） | 5 | — | 8 |
| AI-Agent（虛擬客服） | 5 | 1 | 8 |
| SMS（簡訊服務） | 1 | — | 1 |
| AI-QI（智慧質檢） | 7 | — | 7 |
| RPT（報表） | 3 | 1 | 3 |
| KB（知識庫） | 2 | 1 | 2 |
| WS（值機平台） | 5 | 1 | 5 |
| ADM（管理後台） | 5 | 1 | 5 |
| **合計** | **44** | **5** | **48** |

> 註：P-SMS-01 歸屬通道接入層，程式碼位於獨立 sms_service 目錄，但因僅 1 支程式故不另設前端模組，SMS 管理功能整合於管理後台 UI。

---

## 11.3　API 清單

系統對外提供 RESTful API（符合國發會共通性應用程式介面規範），對內服務間採 gRPC 通訊。以下列出對外 REST API 端點，完整規格詳見光碟 `docs/openapi.yaml`（OpenAPI 3.0 格式）。

### 11.3.1　AI-IVR 語音服務 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/ivr/calls` | GET | 查詢通話紀錄清單 | `date_from`, `date_to`, `page`, `size` | JSON（分頁） |
| `/api/v1/ivr/calls/{call_id}` | GET | 查詢單通通話詳情 | `call_id` (path) | JSON |
| `/api/v1/ivr/calls/{call_id}/transcript` | GET | 取得通話轉寫文字 | `call_id` (path) | JSON |
| `/api/v1/ivr/calls/{call_id}/transfer` | POST | 觸發轉接真人客服 | `call_id` (path), `agent_id`, `summary` | JSON |
| `/api/v1/ivr/menu` | GET | 取得目前 IVR 選單配置 | — | JSON |
| `/api/v1/ivr/menu` | PUT | 更新 IVR 選單配置 | menu tree（JSON body） | JSON |
| `/api/v1/ivr/survey/results` | GET | 查詢滿意度調查結果 | `date_from`, `date_to` | JSON（分頁） |

### 11.3.2　STT 語音辨識 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/stt/transcribe` | POST | 上傳音檔進行語音辨識 | audio file（multipart）, `language` | JSON（文字+時間戳） |
| `/api/v1/stt/stream` | WebSocket | 串流即時語音辨識 | audio chunks（binary） | JSON（逐句推送） |

### 11.3.3　LLM 問答服務 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/llm/chat` | POST | 送出問題取得 AI 回答 | `session_id`, `message`, `context` | JSON（回答+引用來源） |
| `/api/v1/llm/chat/stream` | POST | 串流式回答（SSE） | 同上 | text/event-stream |
| `/api/v1/llm/conversations` | GET | 查詢對話紀錄 | `user_id`, `date_from`, `date_to`, `page` | JSON（分頁） |
| `/api/v1/llm/conversations/{id}` | GET | 取得單筆對話完整內容 | `id` (path) | JSON |
| `/api/v1/llm/conversations/{id}/export` | GET | 匯出對話紀錄 | `id` (path), `format`（word/pdf/excel/html/csv） | 檔案下載 |

### 11.3.4　AI-Agent 數位客服 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/agent/connect` | WebSocket | 建立數位客服連線 | `token`, `channel`（web/app） | JSON（雙向訊息） |
| `/api/v1/agent/sessions` | GET | 查詢作用中的對話 | `status`, `page`, `size` | JSON（分頁） |
| `/api/v1/agent/sessions/{id}/transfer` | POST | AI 轉真人客服 | `id` (path), `reason`, `summary` | JSON |
| `/api/v1/agent/sessions/{id}/feedback` | POST | 旅客滿意度回饋 | `id` (path), `rating`, `comment` | JSON |

### 11.3.5　SMS 簡訊服務 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/sms/send` | POST | 發送簡訊 | `phone`, `content`, `template_id` | JSON |
| `/api/v1/sms/records` | GET | 查詢簡訊紀錄 | `phone`, `date_from`, `date_to`, `page` | JSON（分頁） |
| `/api/v1/sms/templates` | GET | 取得簡訊範本清單 | — | JSON |
| `/api/v1/sms/templates` | POST | 新增簡訊範本 | `name`, `content` | JSON |

### 11.3.6　智慧質檢 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/qi/tasks` | POST | 提交質檢任務 | audio files（multipart）, `rule_set_id` | JSON（task_id） |
| `/api/v1/qi/tasks/{id}` | GET | 查詢質檢任務狀態與結果 | `id` (path) | JSON |
| `/api/v1/qi/rules` | GET | 取得質檢規則清單 | — | JSON |
| `/api/v1/qi/rules` | POST | 新增質檢規則 | `name`, `criteria`, `weight` | JSON |
| `/api/v1/qi/rules/{id}` | PUT | 更新質檢規則 | `id` (path), 規則內容（JSON body） | JSON |
| `/api/v1/qi/reports` | GET | 查詢質檢報表 | `date_from`, `date_to`, `agent_id`, `type` | JSON |

### 11.3.7　後送案件分析 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/cases/analyze` | POST | 對後送案件執行 AI 分析 | `case_id`, `content` | JSON（分類+優先級+情感） |
| `/api/v1/cases/classify/batch` | POST | 批次案件分類 | case list（JSON body） | JSON |
| `/api/v1/cases/trends` | GET | 案件趨勢分析 | `date_from`, `date_to`, `category` | JSON |

### 11.3.8　知識庫管理 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/kb/documents` | GET | 查詢知識庫文件清單 | `category`, `keyword`, `page` | JSON（分頁） |
| `/api/v1/kb/documents` | POST | 新增知識庫文件 | `title`, `content`, `category`, `tags` | JSON |
| `/api/v1/kb/documents/{id}` | PUT | 更新知識庫文件 | `id` (path), 文件內容（JSON body） | JSON |
| `/api/v1/kb/documents/{id}` | DELETE | 刪除知識庫文件 | `id` (path) | JSON |
| `/api/v1/kb/documents/{id}/versions` | GET | 取得文件版本歷程 | `id` (path) | JSON |
| `/api/v1/kb/rebuild-index` | POST | 觸發向量索引重建 | `scope`（all/incremental） | JSON（task_id） |

### 11.3.9　報表與儀表板 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/reports/analytics` | GET | 查詢統計分析報表 | `type`, `date_from`, `date_to`, `dimension` | JSON |
| `/api/v1/reports/export` | POST | 匯出報表 | `report_id`, `format`（pdf/excel/csv） | 檔案下載 |
| `/api/v1/reports/custom` | GET | 查詢客製報表清單 | — | JSON |
| `/api/v1/reports/dashboard/config` | GET | 取得儀表板配置 | `user_id` | JSON |
| `/api/v1/reports/dashboard/config` | PUT | 更新儀表板配置 | 配置內容（JSON body） | JSON |

### 11.3.10　值機平台 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/ws/agents/status` | GET | 查詢所有座席狀態 | — | JSON |
| `/api/v1/ws/agents/{id}/status` | PUT | 更新座席狀態 | `id` (path), `status`（ready/busy/break） | JSON |
| `/api/v1/ws/agents/{id}/assist` | GET | 取得 AI 即時建議 | `id` (path), `call_id` | JSON（建議回覆+知識庫內容） |
| `/api/v1/ws/tickets` | POST | 建立後送工單 | `summary`, `category`, `priority`, `assignee` | JSON |
| `/api/v1/ws/tickets/{id}` | PUT | 更新工單狀態 | `id` (path), `status`, `note` | JSON |
| `/api/v1/ws/supervisor/monitor` | WebSocket | 督導即時監控 | `token` | JSON（座席狀態+通話事件推送） |

### 11.3.11　管理後台 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/admin/config` | GET | 取得系統參數 | `category` | JSON |
| `/api/v1/admin/config` | PUT | 更新系統參數 | 參數內容（JSON body） | JSON |
| `/api/v1/admin/users` | GET | 查詢使用者清單 | `role`, `page` | JSON（分頁） |
| `/api/v1/admin/users/{id}/roles` | PUT | 設定使用者角色 | `id` (path), `roles`（array） | JSON |
| `/api/v1/admin/logs` | GET | 查詢系統日誌 | `level`, `source`, `date_from`, `date_to`, `page` | JSON（分頁） |
| `/api/v1/admin/logs/export` | POST | 匯出日誌 | `filter`, `format`（csv/json） | 檔案下載 |
| `/api/v1/admin/backup/trigger` | POST | 手動觸發備份 | `scope`（full/incremental） | JSON（task_id） |
| `/api/v1/admin/backup/restore` | POST | 執行資料回復 | `backup_id`, `target` | JSON |
| `/api/v1/admin/health` | GET | 系統健康狀態 | — | JSON |

### 11.3.12　認證 API

| 端點 | 方法 | 說明 | 主要參數 | 回傳格式 |
|------|-----|------|---------|---------|
| `/api/v1/auth/login` | POST | 使用者登入（AD/LDAP） | `username`, `password` | JSON（access_token, refresh_token） |
| `/api/v1/auth/refresh` | POST | 更新存取權杖 | `refresh_token` | JSON（access_token） |
| `/api/v1/auth/logout` | POST | 使用者登出 | — | JSON |

所有 API 端點遵循以下共通規範（符合國發會共通性應用程式介面規範）：

- **版本控制**：URI 路徑含版本號 `/v1/`
- **認證方式**：OAuth 2.0 Bearer Token（經 AD/LDAP 驗證取得）
- **回傳格式**：JSON，含 `status`、`data`、`message`、`timestamp` 欄位
- **錯誤碼**：HTTP 標準狀態碼 + 自訂 error_code
- **分頁**：`page`/`size` 參數，回傳含 `total`/`page`/`size`/`items`
- **速率限制**：依角色設定 API 呼叫頻率上限

---

## 11.4　第三方元件版本清單

所有元件均為開源軟體，授權類型允許地端部署與永久使用（AD-008）。元件原始碼與授權全文收錄於光碟 `licenses/` 目錄。

### 11.4.1　AI 模型與推論引擎

| 元件名稱 | 版本 | 授權類型 | 用途 | 備註 |
|---------|------|---------|------|------|
| Llama 3.1 8B-Instruct | 3.1 | Meta Community License | LLM 推論（AWQ 4-bit 量化，~8GB VRAM） | AD-004 |
| vLLM | 0.5+ | Apache 2.0 | LLM 推論引擎（PagedAttention） | AD-004 |
| Whisper large-v3 | large-v3 | MIT License | 語音辨識模型 | AD-003 |
| faster-whisper | 1.0+ | MIT License | CTranslate2 加速版 Whisper | AD-003 |
| Coqui XTTS-v2 | v2 | MPL 2.0 | 語音合成模型 | Coqui AI 已停業，模型仍開源可用 |
| MeloTTS | 最新穩定版 | MIT License | TTS 備案方案 | 備案引擎，已驗證可行 |
| Piper | 最新穩定版 | MIT License | TTS 備案方案 | 備案引擎，已驗證可行 |
| bge-large-zh-v1.5 | 1.5 | MIT License | 中文向量 Embedding（~1.3GB） | MTEB 中文排行前三 |
| Silero VAD | 最新穩定版 | MIT License | 語音活動偵測 | P-STT-03 |

### 11.4.2　資料庫與快取

| 元件名稱 | 版本 | 授權類型 | 用途 |
|---------|------|---------|------|
| PostgreSQL | 16 | PostgreSQL License | 關聯式資料庫 |
| TimescaleDB | 最新穩定版 | Apache 2.0 | 時序資料擴展（日誌/監控） |
| Qdrant | 最新穩定版 | Apache 2.0 | 向量資料庫（HNSW 索引，Top-K <50ms） |
| Redis | 7 | BSD 3-Clause | Session Cache / 對話上下文 |

### 11.4.3　後端框架與通訊

| 元件名稱 | 版本 | 授權類型 | 用途 |
|---------|------|---------|------|
| Python | 3.11+ | PSF License | 後端主要語言 |
| FastAPI | 最新穩定版 | MIT License | REST API 框架 |
| PJSIP (pjsua2) | 最新穩定版 | GPL 2.0 | SIP/RTP 通訊堆疊 |
| gRPC (grpcio) | 最新穩定版 | Apache 2.0 | 內部服務間通訊 |
| Alembic | 最新穩定版 | MIT License | 資料庫 Migration |
| SQLAlchemy | 最新穩定版 | MIT License | ORM |
| Celery | 最新穩定版 | BSD 3-Clause | 非同步任務佇列（質檢批次） |

### 11.4.4　前端框架

| 元件名稱 | 版本 | 授權類型 | 用途 |
|---------|------|---------|------|
| React | 18+ | MIT License | 前端 UI 框架 |
| Next.js | 最新穩定版 | MIT License | React SSR 框架 |
| Ant Design | 最新穩定版 | MIT License | 企業級 UI 元件庫 |
| TypeScript | 5+ | Apache 2.0 | 前端開發語言 |

### 11.4.5　監控與部署

| 元件名稱 | 版本 | 授權類型 | 用途 |
|---------|------|---------|------|
| Prometheus | 最新穩定版 | Apache 2.0 | 指標收集與告警 |
| Grafana | 最新穩定版（OSS） | AGPL 3.0 | 視覺化監控儀表板 |
| Docker | 最新穩定版 | Apache 2.0 | 容器化部署 |
| Docker Compose | 最新穩定版 | Apache 2.0 | 多容器編排（AD-006） |
| NVIDIA Container Toolkit | 最新穩定版 | Apache 2.0 | GPU 容器支援 |
| Nginx | 最新穩定版 | BSD 2-Clause | 反向代理 / 負載均衡 |
| Keepalived | 最新穩定版 | GPL 2.0 | VIP 高可用切換（AD-005） |

### 11.4.6　GPL 授權傳染性說明

PJSIP（GPL 2.0）透過 pjsua2 Python binding 呼叫，屬於獨立程序間通訊，不構成 GPL 對其他模組的授權傳染。Keepalived 為獨立系統服務，同理不影響應用程式授權。Grafana OSS 版（AGPL 3.0）為獨立部署的監控工具，不與應用程式碼連結。授權合規性分析詳見 `licenses/COMPLIANCE.md`。

---

## 11.5　AI 模型權重與組態檔

光碟 `models/` 目錄收錄所有 AI 模型權重，確保台鐵無需外部網路即可完整重建 AI 服務。

| 模型 | 檔案大小 | 目錄路徑 | SHA-256 校驗 |
|------|---------|---------|-------------|
| Llama 3.1 8B-Instruct AWQ | ~8 GB | `models/llm/llama-3.1-8b-awq/` | 隨光碟附校驗碼 |
| Whisper large-v3 | ~3 GB | `models/stt/whisper-large-v3/` | 隨光碟附校驗碼 |
| Coqui XTTS-v2 | ~2 GB | `models/tts/xtts-v2/` | 隨光碟附校驗碼 |
| MeloTTS（備案） | ~1 GB | `models/tts/melotts/` | 隨光碟附校驗碼 |
| Piper（備案） | ~500 MB | `models/tts/piper/` | 隨光碟附校驗碼 |
| bge-large-zh-v1.5 | ~1.3 GB | `models/embedding/bge-large-zh/` | 隨光碟附校驗碼 |
| 情緒分析模型 | ~500 MB | `models/emotion/` | 隨光碟附校驗碼 |
| Silero VAD | ~5 MB | `models/vad/silero/` | 隨光碟附校驗碼 |

組態檔位於 `config/` 目錄：

| 組態檔 | 說明 |
|--------|------|
| `config/vllm.yaml` | vLLM 推論配置（GPU 分配、batch size、量化參數） |
| `config/faster-whisper.yaml` | faster-whisper 參數（模型路徑、語言、VAD 閾值） |
| `config/tts.yaml` | TTS 語音參數（語速、音調、引擎切換開關） |
| `config/qdrant.yaml` | Qdrant Collection 定義（向量維度、HNSW 參數） |
| `config/redis.yaml` | Redis 連線與快取策略 |
| `config/sip.yaml` | SIP/RTP 參數（SBC 位址、codec、DTMF 模式） |
| `.env.example` | 環境變數範本（不含實際密碼） |

TTS 引擎採三引擎抽象介面設計（詳見 #10 §3.4），透過 `config/tts.yaml` 中的 `engine` 參數即可一鍵切換 XTTS-v2 / MeloTTS / Piper，無需修改程式碼。

---

## 11.6　Docker 映像與部署腳本

系統採 Docker Compose 部署（AD-006），每個服務獨立容器映像，降低維運複雜度。

### 11.6.1　Dockerfile 清單

| 映像名稱 | 基底映像 | 說明 |
|---------|---------|------|
| `tra-llm` | `nvidia/cuda:12.x-runtime` | vLLM + Llama 3.1 推論服務 |
| `tra-stt` | `python:3.11-slim` | faster-whisper STT 服務（CPU） |
| `tra-tts` | `python:3.11-slim` | TTS 合成服務（CPU） |
| `tra-ivr` | `python:3.11-slim` | SIP Gateway / IVR 服務 |
| `tra-agent` | `python:3.11-slim` | AI-Agent 數位客服後端 |
| `tra-qi` | `python:3.11-slim` | 智慧質檢引擎 |
| `tra-api` | `python:3.11-slim` | API Gateway（FastAPI） |
| `tra-ws` | `python:3.11-slim` | 值機平台後端 |
| `tra-admin` | `python:3.11-slim` | 管理後台後端 |
| `tra-frontend` | `node:20-alpine` | 前端靜態檔建置 + Nginx 伺服 |
| `tra-qdrant` | `qdrant/qdrant` | 向量資料庫 |
| `tra-postgres` | `timescale/timescaledb` | PostgreSQL + TimescaleDB |
| `tra-redis` | `redis:7-alpine` | Redis 快取 |
| `tra-prometheus` | `prom/prometheus` | 監控指標收集 |
| `tra-grafana` | `grafana/grafana-oss` | 監控儀表板 |
| `tra-nginx` | `nginx:stable-alpine` | 反向代理 / 負載均衡 |

### 11.6.2　Docker Compose 配置

| 檔案 | 用途 |
|------|------|
| `deploy/docker-compose.prod.yml` | 正式環境（雙機 Active-Active，GPU 映射） |
| `deploy/docker-compose.test.yml` | 測試環境（單機，L40S ×1） |
| `deploy/docker-compose.dev.yml` | 開發環境（無 GPU，Mock 推論） |

### 11.6.3　部署與維運腳本

| 腳本 | 說明 |
|------|------|
| `deploy/build.sh` | 建置所有 Docker 映像 |
| `deploy/deploy.sh` | 一鍵部署（拉取映像 → 啟動服務 → 健康檢查） |
| `deploy/rollback.sh` | 回滾至指定版本 |
| `deploy/healthcheck.sh` | 全服務健康檢查（詳見 #07 §7.8） |
| `deploy/backup.sh` | 資料備份（PostgreSQL dump + Qdrant snapshot + Redis RDB） |
| `deploy/restore.sh` | 資料回復 |
| `deploy/init-db.sh` | 資料庫 Schema 初始化 + Qdrant Collection 建立 + Redis 預熱 |

---

## 11.7　光碟驗證與校驗

### 11.7.1　完整性驗證

光碟根目錄 `CHECKSUMS.sha256` 包含所有檔案的 SHA-256 雜湊值。驗證指令：

```bash
cd /media/cdrom/L0215P2010U-SOURCE
sha256sum -c CHECKSUMS.sha256
```

### 11.7.2　可建置性驗證

`docs/build-from-source.md` 提供從光碟原始碼完整重建系統的步驟：

1. 安裝基礎環境（Ubuntu 22.04 LTS + Docker + NVIDIA Driver）
2. 載入 AI 模型權重至指定目錄
3. 建置 Docker 映像（`deploy/build.sh`）
4. 初始化資料庫與向量索引（`deploy/init-db.sh`）
5. 啟動服務（`deploy/deploy.sh`）
6. 執行健康檢查（`deploy/healthcheck.sh`）

驗證紀錄：交付前於獨立測試機（測試環境 AI 伺服器，L40S ×1）完成一次從光碟到系統上線的完整建置，附終端截圖與健康檢查通過畫面佐證。

---

## 本章引用編號清單

**功能需求（FR）：** FR-IVR-001~007、FR-STT-001~003、FR-TTS-001~002、FR-LLM-001~008、FR-AGT-001~008、FR-QI-001~007、FR-RPT-001~003、FR-WS-001~005、FR-ADM-001~005（共 48 項）

**測試案例（TC）：** TC-IVR-001~007、TC-STT-001~003、TC-TTS-001~002、TC-LLM-001~008、TC-AGT-001~008、TC-QI-001~007、TC-RPT-001~003、TC-WS-001~005、TC-ADM-001~005（1:1 對應 FR）

**架構決策（AD）：** AD-001（六層式架構）、AD-002（GPU 分工）、AD-003（STT/TTS 跑 CPU）、AD-004（Llama 3.1 8B AWQ）、AD-005（HA Active-Active）、AD-006（Docker Compose 部署）、AD-007（SIP/RTP fork 介接）、AD-008（開源優先）

**攻擊面防禦（ATK）：** ATK-011（台鐵保有完整原始碼與自主重建能力）、ATK-015（開源模型完整交付，授權永久可用）、ATK-016（GPL 傳染性範圍確認、授權合規）、ATK-017（交付物完整性）、ATK-024（文件格式合規、簡體偵測工具交付）
