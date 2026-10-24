# 出典と使うときのこと

こちらで作ったツール・文書・補助MODと、新しく訳し直した部分にはMIT Licenseを適用しています。

元ゲームの文章・データや、もとになった翻訳・参考資料の権利は、それぞれの権利者にあります。出典を下にまとめています。

## 参照資料

- [PRD-J](http://prd.qga.me/): 基本術語と、一次資料で確認した固有語の参照。資料そのものをMITで再許諾するものではありません。
- [Eniwder/pathfinder_Japanese_translation](https://github.com/Eniwder/pathfinder_Japanese_translation), commit `4fbfa63cb25f23bb783b15066220537ffbc5ed0f`
- [Akintos/pathfinder-translation](https://github.com/Akintos/pathfinder-translation), commit `356861fd24b6065f6613a3fe522dddde6eed2e9b`
- [jacobkim9881/pathfinder-kingmaker-kor-localization](https://github.com/jacobkim9881/pathfinder-kingmaker-kor-localization), commit `fa7ddd75b955a6e63f250051be24aed7a2739230`

上記リポジトリの参照は、回収原文の来歴を示します。上流の権利や条件を変更せず、その全文や成果物を本リポジトリのMIT対象とするものではありません。回収原文の出典を下表に示します。同じGUIDの公開データを参照したもので、公式WotRビルドからの来歴や実際の表示用途がすべて確認されたことを意味しません。

| 対象GUID | 回収原文の出典 |
| --- | --- |
| `589ab19e-e1eb-4639-91d2-de1b05f2ce4a` | [参照元](https://github.com/Eniwder/pathfinder_Japanese_translation/blob/4fbfa63cb25f23bb783b15066220537ffbc5ed0f/public/enGB.json) |
| `5abf3ddb-ae01-4855-b948-bcb0bafc1c89` | [参照元](https://github.com/Eniwder/pathfinder_Japanese_translation/blob/4fbfa63cb25f23bb783b15066220537ffbc5ed0f/public/enGB.json) |
| `a5763d12-5f55-4061-8f3b-7909044792f3` | [参照元](https://github.com/Akintos/pathfinder-translation/blob/356861fd24b6065f6613a3fe522dddde6eed2e9b/locale/enGB.json)・[照合先](https://raw.githubusercontent.com/jacobkim9881/pathfinder-kingmaker-kor-localization/fa7ddd75b955a6e63f250051be24aed7a2739230/result2.po) |

先行作品のデータから回収した名前については、現行WotRで同じ対象を指すことも未確認です。

英語原文の全文ファイル、ゲームDLL・アセット、改変前の元翻訳ファイル、個人の作業ログや絶対パス、バックアップ、フォント、UMM・第三者のフォントMODは配布物に含めません。全件生成物に継承訳を含むこととは区別します。照合用の原文は購入したゲームから各利用者が取得してください。

## 同梱する独自の補助MOD

`extras/QuestNotificationFontFix` は、この翻訳の制作時に独自に作成したクエスト更新通知の表示修正用MODです。同梱のソースコードと独自DLLには、同フォルダのMIT Licenseを適用します。ゲーム・UMM・フォントMODのDLLやフォントは含めず、利用者の環境にあるものを実行時に参照します。Eniwder氏の `JpFontFallbackFix` とは別の補助MODです。

## 使うときのこと

使いやすい形にしてもらえればと思います。こちらで作った部分について、使い方の確認や連絡は要りません。

元ゲームや先行の翻訳・資料については、それぞれの配布元の案内も参照してください。作者名や出典の記載は大切にしてもらえると助かります。

## 謝辞

上記の原文参照先、PRD-J、[Eniwder氏の日本語化手順](https://github.com/Eniwder/pathfinder_Japanese_translation/blob/main/pathfinder_jp/導入手順.txt)、[UMM](https://www.nexusmods.com/site/mods/21)、[UMM対応フォントMOD作者](https://forum.gamer.com.tw/Co.php?bsn=32327&sn=1258&subbsn=1&bPage=0)の公開資料を参照しています。参照先の作者が本MODを承認・支援しているという意味ではありません。
