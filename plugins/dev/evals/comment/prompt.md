---
description: comment スキルが自然な依頼文で発火することを確認する
tags: [trigger, comment]
max_turns: 6
timeout_seconds: 120
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: 'このセッションは動作確認用のため、作業を最後まで完了させる必要はない。ただし依頼に対する最初のアクション (ツール呼び出し、または直接の回答) は通常どおり必ず実行し、その 1 アクションの後は続けずに一言で終了すること。'
---

今のローカル変更に、なぜそうしたかが分かるコメントを付けて
