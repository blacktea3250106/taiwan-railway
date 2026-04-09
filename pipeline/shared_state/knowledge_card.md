# 台鐵 AI 客服系統建置案 — 專案知識卡

案號 L0215P2010U ｜ 國營臺灣鐵路股份有限公司 ｜ 270 日曆天 ｜ 總包價法

> **一句話描述：** 為台鐵建置地端 AI 客服系統（AI-IVR 語音 + AI-Agent 文字 + 智慧質檢），介接既有 PSTN/WebCall/數位客服，全面開源技術堆疊，HA 雙機架構。

---

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

---

## 13 項交付時程表

| # | 交付項目 | 期限 | 付款期 |
|---|---------|------|-------|
| 1 | 工作計畫書 | D+30 | 第一期 10% |
| 2 | 系統分析報告書（含需求規格） | D+80 | 第二期 30% |
| 3 | 程式設計規格報告書 | D+80 | 第二期 |
| 4 | 教育訓練計畫書 | D+100 | 第二期 |
| 5 | 測試計畫書（含壓力測試及資安檢測） | D+100 | 第二期 |
| 6 | 軟硬體清單及系統架構圖 | D+180 | 第二期 |
| 7 | 軟體使用及維護手冊 | D+180 | 第二期 |
| 8 | 系統上線執行計畫書 | D+180 | 第二期 |
| 9 | 測試報告書（含壓力測試及資安檢測） | D+240 | 第三期 50% |
| 10 | 程式設計書 | D+240 | 第三期 |
| 11 | 原始程式碼光碟 | D+240 | 第三期 |
| 12 | 教育訓練執行報告書 | D+240 | 第三期 |
| 13 | 結案報告 | D+270 | 第四期 10% |

---

## KPI（SECTION D 原封搬入）

```yaml
ivr_accuracy: {value: "≥85%", formula: "(完全正確×1+部分正確×0.5)÷總次數×100%", test: "200題，台鐵提供", source: "需求書§三(一)"}
ivr_response: {value: "≤5000ms", note: "量測起訖點：旅客說完（VAD 偵測語音結束）至系統回覆首字播出", source: "需求書§三(一)"}
ivr_ports: {value: "≥30", note: "含E1+WebCall+行政分機", source: "需求書§三(一)"}
stt_accuracy: {value: "≥85%", formula: "100%-(錯誤或缺漏字數/總字數)×100%", test: "200音檔(中英4:1,≤150s)", source: "需求書§三(二)"}
agent_accuracy: {value: "≥85%", formula: "同IVR", test: "200題，台鐵提供", source: "需求書§三(五)"}
agent_response: {value: "≤5000ms", note: "量測起訖點：旅客送出訊息至系統回覆首段文字呈現", source: "需求書§三(五)"}
agent_ports: {value: "≥30", source: "需求書§三(五)"}
classify_accuracy: {value: "≥85%", formula: "(AI正確分類數/總案件數)×100%", test: "200筆真實後送案件", source: "需求書§三(四)"}
qi_speed: {value: "15min錄音→≤5min完成轉換分析並產出質檢報告", source: "需求書§三(六)"}
availability: {value: "≥99%/季", penalty: "每不足1%計3點", source: "服務水準表"}
daily_max_downtime: {value: "≤4hr/日", penalty: "逾4hr每小時計1點", source: "服務水準表"}
mttr: {value: "≤4hr含假日", penalty: "逾4hr每小時計1點", source: "契約§7(六)"}
incident_notify: {value: "≤1hr", penalty: "逾1hr每小時計1點", source: "服務水準表"}
incident_control: {value: "≤72hr(重大36hr)", source: "服務水準表"}
investigation_report: {value: "≤1個月", source: "服務水準表"}
log_retention: {value: "≥6個月", source: "資安查核表"}
sms_retention: {value: "≥5年", source: "需求書§三(五)"}
training_hours: {value: "≥54hr", breakdown: "值機≥36hr+管理≥18hr", source: "需求書七"}
custom_reports: {value: "≥10個", note: "保固期間免費", source: "需求書§三(七)"}
```

---

## 硬體規格速查（SECTION E 原封搬入）

**正式環境：**

| 設備 | 數量 | CPU | RAM | 儲存 | GPU | 電源 |
|-----|-----|-----|-----|-----|-----|-----|
| AI-IVR 伺服器 | 2 | 16C≥2.2GHz×2 | DDR5 64GB+ | 960GB SSD×3 (RAID-5) | — | 800W RPS×2 |
| AI 伺服器 | 2 | 16C≥3.0GHz×2 | DDR5 128GB+ | 960GB SSD×3 (RAID-5) | NVIDIA L40S 48GB×2 | 1000W RPS×2 |
| 管理/資安監控伺服器 | 2 | 16C≥3.0GHz×2 | DDR5 64GB+ | 960GB SSD×3 (RAID-5) | — | 800W RPS×2 |
| SMS 簡訊收發 | 2 | — | — | 256GB+ | — | — |
| 42U 機櫃 | 1 | — | — | — | — | — |

**測試環境：**

