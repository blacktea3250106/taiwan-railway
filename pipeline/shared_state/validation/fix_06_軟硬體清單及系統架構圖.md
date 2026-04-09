根據審查結果，共有 3 處需修正（2 項 FAIL + 1 項附帶風險）。以下為逐條修正指令：

---

### 修正 1：bge-large-zh-v1.5 替換為 multilingual-e5-large 作為預設方案

**§6.4.2 AI 框架與模型表格第 6 列：**

原文：<<<
| 6 | bge-large-zh-v1.5 | 1.5 | 中文向量嵌入模型 | MIT | $0 | — |
>>>
改為：<<<
| 6 | multilingual-e5-large | 最新穩定版 | 中文向量嵌入模型 | MIT | $0 | bge-large-zh-v1.5（BAAI，MIT 授權，需機關書面同意方可使用） |
>>>

---

### 修正 2：§6.5.1 合規總表 bge-large-zh-v1.5 列

原文：<<<
| bge-large-zh-v1.5 | 1.5 | MIT | 北京智源人工智慧研究院（BAAI） | 中國 | **見下方說明** |
>>>
改為：<<<
| multilingual-e5-large | 最新穩定版 | MIT | Microsoft | 美國 | 否 |
>>>

---

### 修正 3：§6.5.2 大陸關聯元件合規分析 — bge 段落改寫

原文：<<<
**bge-large-zh-v1.5（北京智源）：** 此為開源 Embedding 模型，以 MIT 授權發布於 Hugging Face。本案僅使用其公開之模型權重進行地端推論，不涉及與該組織之商業合作、資料傳輸或技術支援關係。模型權重為靜態檔案，部署於台鐵機房，無任何對外連線需求。若台鐵認定此模型不符合規範，備案方案為 multilingual-e5-large（Microsoft，美國，MIT 授權），切換僅需修改 Embedding 服務容器之模型路徑參數，預計 1 個工作日內完成。
>>>
改為：<<<
**向量嵌入模型：** 本案預設採用 multilingual-e5-large（Microsoft，美國，MIT 授權），部署於台鐵機房進行地端推論，無任何對外連線需求。原評估之 bge-large-zh-v1.5（北京智源，MIT 授權）因開發組織屬大陸地區，依契約§8(24)規定不予採用；如未來機關以書面同意函確認開源元件不適用該條款，可作為替代選項，切換僅需修改 Embedding 服務容器之模型路徑參數，預計 1 個工作日內完成。
>>>

---

### 修正 4：Ant Design 替換為 Material UI 作為預設方案

**§6.4.4 應用框架與通訊表格第 6 列：**

原文：<<<
| 6 | Ant Design | 5.x | 企業級 UI 元件庫 | MIT | $0 |
>>>
改為：<<<
| 6 | Material UI（MUI） | 5.x | 企業級 UI 元件庫 | MIT | $0 |
>>>

---

### 修正 5：§6.5.1 合規總表 Ant Design 列

原文：<<<
| Ant Design | 5.x | MIT | 螞蟻集團 | 中國 | **見下方說明** |
>>>
改為：<<<
| Material UI（MUI） | 5.x | MIT | Google / MUI SAS | 美國 | 否 |
>>>

---

### 修正 6：§6.5.2 大陸關聯元件合規分析 — Ant Design 段落改寫

原文：<<<
**Ant Design（螞蟻集團）：** 此為前端 UI 元件庫，以 MIT 授權發布於 GitHub，為全球最廣泛使用之 React 企業級 UI 套件之一。本案使用方式為引入其開源 npm 套件進行前端開發，不涉及雲端服務、資料傳輸或技術支援關係。所有前端程式碼經編譯後為靜態 JavaScript/CSS 檔案，部署於台鐵機房。若台鐵認定不符合規範，備案方案為 Material UI（Google，美國，MIT 授權），切換工期約 2~3 週。
>>>
改為：<<<
**前端 UI 元件庫：** 本案預設採用 Material UI（MUI，Google / MUI SAS，美國，MIT 授權），以 npm 套件引入進行前端開發，所有前端程式碼經編譯後為靜態 JavaScript/CSS 檔案，部署於台鐵機房。原評估之 Ant Design（螞蟻集團，MIT 授權）因開發組織屬大陸地區，依契約§8(24)規定不予採用；如未來機關以書面同意函確認開源元件不適用該條款，可作為替代選項，切換工期約 2~3 週。
>>>

---

### 修正 7：§6.2.1 附註移除 Quectel

原文：<<<
- SMS 裝置之 4G LTE 模組品牌與產地須於交貨時提供原廠證明，確認非大陸品牌/製造（如：採用 Sierra Wireless、u-blox 或 Quectel 台灣產線模組）
>>>
改為：<<<
- SMS 裝置之 4G LTE 模組品牌與產地須於交貨時提供原廠證明，確認非大陸品牌/製造（如：採用 Sierra Wireless（加拿大）或 u-blox（瑞士）模組）
>>>

---

### 修正 8：§6.7.2 GPU 資源分工表 bge 名稱更新

原文：<<<
| GPU #1 | Embedding（bge-large-zh）+ AI-QI 批次分析 + 擴充預留 | ~1.3GB + ~8GB + 預留 | 批次任務與預留空間 |
>>>
改為：<<<
| GPU #1 | Embedding（multilingual-e5-large）+ AI-QI 批次分析 + 擴充預留 | ~1.3GB + ~8GB + 預留 | 批次任務與預留空間 |
>>>

---

共 **8 處修正**，涵蓋：
- bge-large-zh-v1.5 → multilingual-e5-large（修正 1、2、3、8）
- Ant Design → Material UI（修正 4、5、6）
- Quectel 移除（修正 7）
