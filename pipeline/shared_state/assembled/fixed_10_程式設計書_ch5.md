## 第五章　軟體整合說明

本章說明本系統與台鐵既有系統之整合機制。AI 客服系統採六層式架構（AD-001），AI 模組獨立於既有系統之外，所有整合均透過標準化介面通訊，不修改既有系統任何設定或組態，確保導入過程零衝擊。各整合介面之詳細信令流程圖與延遲預算分配，詳見 #03 程式設計規格報告書第四章；介面規格書詳見 #06 軟硬體清單及系統架構圖。

---

### 5.1　MES Server 整合（SIP/RTP）

**整合對象：** Media Exchange Server（既有話務分派與錄音伺服器）
**整合方式：** RTP fork + SIP 事件訂閱
**相關程式：** P-IVR-01（FR-IVR-001、FR-IVR-002）
**相關決策：** AD-007（SIP/RTP fork 方式介接既有語音系統）

#### 整合機制

AI-IVR 以被動方式接收 MES Server 的 RTP fork 語音流副本，不攔截、不修改、不影響原始通話路徑。MES Server 在建立通話時，將 RTP 語音流複製一份傳送至 AI-IVR 伺服器，AI-IVR 僅對副本進行 STT→LLM→TTS 處理，原始通話路徑完全不受影響。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **通訊協定** | SIP（信令）+ RTP（語音流），PJSIP pjsua2 Python binding |
| **資料方向** | MES → AI-IVR（RTP fork 單向複製）；AI-IVR → MES（SIP REFER 轉接指令） |
| **音訊格式** | G.711 μ-law / A-law，64kbps PCM |
| **事件訂閱** | 透過 SIP SUBSCRIBE/NOTIFY 訂閱通話狀態（來電通知、保留、掛斷），推送至值機平台（P-WS-01） |
| **轉接機制** | AI-IVR 判定需轉接真人時，發送 SIP REFER 至 MES，由 MES 執行實際的通話路由切換（P-IVR-03） |

#### 整合約束

- MES Server 端僅需設定 RTP fork 目的 IP（AI-IVR 伺服器 VIP），不修改話務分派邏輯或錄音設定
- AI-IVR 伺服器雙機以 Active-Active 架構部署（AD-005），透過 Keepalived VIP 接收 RTP fork 流量，任一台故障時自動切換，MES 端無需任何調整
- RTP fork 為語音流複製，不佔用 E1 B-channel 通道容量：現有 1 條 E1 的 30 個 B-channel 供人工客服與 AI-IVR 共用的是 SIP 信令通道，RTP fork 副本透過 LAN 傳送，不經過 E1 線路

---

### 5.2　E1 VoIP Gateway 整合（SIP Trunk）

**整合對象：** PSTN E1 VoIP Gateway（公眾電話語音來源）
**整合方式：** SIP Trunk 註冊
**相關程式：** P-IVR-01（FR-IVR-001）
**相關決策：** AD-007

#### 整合機制

AI-IVR 透過 PJSIP 建立 SIP UA（User Agent），以 SIP Trunk 方式向 VoIP Gateway 註冊，接收從 E1 專線進入的 PSTN 語音通話。現有 1 條 E1 提供 30 個 B-channel（每 channel 64kbps），系統架構支援最多 2 條 E1 擴充。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **通訊協定** | SIP Trunk（UDP/TCP 5060）、SRTP 加密（選配） |
| **信令流程** | E1 來電 → VoIP Gateway 轉 SIP INVITE → MES 分派 → RTP fork 至 AI-IVR |
| **DTMF 偵測** | 支援 RFC 2833（RTP 事件）與 SIP INFO 雙模式（P-IVR-04），自動偵測 Gateway 支援模式 |
| **通道監控** | 即時回報通道佔用數至管理後台（P-ADM-01），達 27 路（90%）觸發容量告警 |

#### 行政交換機路徑

行政交換機（02-2381-5226）為類比線路，經 VoIP Gateway 以 G.711 編碼轉換為數位信號後，經 MES 路由至 AI-IVR。類比→數位轉換採用 G.711 PCM 編碼（64kbps），語音品質損失極小。P-STT-01 的音訊前處理 Pipeline 針對類比線路來源設定差異化的 VAD 參數與降噪門檻值，以因應背景雜訊高於數位線路的特性（詳見第三章 §3.1）。

#### 異常處理

- SIP 註冊失敗時每 30 秒自動重試，連續 3 次失敗後發送告警至值班人員
- 系統日誌記錄所有 SIP 信令事件（SIP INVITE/BYE/REFER/REGISTER），保留 ≥6 個月
- AI-IVR 異常時，通話由 MES 依原有規則分派至人工客服，旅客不受影響

---

### 5.3　WebCall SBC 整合（SIP Trunk Failover）

**整合對象：** WebCall Session Border Controller（雙備援）
**整合方式：** SIP Trunk 雙註冊 + 自動 Failover
**相關程式：** P-IVR-01（FR-IVR-001）
**相關決策：** AD-005、AD-007

