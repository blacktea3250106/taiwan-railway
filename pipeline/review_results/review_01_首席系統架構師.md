# 首席系統架構師審查報告

**審查角色：** 20 年經驗首席系統架構師，專精 VoIP/SIP 與 AI 推論系統設計  
**審查日期：** 2026-04-07  
**審查文件數：** 16（#01~#13 交付文件 + decisions.yaml + 2 份既有審查報告）  
**審查焦點：** 架構完整性、技術一致性、HA 設計、效能可達性、跨文件一致性、介面設計

---

## 審查摘要

| 項目 | 評估結果 |
|------|---------|
| **六層式架構完整度** | ⭐⭐⭐⭐（概念清晰，細節缺失） |
| **技術選型合理性** | ⭐⭐⭐⭐（開源堆疊穩健，但實作細節空白） |
| **HA 雙機設計** | ⭐⭐⭐（架構宣稱 Active-Active，實作細節有矛盾） |
| **效能指標可達性** | ⭐⭐⭐（設計合理但單卡測試無法驗證） |
| **跨文件一致性** | ⭐⭐（多個致命級矛盾） |
| **介面設計完整度** | ⭐⭐⭐（REST API 完整，gRPC 缺失） |
| **當前送審就緒度** | 🔴 **不宜送審**（致命級問題 6 個） |

---

## 致命級問題（6 個）

### A-01：vLLM 運作模型根本矛盾

**文件位置：** decisions.yaml §B1 `rationale` + #03 §3.1.1

**問題描述：**

decisions.yaml 仍記載：
> 「以單一 vLLM 引擎透過 continuous batching + PagedAttention 管理 KV Cache，30 路並行峰值 ~42GB，單卡 48GB 足以承載」

但 decisions.yaml 同一文件在另處寫：
> 「或者單卡上跑 6 個實例，每實例 8GB 模型權重 + KV Cache」

兩者物理上衝突：
- 單一引擎 continuous batching：✓ 可行（實際測試 42GB，#09 驗證）
- 6 個實例獨立推論：✗ 不可行（6×8GB 模型 = 48GB 無餘裕給 KV Cache）

**技術影響：** 
- 若採 6 實例模式，KV Cache 為零，不符合設計目標
- 若採單一引擎，VIP 故障時 failover 邏輯與多實例假設衝突

**修正建議：**

刪除 decisions.yaml 中所有「6 個實例」相關描述，統一為：
> 「模型權重 ~8GB，單一 vLLM 引擎以 continuous batching + PagedAttention 服務 ≤30 路並行，KV Cache 動態分配，峰值 ~42GB，單卡 L40S 48GB 足以承載。故障轉移時新實例重新啟動 vLLM 服務，Session state 由 Redis Sentinel 維持。」

---

### A-02：HA 架構 Active-Active 與 VIP 單點模式邏輯矛盾

**文件位置：** #01 §2.1 + #02 §1.3 + #13 §3.3 + AD-005 全文

**問題描述：**

全案宣稱「Active-Active + Failover 架構（AD-005），正常運行時雙機以 50/50 負載分攤流量」，但實現機制為：
- Keepalived VRRP 單 VIP（虛擬 IP）
- VRRP 心跳檢測故障時，VIP 漂移至存活機

**邏輯衝突：**

| 架構模式 | VIP 配置 | 負載分攤方式 | 故障時行為 |
|---------|---------|------------|---------|
| **真正 Active-Active** | 雙 VIP（VIP-A 在 Srv-A，VIP-B 在 Srv-B） | L4 LB 交叉配置 | 單機故障時客戶端自動重試另一 VIP |
| **實際部署（Keepalived）** | 單 VIP | Keepalived 決定 VIP 歸屬 | VIP 漂移，兩台機器在同一時刻僅一台持有 VIP |

**架構影響：**
- 實際上是 **Active-Standby + 自動 Failover**
- 「50/50 負載分攤」宣稱錯誤（正常時 VIP 選舉結果為一台 Master 一台 Backup）
- 正式環境容量規劃應以「單機 100% 承載」為基準，而非「雙機各 50%」

**修正建議（二選一）：**

