# Minified Code Patching — 錨點定位 + String Replacement

**提取時間：** 2026-03-18
**來源專案：** Lovely Office SDK (packages/sdk)
**適用場景：** 需要修改 minified/bundled JS 時，用不可變字串定位可變函數名

## 問題

Minified JavaScript 每次版本升級都會 rename 所有函數/變數名。
直接 hardcode `functionName` 做 patch 會在下次升級時失效。

## 解法：錨點字串定位法

1. 找到目標功能附近的**不可變字串常量**（error messages、API paths、header values）
2. 用字串常量 grep 到行號，在行號附近找到 minified 函數名
3. Patch 的 find string 使用包含字串常量的程式碼片段，而非 minified 名稱

```bash
# 範例：找到 SDKSession class
grep -n "Cannot send to closed session" sdk.mjs
# → line 24，附近就是 dQ class（v0.2.77）或 cQ class（v0.2.76）
```

## Patch Script 最佳實踐

```bash
# 1. find string 必須在檔案中唯一
grep -c "FIND_STRING" target.js  # 必須 = 1

# 2. find 不能是 replace 的子字串（idempotency）
#    BAD:  find="abc"  replace="Xabc"  → abc 仍在，會重複 patch
#    GOOD: find="{abc" replace="{X,abc" → {abc 消失了

# 3. 用 bun/node 做 string replacement（避免 sed escape 問題）
bun -e 'let c=fs.readFileSync(f,"utf-8"); c=c.replace(FIND, REPLACE); fs.writeFileSync(f,c)'

# 4. 套用後跑 node -c 驗證語法
node -c target.js
```

## 升級維護流程

```text
SDK 升級
  → 跑 patch --check（確認 find strings 是否還在）
  → 如果 MISS → grep 錨點字串找到新位置
  → 更新 find/replace strings
  → 更新錨點索引文件
  → 重新 patch
```

## 觸發條件

- 要 patch minified/bundled JavaScript
- 要維護跨版本的 monkey-patch
- 分析 node_modules 裡的 SDK 行為