#### 整合機制

台鐵既有系統配置兩台 WebCall SBC 確保網頁電話服務穩定性。AI-IVR 的 SIP UA 同時向 Primary 與 Secondary SBC 進行雙重 SIP Trunk 註冊，正常時僅接收 Primary SBC 的語音流，Primary 故障時自動切換至 Secondary，failover 時間目標 ≤5 秒。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **通訊協定** | SIP Trunk over TLS（WebCall 為網頁來源，強制加密） |
| **Failover 策略** | PJSIP 每 5 秒向雙 SBC 發送 SIP OPTIONS 心跳探測；Primary 連續 2 次無回應即標記為不可用，流量切至 Secondary |
| **切換影響** | 切換期間已建立的通話由 MES 維持，AI-IVR 僅遺失該通的 AI 輔助功能，通話本身不中斷 |
| **回切機制** | Primary 恢復後，新通話自動回到 Primary，既有通話維持在 Secondary 直到結束 |

#### 待確認事項

WebCall SBC 的 failover 機制為 VIP-based 或 DNS-based，須於需求訪談階段與既有廠商確認，AI-IVR 端的 SIP Trunk 配置將依確認結果調整。無論何種機制，AI-IVR 雙 SBC 註冊架構均可支援。

---

### 5.4　CRM Gateway 整合（REST / WebSocket）

**整合對象：** CRM Gateway（既有數位文字客服閘道器）
**整合方式：** REST API + WebSocket
**相關程式：** P-AGT-01（FR-AGT-001）、P-AGT-03（FR-AGT-003）、P-AGT-05（FR-AGT-006）
**相關決策：** AD-005

#### 整合機制

AI-Agent 透過 WebSocket 與 CRM Gateway 建立即時雙向通訊通道，接收旅客文字訊息並回傳 AI 回應。同時以 REST API 處理非即時操作（Session 歷史查詢、對話紀錄匯出等）。對外 REST API 依國發會「共通性應用程式介面規範」設計，採用 JSON 格式、統一錯誤碼、版本化 URI（`/api/v1/`）。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **即時通訊** | WebSocket（wss://），支援 ≥30 埠併發連線，心跳間隔 30 秒 |
| **訊息格式** | JSON（`session_id`、`channel`（Web/App）、`message`、`timestamp`） |
| **AI 回應** | JSON（`response_text`、`citations[]`（來源文件名稱、頁碼）、`confidence_score`） |
| **轉接通知** | AI-Agent 判定需轉真人時，透過 WebSocket 發送轉接事件，CRM Gateway 將對話路由至值機平台（P-WS-01），附帶對話摘要 |
| **REST API** | `GET /api/v1/sessions/{id}/history` — 對話歷史<br>`POST /api/v1/sessions/{id}/export` — 對話紀錄匯出（Word/PDF/Excel/HTML/CSV） |
| **認證方式** | API Key + HMAC 簽章，每個介接系統配發獨立 Key |

#### SMS 簡訊整合

SMS 簡訊收發系統（雙備援，4G LTE+）透過本機 REST API 與 AI-Agent 整合（P-SMS-01，FR-AGT-007）。旅客簡訊經 SMS 裝置接收後轉為 REST 請求送入 AI-Agent 處理，AI 自動回覆結果同步透過 WebSocket 推播至值機平台通知客服人員。簡訊紀錄寫入 PostgreSQL，保留 ≥5 年。雙備援 SMS 裝置採 Active-Standby 架構，Primary 裝置故障時系統自動切換至 Standby 裝置。

---

### 5.5　AD / LDAP 整合

**整合對象：** Active Directory（台鐵既有帳號管理系統）
**整合方式：** LDAP 協定
**相關程式：** P-ADM-02（FR-ADM-002）
**相關決策：** AD-001

#### 整合機制

系統帳號驗證與角色權限管理整合台鐵既有 AD，不另建帳號系統，確保人員異動時權限即時同步。登入流程以 LDAP 協定向 AD 驗證帳號密碼，驗證通過後依 AD 群組對應系統角色（RBAC），角色包含：值機員、督導、系統管理者、外點後送人員。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **通訊協定** | LDAPS（LDAP over TLS，636 port） |
| **驗證流程** | ① 使用者輸入帳號密碼 → ② 系統以 LDAP Bind 向 AD 驗證 → ③ 驗證通過後查詢 AD 群組 → ④ 依 RBAC 對照表授予系統角色與功能權限 |
| **同步機制** | 每次登入時即時查詢 AD，不快取帳號資料；角色對照表維護於管理後台（P-ADM-01） |
| **日誌記錄** | 所有登入/登出/授權變更事件寫入稽核日誌，保留 ≥6 個月 |

#### 企業資訊入口平台 SSO

