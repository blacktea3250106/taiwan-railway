# 程式設計書

**案號：** L0215P2010U
**版本：** 1.0
**日期：** 中華民國 115 年

---

本章內容詳見 `10_程式設計書_ch1.md`。

內容摘要：

- **§1.1 清單說明** — 編號體系對照（P/FR/M/TC），說明 45 支程式與 48 項 FR 的對應關係
- **§1.2 程式功能清單** — 依 11 個子系統分組，每組以表格列出程式代號、名稱、所屬 FR、所屬模組與簡述，所有編號均從 `cross_reference_map.yaml` 讀取，技術數字從 `decisions.yaml` 引用
- **§1.3 程式統計摘要** — 彙總表 + 3 項合併實作的技術理由說明（P-IVR-01、P-LLM-02、P-AGT-03）

全文約 3,200 字，預估排版 3~4 頁。所有 FR 編號與 #02、模組編號與 #03 完全對齊。


---

本章內容詳見 `10_程式設計書_ch2.md`。

**內容摘要：**

- **§2.1 P-LLM-01** — vLLM 推論引擎：GPU#0 綁定、6 實例 × ~8GB VRAM、gRPC 介面、健康檢查與自動重啟機制
- **§2.2 P-LLM-02** — 語意理解與對話引擎（合併 FR-LLM-002 + 003）：完整 RAG Pipeline 七階段（查詢改寫→向量檢索→Rerank→Prompt 組裝→LLM 生成→Citation 抽取→信心度三層路由），多輪對話 Redis 上下文管理，資料庫表格詳列
- **§2.3 P-LLM-03** — 文字處理引擎：同義詞擴展、錯別字修正（Levenshtein + 台鐵專屬字典）、敏感詞過濾、繁體中文校驗
- **§2.4 P-LLM-04** — 對話紀錄管理：五格式匯出（Word/PDF/Excel/HTML/CSV）、個資去識別化
- **§2.5 P-LLM-05** — 後送案件分析：自動分類 + 優先級 + 情感分析，正確率 ≥85%
- **§2.6 P-KB-01** — 知識庫管理引擎：CRUD、版本 snapshot、增量 Embedding 更新、Qdrant Collection 管理
- **§2.7 P-KB-02** — 知識庫權限控管：RBAC + AD/LDAP 整合、個資存取日誌隔離
- **§2.8 模組間介面總覽** — gRPC（內部）/ REST（對外）呼叫關係圖

全文約 3,200 字，預估排版 6~7 頁。ATK-008（三層防線）自然融入 §2.2 信心度回應策略，ATK-020（知識庫覆蓋率）自然融入 §2.6 增量更新機制。所有數字來源 `decisions.yaml`、編號來源 `cross_reference_map.yaml`。


---

本章內容詳見 `10_程式設計書_ch3.md`。

**內容摘要：**

- **§3.1 P-STT-01** — 即時語音辨識引擎：faster-whisper（CTranslate2）串流模式、三階段音訊前處理（重採樣/正規化/RNNoise 降噪）、台鐵專屬詞彙 hotword boosting，30 路並行約 9 CPU 核心
- **§3.2 P-STT-02** — 意圖辨識：LLM few-shot 分類、四類路由決策規則（api_query / ai_answer / transfer_human / 引導結束）
- **§3.3 P-STT-03** — VAD 語音活動偵測：Silero VAD 神經網路模型，**針對類比線路差異化參數配置**（自然防禦 ATK-006）
- **§3.4 P-TTS-01** — 語音合成引擎：Coqui XTTS-v2 串流合成（首包 ≤300ms）、Redis 語音快取（500 條常用語句）、**三引擎抽象介面 + 一鍵切換 MeloTTS/Piper 備案（註：MeloTTS 開發團隊 MyShell AI 之資本結構須經產地合規查證確認無陸資背景，若查證不通過則以 Piper 為唯一備案）**（自然防禦 ATK-011）
- **§3.5 P-TTS-02** — 動態選單合成：SSML 標記模板、管理後台自助編輯、自動快取更新
- **§3.6 模組間介面總覽** — 完整呼叫鏈與延遲預算分配（合計 ≤4,600ms，餘裕 400ms）

全文約 3,100 字，預估排版 5~6 頁。所有數字來源 `decisions.yaml`、編號來源 `cross_reference_map.yaml`。


---

本章內容詳見 `10_程式設計書_ch4.md`。

**內容摘要：**

- **§4.1 P-AGT-01** — 數位通道管理：WebSocket ≥30 埠併發、Redis 跨機 Session 共享（AD-005）、連線池 asyncio 管理
- **§4.2 P-AGT-02** — 向量檢索引擎：Qdrant HNSW + multilingual-e5-large（GPU#1）、Top-K <200ms、知識庫版本管理（alias 原子切換）
- **§4.3 P-AGT-03** — 智慧問答 + Citation（合併 FR-AGT-003 + 004）：RAG Pipeline 延遲預算、footnote Citation 標註、信心度三層路由（防禦 ATK-008）
- **§4.4 P-AGT-04** — 個性化引擎：歷史摘要注入 Prompt（≤200 token）、匿名化 user_id 存取、個資保護
- **§4.5 P-AGT-05** — Web/App 轉接：對話摘要 + WebSocket 推播至值機平台
- **§4.6 P-SMS-01** — SMS 簡訊服務：雙備援 Active-Standby、AI 自動回覆同步通知客服、5 年保留 TimescaleDB 分割（防禦 ATK-021 產地合規）
- **§4.7 P-AGT-06** — 持續優化校正：督導標記→錯誤分類→知識庫更新建議閉環（防禦 ATK-020）
- **§4.8~4.14 P-QI-01~07** — 質檢完整 Pipeline：匯入排程→STT 轉寫（批次 RTF 0.3x）→規則評分引擎→靜音/插話偵測→情緒分析（GPU#1 批次）→異常警報→多維度報表
- **§4.15 模組間介面總覽** — Agent 延遲預算合計 ≤3,150ms（餘裕 1,850ms）；QI Pipeline 時間預算約 371 秒

全文約 3,800 字，預估排版 7~8 頁。ATK-008、ATK-020、ATK-021 自然融入行文。所有數字來源 `decisions.yaml`、編號來源 `cross_reference_map.yaml`。


---

本章內容詳見 `10_程式設計書_ch5.md`。

**內容摘要：**

- **§5.1 MES Server 整合** — RTP fork 被動接收機制、SIP REFER 轉接、零衝擊原則（防禦 ATK-005、ATK-012）
- **§5.2 E1 VoIP Gateway 整合** — SIP Trunk 註冊、DTMF 雙模偵測、行政交換機類比線路 G.711 轉換與 VAD 調校（防禦 ATK-006）
- **§5.3 WebCall SBC 整合** — 雙 SBC SIP Trunk 註冊、failover ≤5 秒、切換期間通話不中斷（防禦 ATK-007）
- **§5.4 CRM Gateway 整合** — WebSocket 即時通訊 + REST API、SMS 雙備援整合、國發會 API 規範
- **§5.5 AD/LDAP 整合** — LDAPS 帳號驗證、RBAC 角色對應、SSO 預留介面
- **§5.6 訂票/時刻表系統整合** — LLM Tool Use 即時查詢、API Adapter 抽象層、個資保護
- **§5.7 整合介面彙總表** — 9 個外部系統介面一覽

全文約 2,800 字，預估排版 4 頁。所有編號與 decisions.yaml / cross_reference_map.yaml 對齊，自然防禦 ATK-005/006/007/012/015。


---