**方案 A：採雙 VIP 交叉持有（真正 Active-Active）**
- Keepalived 配置雙 VRRP instance：VIP-SIP（SIP 信令）+ VIP-API（REST API）
- VIP-SIP 優先權配置 A > B，VIP-API 優先權配置 B > A
- #03 補充 VRRP instance 配置代碼、故障轉移邏輯
- #06 網路拓撲補充雙 VIP 配置圖
- 工時：2 小時

**方案 B：修正為 Active-Standby + 自動 Failover（實話實說）**
- 全案統一用詞為「Active-Standby + Keepalived 自動 Failover」
- 容量規劃改為：正常時 Srv-A 為 Master（100% 流量），Srv-B 為 Backup（Hot Standby）
- 故障時 VIP 漂移至 Srv-B，完成時間 ≤5 秒
- 更新 #01/#02/#06/#13 相關章節
- 工時：3 小時

---

### A-03：信心度（Confidence Score）三層防線無計算公式

**文件位置：** #02 §2.2 FR-LLM-002 + #03 §2.2 + #10 P-LLM-02

**問題描述：**

系統設計宣稱對 AI 回答採三層信心度防線：
- 信心度 ≥0.85：直接回答
- 信心度 0.6~0.85：回答 + 「建議洽人工確認」提示
- 信心度 <0.6：直接轉接人工客服

**但全案零份文件定義如何計算信心度。** 

現實問題：
- LLM 的 token log-probability 是否即為信心度？（不是，未經校準）
- RAG 檢索相關度分數（0~1）應加權多少？
- 用戶滿意度反饋如何動態調整閾值？

**架構影響：**
- 開發人員無法實作此機制
- #09 測試報告書中 200 題正確率 87.5% 是否已納入信心度過濾？未說明
- 此三層防線在審查委員眼中變成「紙上談兵」

**修正建議：**

在 #03 §2.2（P-LLM-02）新增「信心度計算演算法」小節，明確定義：

```
confidence_score = 
  α × rag_retrieval_score  (Reranker 排分 0~1)
  + β × nli_entailment_score (Entailment model 評估 prompt-response 對應度)
  + γ × -log_perplexity(response | model)  (LLM 生成困惑度)
  / (α + β + γ)

其中 α=0.3, β=0.4, γ=0.3（可通過台鐵 200 題驗收集 ECE 校準調整）
```

同步修正：
- #05 測試計畫：新增「信心度校準」測試案例（Expected Calibration Error ≤ 0.1）
- #09 測試報告：補充信心度分布統計
- #10 P-LLM-02：補充實作代碼與參數設定

工時：3 小時

---

### A-04：RAG 文件切割策略完全缺失

**文件位置：** #03 §2.2.2 P-AGT-02（向量檢索引擎）無 RAG Chunking 說明 + #02 §2.2 RAG 管線無細節

**問題描述：**

RAG 管線定義了：
- Embedding 模型（multilingual-e5-large）✓
- 向量庫（Qdrant）✓  
- Top-K 查詢（Top-5） ✓

**但缺少決定 RAG 品質的關鍵策略：**
- **Chunk size**：多少 token 或字符為一個檢索單位？太小會碎片化，太大會稀釋相關性
- **Chunk overlap**：相鄰 chunk 應重疊多少，以保留上下文邊界？
- **分割策略**：遞迴分割（RecursiveCharacterTextSplitter）還是簡單按句號分割？
- **長表格處理**：知識庫含大量表格，如何避免被切割成無意義的行？
- **Metadata 保留**：chunk 中應保留哪些元資訊（doc_title, page_no, section_id）供引用標註？

**#09 測試報告書 §1.5.2 TC-AGT-002 稱「Top-5 查詢延遲 <50ms，命中率 90%」**，但無法重現此結果（缺少設定說明）。

**修正建議：**

在 #03 §2.2.2（P-AGT-02）或新增獨立小節「RAG 文件索引策略」：

```yaml
chunking_strategy:
  chunk_size: 512  # tokens，相當於 ~2,000 字符
  overlap: 64     # tokens，保留前後句子邊界
  splitter: RecursiveCharacterTextSplitter
  
metadata_schema:
  doc_id: string      # 原始文檔 ID
  doc_title: string   # 文檔名稱
  page_no: int        # 頁碼（如適用）
  section_id: string  # 章節 ID（供 Citation 標註）
  chunk_index: int    # 該文檔內 chunk 序號
  
special_handling:
  - type: table
    strategy: keep_intact  # 表格保持整體不分割
    max_size: 8192 tokens
    
  - type: code_block
    strategy: keep_intact
    
embedding_params:
  model: multilingual-e5-large
  instruction: "Represent the document for retrieval"
  batch_size: 32
  
retrieval_params:
  top_k: 5
  similarity_threshold: 0.6
  reranker: bge-reranker-v2-m3  # Rerank 前 5 結果
  
index_rebuild_frequency: incremental  # 知識庫異動時增量重建
```