系統預留 SSO 整合介面，支援台鐵企業資訊入口平台之單一登入機制。SSO 介接規格須於需求訪談階段取得，系統架構已預留 OAuth 2.0 / SAML 2.0 標準協定介面。

---

### 5.6　訂票紀錄 / 時刻表查詢系統整合

**整合對象：** 訂票紀錄查詢系統、時刻表查詢系統
**整合方式：** REST API（規格待取得）
**相關程式：** P-LLM-02（FR-LLM-002）、P-AGT-03（FR-AGT-003）

#### 整合機制

LLM 在處理旅客查詢時，涉及票務資訊（訂票狀態、票價）與班次資訊（時刻、車次、停靠站）等動態資料，必須從台鐵既有系統即時查詢，不依賴 LLM 模型記憶或知識庫靜態資料，確保回覆正確性。

#### 介面呼叫說明

| 介面項目 | 規格 |
|---------|------|
| **通訊協定** | REST API（HTTPS），依國發會共通性應用程式介面規範 |
| **呼叫時機** | LLM RAG Pipeline 中的「工具呼叫」（Tool Use）階段：LLM 識別旅客意圖涉及即時資料時，觸發 API 查詢，將查詢結果注入 Prompt 作為 grounding context |
| **查詢類型** | 時刻表查詢（車次、起訖站、發車時間）、票價查詢（車種、區間、票種）、訂票紀錄查詢（身分證/手機號碼，需旅客授權） |
| **回應格式** | JSON，系統解析後納入 LLM Prompt，生成自然語言回覆並標註資料來源（RAG Citation） |
| **逾時處理** | API 呼叫逾時上限 2,000ms；逾時或失敗時 LLM 回覆「目前無法查詢即時資料，建議撥打專線或至台鐵官網查詢」，不以推測資料回覆 |
| **個資保護** | 訂票紀錄查詢需旅客口頭或文字授權確認後方可發起 API 呼叫；查詢結果不寫入對話紀錄之個資欄位，僅保留查詢時間與查詢類型 |

#### 待確認事項

訂票紀錄與時刻表查詢系統之 API 規格尚待台鐵提供。系統架構已預留 API Adapter 抽象層，得標後取得規格即可實作對接，不影響其他模組開發時程。

---

### 5.7　整合介面彙總

| # | 外部系統 | 介面協定 | 方向 | 相關程式 | 安全機制 |
|---|---------|---------|------|---------|---------|
| 1 | MES Server | SIP/RTP | 雙向 | P-IVR-01~06 | SRTP（選配） |
| 2 | E1 VoIP Gateway | SIP Trunk | 入站 | P-IVR-01 | SIP 認證 |
| 3 | WebCall SBC ×2 | SIP Trunk/TLS | 入站 | P-IVR-01 | TLS + SIP 認證 |
| 4 | CRM Gateway | REST + WebSocket | 雙向 | P-AGT-01/03/05 | API Key + HMAC |
| 5 | SMS 收發裝置 ×2 | REST | 雙向 | P-SMS-01 | 本機 localhost |
| 6 | AD | LDAPS | 出站 | P-ADM-02 | TLS + LDAP Bind |
| 7 | 企業資訊入口平台 | OAuth 2.0 / SAML 2.0 | 雙向 | P-ADM-02 | SSO Token |
| 8 | 訂票紀錄查詢系統 | REST/HTTPS | 出站 | P-LLM-02, P-AGT-03 | API Key + TLS |
| 9 | 時刻表查詢系統 | REST/HTTPS | 出站 | P-LLM-02, P-AGT-03 | API Key + TLS |

所有介面通訊均於台鐵機房內部網路完成，無任何資料離開機房，符合資料在地化與禁止跨境傳輸之合規要求。各介面均記錄完整的呼叫日誌（請求時間、回應狀態碼、處理時間），保留 ≥6 個月，供資安稽核使用。

---

### 本章引用編號清單

**功能需求（FR）：** FR-IVR-001、FR-IVR-002、FR-AGT-001、FR-AGT-003、FR-AGT-006、FR-AGT-007、FR-LLM-002、FR-ADM-002

**測試案例（TC）：** TC-IVR-001、TC-AGT-001、TC-AGT-003、TC-AGT-006、TC-AGT-007、TC-LLM-002、TC-ADM-002

**架構決策（AD）：** AD-001（六層式架構）、AD-005（HA Active-Active）、AD-007（SIP/RTP fork 介接）

**攻擊面防禦（ATK）：** ATK-005（E1/SIP 介接零衝擊 — §5.1 RTP fork 被動接收、§5.2 E1 通道容量分析）、ATK-006（行政交換機類比線路品質 — §5.2 G.711 編碼與 VAD 調校）、ATK-007（WebCall SBC failover — §5.3 雙 SBC 註冊與切換機制）、ATK-012（不影響既有系統 — §5.1 零衝擊原則）、ATK-015（開源技術選型 — 全章所有介接均採用開源 SIP/HTTP 標準協定）
