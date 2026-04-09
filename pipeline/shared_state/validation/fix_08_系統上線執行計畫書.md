ch1-2.md 中有 2 處（L101、L140），ch3-4.md 中有 1 處（L130），共 3 處需修正。以下為修正指令：

---

### 修正 1：ch1-2.md L101 — AI-Agent 上線內容中引用大陸品牌 embedding 模型

原文：<<<
上線內容涵蓋 ≥30 埠數位文字通道（Web + App）、RAG 檢索增強生成（Qdrant 向量資料庫 + bge-large-zh-v1.5 embedding）、互動式多輪文字問答
>>>
改為：<<<
上線內容涵蓋 ≥30 埠數位文字通道（Web + App）、RAG 檢索增強生成（Qdrant 向量資料庫 + multilingual-e5-large embedding）、互動式多輪文字問答
>>>

---

### 修正 2：ch1-2.md L140 — 上線工作項目表中引用大陸品牌 embedding 模型

原文：<<<
| W-09 | 向量資料庫 embedding 建置完成（bge-large-zh-v1.5） | AI/ML 工程師 | Top-K 查詢延遲 <50ms | #02 §2.18 |
>>>
改為：<<<
| W-09 | 向量資料庫 embedding 建置完成（multilingual-e5-large） | AI/ML 工程師 | Top-K 查詢延遲 <50ms | #02 §2.18 |
>>>

---

### 修正 3：ch3-4.md L130 — 軟體版本清單中引用大陸品牌 embedding 模型

原文：<<<
| bge-large-zh-v1.5 | 1.5 | MIT | 中文 Embedding 模型 | — |
>>>
改為：<<<
| multilingual-e5-large | 最新穩定版 | MIT | 中文 Embedding 模型 | — |
>>>

---

**替換說明：**
- `bge-large-zh-v1.5`（BAAI，北京智源人工智能研究院，大陸品牌）→ `multilingual-e5-large`（Microsoft，美國）
- multilingual-e5-large 同為 MIT 授權、支援中文，且為非大陸品牌，符合契約§8(24) 及需求書備註3
- 替換後須同步更新 #02 系統分析報告書及 #06 軟硬體清單中所有 `bge-large-zh-v1.5` 引用
- 替換後須重新驗證 RAG 檢索品質（Top-K 命中率與延遲指標）