同步修正：
- #10 P-AGT-02：補充 Chunking 實作代碼（python-langchain）
- #09 §1.5.2：補充 chunking 參數與測試結果的對應關係

工時：2 小時

---

### A-05：gRPC 服務定義完全缺失

**文件位置：** #03 全文缺 gRPC 定義 + #06 API 清單僅列 REST

**問題描述：**

#03 §1.2 明確說：
> 「內部服務間通訊採 gRPC 協定（二進制序列化 + HTTP/2 多工），相較 REST 快 2~5 倍」

但全案零份文件提供 gRPC 服務定義（.proto 文件）。實務後果：
- 開發團隊無法據此開發 gRPC 服務端/客戶端
- Code generation 步驟無法進行
- 接口版本管理無從談起

**修正建議：**

在 #11 原始程式碼光碟新增 `api/grpc/services.proto`，定義以下服務：

```protobuf
syntax = "proto3";

package tietie.llm;

// LLM 推論服務
service LLMInference {
  rpc Chat(ChatRequest) returns (stream ChatResponse);
  rpc TextAnalyze(TextRequest) returns (AnalysisResponse);
}

// STT 串流服務
service STTStream {
  rpc Transcribe(stream AudioChunk) returns (stream TranscriptChunk);
}

// TTS 串流服務
service TTSStream {
  rpc Synthesize(TextWithVoiceStyle) returns (stream AudioChunk);
}

// RAG 檢索服務
service RAGRetrieval {
  rpc Search(SearchQuery) returns (SearchResult);
}

// Embedding 服務
service EmbeddingService {
  rpc Embed(EmbedRequest) returns (EmbedResponse);
}
```

同步修正：
- #03 新增「gRPC 服務界面定義」章節，列出所有服務端點與數據結構
- #10 各程式設計書中補充 gRPC Stub 初始化代碼
- #07 維護手冊補充 gRPC 日誌調試方法（grpcurl 工具）

工時：2 小時

---

### A-06：WebSocket 升級路徑缺失（文字通道實時推送）

**文件位置：** #02 §1.4 第五層通道接入層未提及 WebSocket

**問題描述：**

#03 明確提到 AI-Agent 使用 WebSocket：
> 「值機平台透過 WebSocket 推播至值機平台」

但 #02 系統分析中，第五層通道接入層描述為：
> 「文字通道透過 CRM Gateway 以 REST/WebSocket API 接入」

**矛盾點：**
- REST 是請求-應答模式（短連接），不適合推播
- WebSocket 應為主要協定，但在 #02 中僅作為備選提及
- CRM Gateway 與值機平台之間的 WebSocket 協議規格完全缺失

**架構影響：**
- 值機平台若採長輪詢（polling）替代 WebSocket，延遲會達 5~10 秒，不符合 FR-WS-002「即時推送」要求
- WebSocket 連接池管理（保活、斷線重連）無設計

**修正建議：**

#02 §1.4 重寫第五層通道接入層描述：

> 「文字通道透過 CRM Gateway 與值機平台間採 WebSocket 長連接（RFC 6455）建立實時通道，AI-Agent 回覆立即推播至客服座席。WebSocket 採心跳機制保活（ping/pong 30 秒），斷線時值機平台自動重連（指數退避，最大 60 秒）。HTTP 升級握手鑒權採 Bearer Token（來自 AD/LDAP）。」

同步補充：
- #03 新增 WebSocket 子協議定義（消息格式、事件類型）
- #06 網路拓撲標註 WebSocket 連接（通常走 VLAN-DMZ）
- #10 M-WS-02 補充 WebSocket 事件推播實作（Server-Sent Events or ws.send()）

工時：1.5 小時

---

## 重要級問題（8 個）

### B-01：Keepalived + PostgreSQL 流複寫架構中，Session 故障轉移策略有漏洞

**文件位置：** #03 §3.4 HA 架構描述 + #10 P-LLM-04 對話紀錄管理

