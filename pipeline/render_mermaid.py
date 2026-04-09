#!/usr/bin/env python3
"""
Mermaid 預渲染器：將 Markdown 中的 ```mermaid 區塊替換為 PNG 圖片引用。

用法：python3 render_mermaid.py <input.md> <output.md> <img_dir>
  - 若無 mermaid 區塊，output.md = input.md（原樣複製）
  - 渲染失敗的區塊保留為 code block
"""
import os
import re
import subprocess
import sys
import tempfile


def find_chrome():
    """自動偵測 Puppeteer Chrome 或系統 Chrome 路徑"""
    # Puppeteer cache
    cache = os.path.expanduser("~/.cache/puppeteer/chrome")
    if os.path.isdir(cache):
        for d in sorted(os.listdir(cache), reverse=True):
            candidate = os.path.join(
                cache, d, "chrome-mac-arm64",
                "Google Chrome for Testing.app",
                "Contents", "MacOS", "Google Chrome for Testing",
            )
            if os.path.isfile(candidate):
                return candidate
    # macOS 系統 Chrome
    sys_chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if os.path.isfile(sys_chrome):
        return sys_chrome
    return None


def render_block(mermaid_code: str, png_path: str, chrome: str, max_retries: int = 3) -> bool:
    """渲染單個 mermaid 區塊為 PNG，失敗自動重試，成功回傳 True"""
    import time
    with tempfile.NamedTemporaryFile(suffix=".mmd", mode="w", delete=False, encoding="utf-8") as f:
        f.write(mermaid_code)
        mmd_path = f.name
    try:
        env = os.environ.copy()
        env["PUPPETEER_EXECUTABLE_PATH"] = chrome
        for attempt in range(1, max_retries + 1):
            result = subprocess.run(
                ["npx", "--yes", "@mermaid-js/mermaid-cli",
                 "-i", mmd_path, "-o", png_path,
                 "-w", "1200", "-b", "white", "--quiet"],
                capture_output=True, text=True, timeout=60, env=env,
            )
            if result.returncode == 0 and os.path.isfile(png_path):
                return True
            if attempt < max_retries:
                time.sleep(1)
        return False
    except Exception as e:
        print(f"  ⚠ Mermaid 渲染異常: {e}", file=sys.stderr)
        return False
    finally:
        os.unlink(mmd_path)


def process_file(input_path: str, output_path: str, img_dir: str):
    # 優先使用環境變數（bash pipeline 已偵測並 export），再 fallback 自動偵測
    chrome = os.environ.get("PUPPETEER_EXECUTABLE_PATH") or find_chrome()
    if not chrome:
        print("  ⚠ 找不到 Chrome，Mermaid 區塊保留原始碼", file=sys.stderr)
        # 原樣複製
        with open(input_path, "r", encoding="utf-8") as f:
            content = f.read()
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(content)
        return

    os.makedirs(img_dir, exist_ok=True)
    fname = os.path.splitext(os.path.basename(input_path))[0]
    # 提取文件名前缀数字（如 "06_", "01_"），忽略中文部分
    match = re.match(r"^(\d+)", fname)
    base = match.group(1) if match else "fig"

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 匹配 ```mermaid ... ```
    pattern = re.compile(r"```mermaid\s*\n(.*?)```", re.DOTALL)
    matches = list(pattern.finditer(content))

    if not matches:
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(content)
        return

    print(f"  ▸ 偵測到 {len(matches)} 個 Mermaid 區塊，開始渲染...", file=sys.stderr)
    result = content
    # 倒序替換避免偏移
    for i, m in enumerate(reversed(matches), 1):
        idx = len(matches) - i + 1
        mermaid_code = m.group(1)
        png_name = f"{base}_fig{idx}.png"
        png_path = os.path.join(img_dir, png_name)

        if render_block(mermaid_code, png_path, chrome):
            # 使用絕對路徑確保 Pandoc 找得到
            replacement = f"![{base}_fig{idx}]({os.path.abspath(png_path)})"
            result = result[:m.start()] + replacement + result[m.end():]
            print(f"  ✅ 圖 {idx}/{len(matches)}: {png_name}", file=sys.stderr)
        else:
            print(f"  ⚠ 圖 {idx}/{len(matches)} 渲染失敗，保留原始碼塊", file=sys.stderr)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(result)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(f"用法: {sys.argv[0]} <input.md> <output.md> <img_dir>")
        sys.exit(1)
    process_file(sys.argv[1], sys.argv[2], sys.argv[3])
