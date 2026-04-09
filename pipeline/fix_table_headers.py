#!/usr/bin/env python3
"""
修復 DOCX 表格跨頁標題列重複問題
對 >10 列的表格，設定第一列為標題列（跨頁自動重複）
"""
import os
import sys
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

DOCX_DIR = "pipeline/output_docx"


def set_table_header_row(table):
    """設定表格第一列為標題列（跨頁重複）"""
    if not table.rows:
        return False
    first_row = table.rows[0]
    trPr = first_row._tr.find(qn("w:trPr"))
    if trPr is None:
        trPr = OxmlElement("w:trPr")
        first_row._tr.insert(0, trPr)
    # 檢查是否已有 tblHeader
    existing = trPr.find(qn("w:tblHeader"))
    if existing is not None:
        return False  # 已設定
    tblHeader = OxmlElement("w:tblHeader")
    trPr.append(tblHeader)
    return True


def main():
    if not os.path.isdir(DOCX_DIR):
        print(f"目錄不存在: {DOCX_DIR}")
        sys.exit(1)

    files = sorted(f for f in os.listdir(DOCX_DIR) if f.endswith(".docx"))
    total_fixed = 0

    for fname in files:
        fpath = os.path.join(DOCX_DIR, fname)
        doc = Document(fpath)
        file_fixed = 0

        for tidx, table in enumerate(doc.tables):
            if len(table.rows) > 10:
                if set_table_header_row(table):
                    file_fixed += 1

        if file_fixed > 0:
            doc.save(fpath)
            print(f"  ✅ {fname}: 修復 {file_fixed} 個表格標題列")
            total_fixed += file_fixed
        else:
            print(f"  ─ {fname}: 無需修復")

    print(f"\n總計修復 {total_fixed} 個表格的標題列重複設定")


if __name__ == "__main__":
    main()