**問題描述：**

全案採用 PostgreSQL Streaming Replication 主備同步 + Redis Sentinel 共享 Session。但對話紀錄流程存在競態條件：

| 時刻 | 主機 Srv-A | 備機 Srv-B | Redis Sentinel |
|------|-----------|-----------|--------------|
| T0 | 接收 AI 回覆，寫入 PG | (sync replicate) | Session 存入 Redis |
| T1 | **故障！** | — | — |
| T1+500ms | — | 提升為 Master | 識別 Srv-A 故障 |
| T1+2s | — | 已開始接收新連接 | Keepalived VIP 已漂移 |
| **問題** | 最後 500ms 的 PG transaction 未必 commit | Srv-B 接手時可能缺失最新對話紀錄 | Session 完整但對話紀錄不完整 |

**修正建議：**

在 #03 §3.4 補充故障轉移的資料一致性策略：
- PostgreSQL 採同步複寫（synchronous_replication = on），所有 WRITE 需主備雙確認
- 故障轉移後 Srv-B promote 前，檢查待 commit transaction，必要時 force apply
- Redis Sentinel failover 後，客戶端重新查詢 Session，若缺失則重新建立上下文

工時：1 小時

---

### B-02：SDES 金鑰交換缺乏安全前提聲明

**文件位置：** #03 §3.4 RTP 加密 / #05 TC-SEC-001 未涵蓋

**問題描述：**

設計文件使用 SDES（Session Description Protocol 中攜帶加密金鑰），但未聲明安全前提：

- SDES 將加密金鑰以明文嵌入 SDP 中
- 若 SIP 信令走 **UDP 5060**（未加密），金鑰等同裸傳，MITM 即可竊聽語音
- 修復方案：必須強制 SIPS (TLS 5061) 或改採 DTLS-SRTP

**修正建議：**

#03 §3.4 加註強制性聲明：
> 「SDES 金鑰交換安全性依賴 SIP 信令層加密。禁止使用 UDP 5060；所有 SIP 信令必須走 SIPS (TLS 1.3, port 5061)。替代方案：採用 DTLS-SRTP，金鑰交換不依賴 SDP。」

同步修正：
- #06 防火牆規則：開放 5061 (SIPS)，禁止 5060 (SIP)
- #07 維護手冊：Asterisk/PJSIP 配置檢查項「確認 SIP 強制 TLS」

工時：1 小時

---

### B-03：STT 測試音檔編碼格式未標註，與正式環境差異可能達 3~5% 辨識率

**文件位置：** #05 §1.4.3 / #09 §1.3.2 tc-stt-001

**問題描述：**

#09 §1.3.2 稱「200 音檔中文 160 個、英文 40 個，每檔 ≤150 秒」，但未標註：
- 採樣率（8kHz / 16kHz / 44.1kHz）
- 編碼方式（PCM 16-bit / G.711 μ-law / GSM-6.10）
- **路線場景**（VoIP 頻帶 = 0.3~3.4 kHz 會損失 4~8kHz 高頻成音）

實務影響：
- 行政電話轉入 VoIP Gateway → G.711 編碼 → AI-IVR：帶寬僅 64kbps，語音質量受損
- 若測試集用高保真音檔（16kHz PCM），實測結果可能無法重現

**修正建議：**

#05 §1.4.3 補充測試音檔規格表：

| 屬性 | 標準值 | 說明 |
|------|--------|------|
| 採樣率 | 8kHz | 模擬 VoIP 帶寬約束 |
| 編碼 | G.711 μ-law | 模擬 PSTN → VoIP Gateway 路線 |
| 碼率 | 64 kbps | 標準 VoIP 速率 |
| 頻寬 | 0.3~3.4 kHz | VoIP 帶通濾波後 |

#09 補充複驗結果：
- 使用高保真音檔 (16kHz PCM) 辨識率：**X%**
- 使用 G.711 編碼音檔辨識率：**Y%**
- 差異分析：**Z%**

工時：1 小時

---

### B-04：GPU#0 VRAM 使用率 87.7% 安全餘裕不足

**文件位置：** #09 §1.4.2 實測峰值 42.1/48GB + 推論預算分析

**問題描述：**

測試環境單卡實測：
- 模型權重 ~8GB（不變）
- 30 路 continuous batching，KV Cache 峰值 **42.1 GB**
- 使用率 **87.7%**，剩餘 5.9 GB

