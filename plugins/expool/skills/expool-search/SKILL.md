---
name: "expool-search"
description: "在用户的经验池里做语义检索，找历史上做过没。任何形如 '搜一下/查一下/历史怎么解决/做过没/有没有人遇到过' 之类的请求，先用本技能去经验池捞答案。任务开工前**主动**跑一次能避免重新踩坑。"
---

# Expool Search —— 经验池语义检索

任何新任务（debug、infra、写代码、查文档）开工前的**第一步**：到经验池里搜一下"过去有没有做过类似的事"。

## 何时启动

- 用户明确说"搜经验"、"在经验池里查"、"以前做过这事吗"
- 用户开始一个**有可能踩坑的新任务**（比如配 NCCL、调 dataloader、修 HMAC 签名），即使没明说也建议先搜一下
- 用户提到某个具体技术名词 + 报错（FastAPI、PyTorch、Docker 等）

## 调用方式

优先调用 `mcp__expool__exp_rag_context`。它走平台侧 chunk RAG：先搜切分后的经验单元，再返回可直接阅读的 context pack。参数：

- `q`（必填）：从用户请求里提炼成一句话查询。例如用户说"修复 FastAPI HMAC 签名失败" → `q="FastAPI HMAC 签名验证失败"`
- `top_k`（可选，默认 3）：返回几条；自动召回只保留不同父 session 的最佳片段
- `scope`（可选，默认 `personal`）：`personal` 仅个人池 / `community` 仅社区池 / `project:<slug>` 项目池 / `auto` 自动
- `task_type`（可选）：限定某种任务类型

如果当前环境没有 `mcp__expool__exp_rag_context`，再 fallback 到 `mcp__expool__exp_search`。

## 渲染结果

紧凑展示，**不要贴 raw JSON**。每条命中一个小块：

```
[<id8>]  score=<相关度，2 位小数>  chunk=<片段类型>  scope=<personal|community|project>
         <片段摘要，截断到 160 字符>
```

如果 top hit 跟用户当前任务高度匹配，主动提示：

> 💡 最佳命中 `<id8>` 看起来可复用 —— 要不要 `mcp__expool__exp_get` 拉完整卡片？

## 字段释义

第一次出现时给一句中文：

- `score`：query 和命中片段的综合相关度（0-1）
- `scope=personal`：来自你自己的私有库
- `scope=community`：来自社区共享池
- `scope=project:<slug>`：来自项目共享池
- `task_type`：上传时打的任务分类标签
