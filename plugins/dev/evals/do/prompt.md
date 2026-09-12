---
description: do スキルが自然な依頼文で発火することを確認する
tags: [trigger, do]
max_turns: 6
timeout_seconds: 120
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: 'このセッションは動作確認用のため、作業を最後まで完了させる必要はない。ただし依頼に対する最初のアクション (ツール呼び出し、または直接の回答) は通常どおり必ず実行し、その 1 アクションの後は続けずに一言で終了すること。'
---

次の 3 つを一気に片付けて: 1) README の typo 修正 2) CHANGELOG の追記 3) .gitignore の整理
