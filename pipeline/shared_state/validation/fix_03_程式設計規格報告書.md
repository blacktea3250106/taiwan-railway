審查結果中僅第 3 項為 **FAIL**，以下為所有需修正之處（共 6 處）：

---

### 修正 1：§2.2.4 資料儲存技術表 — Embedding 模型列

原文：<<<
| Embedding 模型 | BAAI/bge-large-zh-v1.5 | — | 1024 維中文向量化，MTEB 中文排行榜穩定前三 |
>>>
改為：<<<
| Embedding 模型 | multilingual-e5-large（Microsoft） | — | 1024 維多語言向量化，MTEB 中文基準表現優異且為非陸資產品 |
>>>

---

### 修正 2：§3.2.1 AI 伺服器 GPU 分配策略 — GPU#1 說明

原文：<<<
**GPU#1 — Embedding + QI + 擴充預留：** M-AGT-02（bge-large-zh-v1.5 embedding，~1.3GB）、M-QI-05（情緒分析），剩餘 VRAM 預留未來模型升級或擴充
>>>
改為：<<<
**GPU#1 — Embedding + QI + 擴充預留：** M-AGT-02（multilingual-e5-large embedding，~1.1GB）、M-QI-05（情緒分析），剩餘 VRAM 預留未來模型升級或擴充
>>>

---

### 修正 3：§3.5 AI 伺服器容器列表 — embedding-server

原文：<<<
- `embedding-server` — bge-large-zh-v1.5 向量化服務（掛載 GPU#1）
>>>
改為：<<<
- `embedding-server` — multilingual-e5-large 向量化服務（掛載 GPU#1）
>>>

---

### 修正 4：§4.2.2 文字對話主流程步驟 4 — RAG 檢索

原文：<<<
 4     RAG 檢索（M-AGT-02~03）      Qdrant 向量檢索                ≤200ms
       　                           bge-large-zh-v1.5 embedding     
>>>
改為：<<<
 4     RAG 檢索（M-AGT-02~03）      Qdrant 向量檢索                ≤200ms
       　                           multilingual-e5-large embedding  
>>>

---

### 修正 5：§5.4.1 向量化引擎 — 模型說明

原文：<<<
Embedding 模組採用 BAAI/bge-large-zh-v1.5，模型大小約 1.3GB，部署於 AI 伺服器之 GPU#1（AD-002）。
>>>
改為：<<<
Embedding 模組採用 Microsoft multilingual-e5-large，模型大小約 1.1GB，部署於 AI 伺服器之 GPU#1（AD-002）。
>>>

---

### 修正 6：§8.2.4 Docker Volume 備份 — 模型權重檔列舉

原文：<<<
模型權重檔（Llama 3.1 8B AWQ ~8GB、bge-large-zh-v1.5 ~1.3GB、XTTS-v2）以版本化目錄管理
>>>
改為：<<<
模型權重檔（Llama 3.1 8B AWQ ~8GB、multilingual-e5-large ~1.1GB、XTTS-v2）以版本化目錄管理
>>>

---

以上 6 處修正將 BAAI/bge-large-zh-v1.5（北京智源人工智能研究院，大陸品牌）全數替換為 multilingual-e5-large（Microsoft，美國），消除契約§8(24)及需求書備註3之違規。multilingual-e5-large 同為 1024 維輸出，中文向量品質相當，且為非陸資產品，合規無虞。