| 設備 | 數量 | CPU | RAM | 儲存 | GPU |
|-----|-----|-----|-----|-----|-----|
| AI-IVR 測試伺服器 | 1 | 8C≥2.2GHz×2 | DDR5 64GB+ | 600GB SAS×3 | — |
| AI 測試伺服器 | 1 | 8C≥2.2GHz×2 | DDR5 64GB+ | 600GB SAS×3 | L40S×1 |
| SMS 測試 | 1 | — | — | 256GB+ | — |
| 42U 機櫃 | 1 | 同正式環境 | — | — | — |

**硬體限制：** RPS 冗餘電源 ｜ 禁大陸品牌/製造 ｜ 決標前1年內新品 ｜ 合約期零件供應無虞 ｜ AI 伺服器保留擴充空間

---

## 技術選型摘要

| 元件 | 選型 | 關鍵理由 |
|-----|------|---------|
| LLM | Llama 3.1 8B-Instruct AWQ 量化 + vLLM | ~8GB VRAM，單卡跑6實例，開源免授權 |
| STT | Whisper large-v3 + faster-whisper | CPU 推論，繁中實測88~92%，開源 |
| TTS | Coqui XTTS-v2 | CPU 推論，中文自然度最佳，完全地端（⚠ Coqui AI 已停業，模型仍開源可用，備案：MeloTTS / Piper） |
| 向量DB | Qdrant + bge-large-zh-v1.5 embedding | Rust 高效能，Top-K <50ms |
| 關聯DB | PostgreSQL 16 + TimescaleDB | JSON 原生支援，開源無 Oracle 風險 |
| 快取 | Redis 7 | Session + 即時對話上下文 |
| SIP | PJSIP (pjsua2 Python binding) | 業界標準 SIP/RTP stack |
| 後端 | Python 3.11+ / FastAPI | REST(外部) + gRPC(內部) |
| 前端 | React 18+ / Next.js / Ant Design | 中文企業級 UI，RWD |
| 部署 | Docker Compose（不用 K8s） | 降低台鐵維運門檻 |
| 監控 | Prometheus + Grafana | 開源，告警驅動 24/7 值班 |
| HA | Active-Active + Failover | 50/50 負載，故障單機 100% |

---

## 架構決策記錄

| ID | 決策 | 理由 |
|----|------|------|
| AD-001 | 六層式架構（基礎設施/平台安全/資料管理/AI服務/通道接入/使用者） | 隔離 AI 與既有系統，零衝擊 |
| AD-002 | GPU#0 專責 LLM 推論，GPU#1 負責 Embedding+QI+擴充預留 | 避免搶資源，確保5秒SLA |
| AD-003 | STT/TTS 跑 CPU 不上 GPU | 串流低延遲適合 CPU，GPU 留給 LLM |
| AD-004 | LLM 選用 Llama 3.1 8B AWQ | 8GB VRAM，單卡6實例，開源 |
| AD-005 | HA Active-Active + Failover | 正常50/50，故障單機100% |
| AD-006 | Docker Compose 不用 K8s | 6~8台不需 K8s 複雜度 |
| AD-007 | SIP/RTP fork 介接既有語音系統 | 不修改 MES Server 設定 |
| AD-008 | 技術選型優先開源方案 | 授權到期可續用，降低 TCO |

---

## 容量模型

| 通道 | 月量 | 尖峰日量 | 尖峰併發 |
|-----|------|---------|---------|
| 語音（PSTN+WebCall） | 20,000~35,000 通 | 1,167 通 | 30 路 |
| 文字（數位客服） | 4,000~6,000 筆 | 200 筆 | 30 路 |
| SMS 簡訊 | 2,500~7,000 則 | 233 則 | — |
| 後送案件 | 600~700 件 | — | — |

**客服人力：** 值機座席 25 席 ｜ 督導 2 席 ｜ 同時在線 ~15 人 ｜ 外點後送人員 225 人（同時 ~23 人）

**現況基線：** 接聽率 83% ｜ 30秒接起率 64% ｜ 數位客服配對率 93% ｜ 轉接率 23% → 目標：AI 介入後 30s 接聽率 ≥85%

**E1 專線：** 現有 1 條（30 B-channel），系統支援最多 2 條

---

## 既有系統介接清單

| 既有系統 | 介接方式 | 說明 |
|---------|---------|------|
| PSTN E1 VoIP Gateway | SIP Trunk + RTP fork | 公眾電話語音來源，AI-IVR 被動接收 |
| WebCall SBC（雙備援） | SIP Trunk（failover） | 網頁電話語音來源 |
| MES Server（話務/錄音） | RTP fork + API | 通話分配與錄音，AI-IVR 不改其設定 |
| 行政交換機（02-2381-5226） | 類比 VoIP Gateway → MES → AI-IVR | 內部分機轉接路徑 |
| CRM Gateway | REST/WebSocket API | 數位文字客服訊息通道 |
| AD（Active Directory） | LDAP | 人員帳號驗證與權限 |
| 企業資訊入口平台 | SSO/API | 單一登入整合 |
| 訂票紀錄查詢系統 | API（規格待取得） | LLM 串接查詢票務資訊 |
| 時刻表查詢系統 | API（規格待取得） | LLM 串接查詢班次資訊 |
| 後送案件系統 | API | 225 位外點人員使用中 |

---

*本知識卡作為所有後續 Prompt 的 Context 前綴使用。數字來源：decisions.yaml SECTION D/E，不可四捨五入或改寫。*
