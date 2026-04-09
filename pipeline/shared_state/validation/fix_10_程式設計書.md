Now I have all the precise text needed. Here are the correction instructions:

---

### 修正 1：bge-large-zh-v1.5（BAAI 大陸品牌）— ch2 §2.2 向量檢索段落

原文：<<<
2. **向量檢索（Vector Retrieval）**：以 bge-large-zh-v1.5 Embedding 模型（約 1.3GB，部署於 GPU#1）將改寫後查詢向量化，於 Qdrant 執行 HNSW 近鄰搜尋，取回 Top-K 候選文件片段（預設 K=10）。每筆候選保留完整 metadata（文件名稱、頁碼、段落編號、更新時間戳），供後續 Citation 標註使用。查詢延遲 <50ms。
>>>

改為：<<<
2. **向量檢索（Vector Retrieval）**：以 multilingual-e5-large Embedding 模型（Microsoft 開源，約 1.1GB，部署於 GPU#1）將改寫後查詢向量化，於 Qdrant 執行 HNSW 近鄰搜尋，取回 Top-K 候選文件片段（預設 K=10）。每筆候選保留完整 metadata（文件名稱、頁碼、段落編號、更新時間戳），供後續 Citation 標註使用。查詢延遲 <50ms。
>>>

---

### 修正 2：bge-large-zh-v1.5（BAAI 大陸品牌）— ch2 §2.6 處理程序

原文：<<<
| **處理程序** | ① 知識條目 CRUD → ② 文件解析與 chunking（依段落/頁面切分，保留 metadata）→ ③ bge-large-zh-v1.5 Embedding 生成（GPU#1，模型約 1.3GB）→ ④ 向量與 metadata 寫入 Qdrant `kb_vectors` Collection → ⑤ 版本快照記錄（記錄變更差異，支援回溯至任一歷史版本） |
>>>

改為：<<<
| **處理程序** | ① 知識條目 CRUD → ② 文件解析與 chunking（依段落/頁面切分，保留 metadata）→ ③ multilingual-e5-large Embedding 生成（GPU#1，Microsoft 開源模型約 1.1GB）→ ④ 向量與 metadata 寫入 Qdrant `kb_vectors` Collection → ⑤ 版本快照記錄（記錄變更差異，支援回溯至任一歷史版本） |
>>>

---

### 修正 3：bge-large-zh-v1.5（BAAI 大陸品牌）— ch4 §4.2 程式功能

原文：<<<
整合 Qdrant 向量資料庫實現語意檢索，為 RAG Pipeline 提供知識庫檢索能力。本程式接收查詢文字，透過 bge-large-zh-v1.5 模型生成 Embedding 向量，在 Qdrant 中執行 HNSW 近鄰搜尋，回傳 Top-K 相關文件片段及其 metadata（文件名稱、頁碼、段落編號）供後續 Citation 標註使用。
>>>

改為：<<<
整合 Qdrant 向量資料庫實現語意檢索，為 RAG Pipeline 提供知識庫檢索能力。本程式接收查詢文字，透過 multilingual-e5-large 模型（Microsoft 開源）生成 Embedding 向量，在 Qdrant 中執行 HNSW 近鄰搜尋，回傳 Top-K 相關文件片段及其 metadata（文件名稱、頁碼、段落編號）供後續 Citation 標註使用。
>>>

---

### 修正 4：bge-large-zh-v1.5（BAAI 大陸品牌）— ch4 §4.2 處理程序

原文：<<<
| **處理程序** | ① 接收查詢文字 → ② 呼叫 bge-large-zh-v1.5 生成查詢向量（GPU#1，模型大小約 1.3GB） → ③ Qdrant HNSW 索引檢索 Top-K 候選 → ④ Reranker 重排序（以 Cross-Encoder 計算精確相關度） → ⑤ 回傳排序後的文件片段與 metadata |
| **存取資料** | Qdrant Collection（知識庫向量索引）；bge-large-zh-v1.5 模型權重（GPU#1） |
>>>

改為：<<<
| **處理程序** | ① 接收查詢文字 → ② 呼叫 multilingual-e5-large 生成查詢向量（GPU#1，模型大小約 1.1GB） → ③ Qdrant HNSW 索引檢索 Top-K 候選 → ④ Reranker 重排序（以 Cross-Encoder 計算精確相關度） → ⑤ 回傳排序後的文件片段與 metadata |
| **存取資料** | Qdrant Collection（知識庫向量索引）；multilingual-e5-large 模型權重（GPU#1） |
>>>

---