**風險：**
- 若出現突發 spike（如同時 31 路推論），GPU OOM 將導致服務崩潰（無 graceful degradation）
- 正式環境 dual GPU 時，單卡故障轉移會令生存卡瞬間面臨 >48GB KV Cache 需求

**修正建議：**

1. **vLLM 配置調整：** 設定 `gpu_memory_utilization=0.90`（允許使用 43.2GB），啟用 GPU memory swap（降級至 PCIe 內存）作為 overflow 機制

2. **負載限流：** 若 GPU VRAM 使用率 >85%，新請求排入優先隊列，以漸進式降級替代急死

3. **實測驗證：** #09 補充「Realistic Prompt」壓測（非 128 token 合成，而是實際 RAG prompt ~2,250 tokens），驗證峰值 VRAM

#03 補充 vLLM 啟動參數：
```yaml
vllm_config:
  gpu_memory_utilization: 0.90
  swap_space: 4  # GB，PCIe 內存 fallback
  max_num_seqs: 30  # continuous batching 上限
  enable_prefix_caching: true  # KV Cache 重複利用
```

工時：1.5 小時

---

### B-05：Reranker 模型未指定

**文件位置：** #03 §2.2 P-AGT-02 （向量檢索引擎）缺 Reranker 名稱

**問題描述：**

RAG Pipeline 流程圖提及 Rerank，但無具體模型：
- 檢索 → Rerank → Prompt 組裝

**Reranker 對 RAG 品質影響達 5~10%**（從 Top-5 命中率 90% 可升至 96%，或降至 82%）。

**修正建議：**

指定 Reranker 模型與評分函數，補充至 #03 P-AGT-02：

```yaml
retrieval_pipeline:
  stage_1_embedding_search:
    model: multilingual-e5-large
    top_k: 10  # 粗篩
  
  stage_2_reranking:
    model: bge-reranker-v2-m3  # 推薦（中英混合，支持繁中）
    # 替代方案：ms-marco-MiniLM-L12-v2（輕量級，延遲 <50ms）
    score_threshold: 0.6  # 低於此閾值的結果過濾
    top_k: 5  # 重排後精選前 5
  
  stage_3_retrieval_aug:
    context_format: "Retrieved {i}: {content}\nSource: {section_id}"
```

#10 補充 Reranker 部署配置與推論延遲測試結果

工時：0.5 小時

---

### B-06：教育訓練缺 Docker/GPU 基礎概念培訓

**文件位置：** #04 教育訓練計畫書全文 / #12 教育訓練執行報告

**問題描述：**

管理者正式訓練內容涵蓋 Docker Compose 操作、Prometheus 監控、備份回復等，但**未補充 Docker/vLLM 基礎概念**。

實務風險：
- 管理者無法判斷「為什麼 vLLM 容器重啟時需要 5 分鐘」（模型權重重載時間）
- 無法理解「GPU VRAM 使用率 92% 是否正常」（缺 vLLM KV Cache 知識）
- 無法應對 GPU 故障切換時 Session 不遺失的驗證

**修正建議：**

#04 新增「模組零：容器 & GPU 基礎概念」（2 小時）：
- Docker 容器生命週期、volume 掛載、環境變數注入
- GPU 容器概念：nvidia-docker、CUDA 版本對應、VRAM 隔離
- vLLM 特異性：continuous batching 如何分配 VRAM、模型權重預熱時間

#12 補充執行紀錄：確認管理者已理解「vLLM 重啟為什麼耗時 5 分鐘」等基本問題

工時：2 小時（課程開發）+ 2 小時（執行）

---

### B-07：WebCall SBC Failover 實現細節缺失

**文件位置：** #01 AD-005 / #08 上線計畫 §8.2.3 W-05

**問題描述：**

#08 上線計畫 W-05 稱「WebCall SBC 雙備援 Failover 測試，模擬主 SBC 離線，驗證 AI-IVR 自動切換」，但零份文件描述實現細節：

- AI-IVR 如何偵測主 SBC 故障？（SIP 註冊失敗重試機制）
- 故障轉移時在途的 SIP INVITE 如何處理？（是否需要 SIP 3xx 重定向）
- 故障轉移後如何驗證？（SIP 200 OK 確認重新註冊）

**修正建議：**

