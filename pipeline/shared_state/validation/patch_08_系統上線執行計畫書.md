以下為針對三個文件的修正指令：

---

## 檔案一：`08_系統上線執行計畫書_ch1-2.md`

### 修正 1：大陸品牌 bge-large-zh-v1.5 → multilingual-e5-large（§8.2.2 AI-Agent 段落）
位置：約第 101 行 / §8.2.2 二、AI-Agent 虛擬客服系統
原文：<<<
RAG 檢索增強生成（Qdrant 向量資料庫 + bge-large-zh-v1.5 embedding）
>>>
改為：<<<
RAG 檢索增強生成（Qdrant 向量資料庫 + multilingual-e5-large embedding）
>>>

### 修正 2：大陸品牌 bge-large-zh-v1.5 → multilingual-e5-large（§8.2.3 W-09）
位置：約第 140 行 / §8.2.3 二、資料與知識庫就緒
原文：<<<
| W-09 | 向量資料庫 embedding 建置完成（bge-large-zh-v1.5） | AI/ML 工程師 | Top-K 查詢延遲 <50ms | #02 §2.18 |
>>>
改為：<<<
| W-09 | 向量資料庫 embedding 建置完成（multilingual-e5-large） | AI/ML 工程師 | Top-K 查詢延遲 <50ms | #02 §2.18 |
>>>

### 修正 3：LLM 模型名稱不一致（缺少 -Instruct）
位置：約第 97 行 / §8.2.2 一、AI-IVR 智慧語音應答系統
原文：<<<
vLLM + Llama 3.1 8B AWQ，GPU #0 專責推論
>>>
改為：<<<
vLLM + Llama 3.1 8B-Instruct AWQ，GPU #0 專責推論
>>>

---

## 檔案二：`08_系統上線執行計畫書_ch3-4.md`

無需修正。（embedding 模型已為 `multilingual-e5-large`，LLM 名稱已為 `Llama 3.1 8B-Instruct AWQ`）

---

## 檔案三：`08_系統上線執行計畫書.md`（主檔）

### 修正 4：全文為 pipeline 摘要，非正式文件正文
位置：第 9～48 行（整個正文區域）
說明：此檔目前內容為 pipeline 產出摘要（「已完成…」「自然防禦了…」），不符合正式交付文件格式。應替換為 ch1-2 與 ch3-4 的合併正文，或至少改為正確的章節導引頁。此項屬結構性問題，建議以組裝腳本重新合併 ch1-2 + ch3-4 內容產生完整正文。

---

**總計：3 處文字替換修正 + 1 處結構性問題待處理。**

需要我直接執行修正 1～3 嗎？