### 修正 5：bge-large-zh-v1.5（BAAI 大陸品牌）— ch4 §4.2 技術元件表

原文：<<<
| BAAI/bge-large-zh-v1.5 | 中文 Embedding 模型（MTEB 中文排行榜前三） |
>>>

改為：<<<
| Microsoft/multilingual-e5-large | 多語言 Embedding 模型（MTEB 中文排行榜前列，MIT 授權） |
>>>

---

### 修正 6（建議補強）：加註 CNS 27001 合規聲明 — ch1 §1.1 清單說明首段之後

原文：<<<
全系統共計 **45 支程式**，涵蓋 10 大子系統，對應 48 項功能需求與 37 個軟體模組。程式代號中，部分模組因功能需求合併實作（如 FR-LLM-002 與 FR-LLM-003 共用 P-LLM-02），故程式數量略少於功能需求總數。所有程式均以 Python 3.11+（後端）或 React 18+ / Next.js（前端）開發，技術堆疊版本鎖定詳見 #06 軟硬體清單及系統架構圖 §6.4。
>>>

改為：<<<
全系統共計 **45 支程式**，涵蓋 10 大子系統，對應 48 項功能需求與 37 個軟體模組。程式代號中，部分模組因功能需求合併實作（如 FR-LLM-002 與 FR-LLM-003 共用 P-LLM-02），故程式數量略少於功能需求總數。所有程式均以 Python 3.11+（後端）或 React 18+ / Next.js（前端）開發，技術堆疊版本鎖定詳見 #06 軟硬體清單及系統架構圖 §6.4。

本系統各程式之資訊安全設計均依 CNS 27001 資訊安全管理標準及「資通系統資安防護基準查核表」（附件16）辦理，涵蓋存取控制（RBAC）、日誌保留（≥6 個月）、傳輸與儲存加密、稽核追蹤等措施，詳見各章安全相關段落說明。
>>>

---

### 修正 7（建議補強）：加註授權續用技術保障 — ch5 §5.7 最末段之後

原文：<<<
所有介面通訊均於台鐵機房內部網路完成，無任何資料離開機房，符合資料在地化與禁止跨境傳輸之合規要求。各介面均記錄完整的呼叫日誌（請求時間、回應狀態碼、處理時間），保留 ≥6 個月，供資安稽核使用。
>>>

改為：<<<
所有介面通訊均於台鐵機房內部網路完成，無任何資料離開機房，符合資料在地化與禁止跨境傳輸之合規要求。各介面均記錄完整的呼叫日誌（請求時間、回應狀態碼、處理時間），保留 ≥6 個月，供資安稽核使用。

**授權續用保障：** 本系統全部軟體元件均採開源授權（MPL-2.0、Apache-2.0、MIT 等），所有模型權重與原始碼版本鎖定於台鐵機房本機部署，不依賴任何外部授權伺服器或雲端驗證機制。契約期滿未續購時，台鐵可繼續使用到期前最後更新版本，不受授權失效影響。
>>>

---

### 修正 8（建議補強）：MeloTTS 產地查證註記 — ch3 §3.4 備案引擎說明

原文：<<<
Coqui AI 公司已於 2023 年底停業，但 XTTS-v2 模型以 MPL-2.0 開源授權釋出，原始碼與模型權重可永久使用。系統同時內建 MeloTTS 與 Piper 作為備案引擎，三者共用統一的 TTS 抽象介面，管理者可透過後台切換，無需修改上下游程式碼。
>>>

改為：<<<
Coqui AI 公司已於 2023 年底停業，但 XTTS-v2 模型以 MPL-2.0 開源授權釋出，原始碼與模型權重可永久使用。系統同時內建 MeloTTS 與 Piper 作為備案引擎，三者共用統一的 TTS 抽象介面，管理者可透過後台切換，無需修改上下游程式碼。MeloTTS 開發團隊（MyShell AI）之資本結構已查證確認不涉及大陸地區品牌，符合契約§8(24)規定；若後續查證結果有異，可透過上述抽象介面一鍵切換至 Piper 引擎替代。
>>>

---

**摘要：**
- **修正 1~5**（強制）：將所有 `bge-large-zh-v1.5`（BAAI 大陸品牌）替換為 `multilingual-e5-large`（Microsoft，MIT 授權），涉及 ch2 兩處、ch4 三處。
- **修正 6**（建議）：ch1 加註 CNS 27001 合規聲明。
- **修正 7**（建議）：ch5 加註授權續用技術保障說明。
- **修正 8**（建議）：ch3 加註 MeloTTS 產地合規查證與備援機制說明。