#03 或 #10 P-IVR-01 新增「WebCall SBC Failover 機制」詳述：

```
Primary SBC: 203.0.113.10:5060
Secondary SBC: 203.0.113.11:5060

SIP UA Registration:
  - 同時向 Primary 和 Secondary 註冊
  - 優先權設置：Primary (priority=100) > Secondary (priority=50)
  - 健康檢查：每 30 秒發送 SIP OPTIONS 探測
  - 故障判定：連續 3 次 OPTIONS 無回應，標記為故障
  - Failover 觸發：切換至備用 SBC，重新 REGISTER
  - Failover 完成時間：實測 3.2 秒（#09 已驗證）

進行中通話處理：
  - 若 SIP 故障發生於 INVITE 階段，返回 SIP 503 Service Unavailable
  - MES Server 應自動重試備用 SBC（由 MES 實現）
  - 若故障發生於 RTP 傳輸中，RTP 流中斷但 SIP 信令可通過新 SBC 恢復
```

工時：1 小時

---

### B-08：Qdrant 向量資料庫無 HA 機制，Snapshot 間隔無明確定義

**文件位置：** #03 §3.3 資料管理層 / #06 軟體清單無 Qdrant HA 描述

**問題描述：**

PostgreSQL 採 Streaming Replication（同步），Redis 採 Sentinel，但 **Qdrant 僅採定期 Snapshot**：

- 兩次 Snapshot 間的增量（新增/更新向量）在故障時會遺失
- RPO（恢復點目標）無定義（可能 1 小時也可能 24 小時）
- RTO（恢復時間目標）無定義

**#01/#05 系統穩定性 KPI 為「可用率 ≥99%/季」，但 Qdrant 故障轉移後 RTO 可能達 10 分鐘（重載 Snapshot），不符合 SLA。**

**修正建議：**

二選一：

**方案 A：Qdrant Replication（官方提供）**
- Qdrant v1.9+ 支持 replica set（主備複寫）
- RPO = 0（同步複寫）
- RTO ≤ 2 秒（自動故障轉移）
- #03 補充 Qdrant Cluster 配置

**方案 B：Snapshot 高頻備份**
- Snapshot frequency = 5 分鐘（手動或 cron job）
- RPO = 5 分鐘（可接受）
- RTO = 2 分鐘（從備份恢復）
- #07 維護手冊補充 Snapshot 恢復 SOP

#06 更新 Qdrant 描述，明確 HA 策略與 RPO/RTO

工時：1.5 小時

---

## 一般級問題（5 個，建議改善但非關鍵）

### C-01：#13 結案報告硬體規格與 #06 至少 10 處矛盾

**文件位置：** #06 §6.2.1 vs #13 §2.1/§2.3

示例矛盾：
- CPU 核心數標註不一致（AI Server 2×16C vs 2×8C）
- 儲存 RAID 型號（RAID-5 vs 缺失）
- 設備類別名稱（AI-IVR Server vs IVR Server）

**修正建議：** 全文檢索替換，以 #06 硬體清單為唯一真實來源

工時：1 小時

---

### C-02：多份文件缺少 Table of Contents (TOC)

**文件位置：** #02/#03/#05 等文件無自動 TOC

**修正建議：** 在 Markdown 首頁手動或自動生成 TOC

工時：0.5 小時

---

### C-03：PJSIP GPL-2.0 copyleft 合規分析不完整

**文件位置：** #11 §11.4.6（GPL 隔離分析）缺 PJSIP

**問題描述：**

pjsua2 Python binding 與 台鐵後續自主開發的 Python 代碼是否構成「衍生作品」，影響授權義務。

**修正建議：** #11 補充 GPL 隔離分析：
- 若 PJSIP 以進程邊界隔離（Python subprocess + IPC），則非衍生作品，GPL 不傳播
- 若直接 import pjsua2，則可能構成衍生作品，台鐵須開源 modify 部分

工時：1 小時

---

### C-04：訓練時數自證違約（#13 vs #04/#12 數字不一致）

**文件位置：** #13 §2.4 + #04 §4.2.2 + #12 §12.1

- #04 計畫：36 小時正式 + 12 小時 Pilot = 48 小時值機培訓
- #12 執行報告：36 小時正式訓練（正確）
- #13 結案報告：24 小時正式訓練（錯誤）

