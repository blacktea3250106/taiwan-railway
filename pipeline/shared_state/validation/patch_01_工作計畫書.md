以下為針對本文件內容的修正指令：

---

### 修正 1：移除英文草稿殘留文字（第一處）
位置：文件開頭，日期之後
原文：<<<
---

Now I have all the source data. Let me compose the document.

---
>>>
改為：<<<
---
>>>

---

### 修正 2：移除英文草稿殘留文字（第二處）
位置：第三章與第四章之間
原文：<<<
---

Now I have all the source data. Let me compose chapters 4-6.

---
>>>
改為：<<<
---
>>>

---

### 修正 3：模型名稱一致性 — WBS 1.2.4.1
位置：§2.2 WBS 工作分解結構
原文：<<<
│   │   ├── 1.2.4.1 LLM 推論引擎部署與繁中微調（vLLM + Llama 3.1 8B AWQ）
>>>
改為：<<<
│   │   ├── 1.2.4.1 LLM 推論引擎部署與繁中微調（vLLM + Llama 3.1 8B-Instruct AWQ）
>>>

---

### 修正 4：模型名稱一致性 — §4.3 設計工作項目表
位置：§4.3 AI Pipeline 列
原文：<<<
| AI Pipeline | LLM 推論鏈（vLLM + Llama 3.1 8B AWQ）、RAG 檢索鏈（Qdrant + bge-large-zh-v1.5）、STT/TTS 串流管線 | AI/ML 工程師 |
>>>
改為：<<<
| AI Pipeline | LLM 推論鏈（vLLM + Llama 3.1 8B-Instruct AWQ）、RAG 檢索鏈（Qdrant + bge-large-zh-v1.5）、STT/TTS 串流管線 | AI/ML 工程師 |
>>>

---

### 修正 5：模型名稱一致性 — §5.4 部署容器表
位置：§5.4 AI 伺服器列
原文：<<<
| AI 伺服器 ×2 | vLLM（Llama 3.1 8B AWQ）、Qdrant 向量資料庫、RAG Pipeline、AI-QI 質檢引擎 |
>>>
改為：<<<
| AI 伺服器 ×2 | vLLM（Llama 3.1 8B-Instruct AWQ）、Qdrant 向量資料庫、RAG Pipeline、AI-QI 質檢引擎 |
>>>

---

### 修正 6：模型名稱一致性 — §5.3 效能驗證標準
位置：§5.3 交期風險管控段落
原文：<<<
並以 vLLM 跑 Llama 3.1 8B AWQ 之 throughput ≥ L40S 的 95% 作為效能驗證標準
>>>
改為：<<<
並以 vLLM 跑 Llama 3.1 8B-Instruct AWQ 之 throughput ≥ L40S 的 95% 作為效能驗證標準
>>>

---

### 修正 7：模型名稱一致性 — 第三章引用編號清單
位置：第三章末「本章引用編號清單」
原文：<<<
AD-004（Llama 3.1 8B AWQ）
>>>
改為：<<<
AD-004（Llama 3.1 8B-Instruct AWQ）
>>>

---

### 修正 8：模型名稱一致性 — 第四~六章引用編號清單
位置：第四~六章末「本章引用編號清單」
原文：<<<
AD-004（Llama 3.1 8B AWQ）
>>>
改為：<<<
AD-004（Llama 3.1 8B-Instruct AWQ）
>>>

---

### 修正 9：§4.2 時間預算拆解
位置：§4.2 第 3 項「非功能需求量化」
原文：<<<
IVR/Agent 回應時間 ≤5,000ms 拆解為 STT ≤1,500ms + LLM ≤2,500ms + TTS ≤800ms + 網路/排隊 ≤200ms 之時間預算分配。
>>>
改為：<<<
IVR/Agent 回應時間 ≤5,000ms 拆解為 VAD+STT+意圖 ≤1,200ms + LLM ≤2,500ms + TTS ≤800ms + 其餘 ≤110ms 之時間預算分配。
>>>

---

### 備註：「本公司」用語（2 處，待確認）
位置一：§2.3 RACI 矩陣說明段落
> 「核心工作……全由**本公司**核心團隊 6 人執行。」

位置二：§3.3 訪談表表頭
> 「出席人員（**本公司**）」

「本公司」在投標文件階段尚未簽約，嚴格而言應改為「**乙方**」或具體公司名稱。但此修正涉及全文用語方針，建議確認後統一替換。若確認改為「乙方」，則：

原文：`全由本公司核心團隊 6 人執行` → 改為：`全由乙方核心團隊 6 人執行`
原文：`出席人員（本公司）` → 改為：`出席人員（乙方）`