**修正建議：** #13 修正為 36 小時，補充註記「Pilot 12hr 為種子人員額外先修，不計入正式訓練時數」

工時：0.5 小時

---

### C-05：GPU 測試工作量與正式環境推論差距 17.6 倍

**文件位置：** #09 §1.4.2 / #05 TC-LLM-001

**問題描述：**

- 測試：128 input tokens + 64 output tokens
- 實務 RAG prompt：~1,200 input tokens（系統指令 + RAG 上下文 + 對話歷史） + 256 output tokens

**VRAM 峰值與延遲都會顯著上升。**

**修正建議：**

#09 補充「Realistic Workload」測試結果（≥1,200 input tokens），並標註「synthesis benchmark」與「realistic」的差異

工時：1 小時

---

## 整體架構評語

### 優點（⭐⭐⭐⭐）
1. **六層分層架構清晰**——從基礎設施到使用者層的抽象完整，各層職責明確
2. **技術選型穩健**——開源堆疊成熟且無授權風險，LLM/STT/TTS/向量庫均為業界一流
3. **HA 雙機設計方向正確**——Keepalived + PostgreSQL Streaming + Redis Sentinel 組合是中小規模 SIP 系統的標準配置
4. **涵蓋面寬**——從 PSTN 舊線路到 WebCall 新通道，從語音到文字，系統邊界定義周密
5. **效能預算分配合理**——5000ms 端對端 SLA 按 STT/LLM/TTS 分配，單項預算有節制

### 弱點（⭐⭐⭐）
1. **架構概念與實現細節脫節**——宣稱三層信心度防線但無計算公式、宣稱 RAG 檢索但無 chunking 策略
2. **HA 架構描述歧義**——Active-Active 概念與單 VIP Keepalived 實際實作存在邏輯矛盾
3. **跨文件一致性問題**——#13 結案報告在硬體/訓練時數/架構描述上與前 12 份文件多處衝突
4. **缺乏工程可實施性細節**——gRPC 無 .proto 定義、Reranker 無模型指定、金鑰交換無安全前提
5. **測試代表性不足**——單卡 GPU 測試無法驗證雙卡資源隔離，合成 128-token prompt 無法代表真實 RAG 工作量

### 建議方向
1. **優先修復致命級問題（6 個）**——信心度計算公式、RAG chunking、gRPC 定義、HA 矛盾、vLLM 模型一致性、WebSocket 升級
2. **強化工程細節**——為每個架構決策配上配置參數、驗證結果、故障轉移 SOP
3. **統一跨文件數字**——建立「單一真實來源」（decisions.yaml），所有衍生文件依此同步
4. **補充故障場景**——除了正常路徑，補充故障轉移、降級策略、限流機制等邊界條件設計

---

## 評分理由

| 維度 | 得分 | 說明 |
|------|:----:|------|
| 架構完整性 | 8/10 | 六層分層清晰，但 HA 架構描述有矛盾 |
| 技術一致性 | 7/10 | 整體選型合理，但跨文件數字衝突、vLLM 描述有歧義 |
| 工程實施性 | 6/10 | 缺乏操作細節（計算公式、配置參數、SOP） |
| 效能達成度 | 7/10 | 預算分配合理，但單卡測試無法代表實際環境 |
| 文件品質 | 5/10 | #01~#12 整體尚可，#13 結案報告與前文多處矛盾 |
| **加權總分** | **6.6/10** | 🔴 **不宜送審**（需修正致命級問題） |

修正致命級問題（約 16 小時）後，預估評分升至 **8.2/10**（🟡 基本可送審）  
修正重要級問題（約 12 小時）後，預估評分升至 **9.0/10**（🟢 信心送審）

---

## 審查總結

**本案架構設計展現了紮實的系統工程紀律——技術選型穩健、分層邏輯清晰、涵蓋面周密。然而，在『將架構願景轉化為工程實現細節』的環節出現了明顯的斷裂：文件描述了一個優雅的系統，但開發人員據此無法實作。特別是 #13 結案報告集中了全案絕大多數致命級矛盾，使得審查委員將在翻閱首份文件時即對整案可信度產生根本性懷疑。**

**建議採用"兩階段修復"策略：第一階段（3~4 個工作天）修復 6 個致命級問題，達到『基本可送審』水準；第二階段（2~3 個工作天）補強工程細節與跨文件一致性，達到『信心送審』水準。**
