# クエスト更新通知の日本語表示修正

`QuestNotificationFontFix` 1.2.1は、画面上部に表示されるクエスト・目標更新通知の文字が消える問題に対処するための補助MODです。通知の文字と、日本語フォントの描画用マテリアルを調整します。

**制作環境では、ゲーム内で通知の文字が表示されることを確認済みです。** すでに通知が読める場合は、入れなくて大丈夫です。

## 必要なもの

- Pathfinder: Wrath of the Righteous。ビルド時の参照先はゲーム版2.7.0xです。
- Unity Mod Manager（UMM）。
- `I18NFont4UnityGame-UMM` と、日本語を表示できるフォント設定。

UMM・フォントの準備方法は[翻訳MODの導入説明](https://github.com/kumakiti300-stack/wotr-japanese-mod/blob/v0.1.2/docs/INSTALL.md#日本語フォントについて)を参照してください。この補助MODにそれらは含まれません。

## 導入

1. ゲームを完全に終了します。
2. ゲームの `Mods` フォルダに同名の `QuestNotificationFontFix` がある場合は、フォルダごと `Mods` の外へ退避します。古いDLLと混ぜないでください。
3. 同梱の **`QuestNotificationFontFix` フォルダ全体**を、ゲームの `Mods` フォルダへコピーします。
4. `Mods/QuestNotificationFontFix/Info.json` と `Mods/QuestNotificationFontFix/QuestNotificationFontFix.dll` がある状態にします。
5. `I18NFont4UnityGame-UMM/config.json` の **`ShouldOverrideAscii` は `false` を維持**します。
6. ゲームを起動し、UMMで「Quest Notification Japanese Font Fix」が有効か確認します。クエストを更新して、通知のタイトル・目標文と、通常のメニュー・会話を確認してください。

すでに `I18NFont4UnityGame-UMM` が使っている日本語フォントを実行時に参照します。翻訳JSON、セーブ、フォントのファイルは書き換えません。通知の縁取りなどの見た目が変わる場合があります。

## 元に戻す

ゲームを完全に終了し、`Mods/QuestNotificationFontFix` フォルダを `Mods` の外へ移してから再起動します。旧版へ戻す場合は、退避していた旧版のフォルダを戻してください。

## 確認範囲

- 旧版1.2.0のログで確認された診断処理の例外に対処し、診断に失敗しても通知の修復処理を続けるようにしました。
- ゲームの参照DLLを使ったReleaseビルドと、対象となる通知クラス・参照API、配布ファイルの整合性を確認しています。
- 制作環境で、ゲーム内のクエスト更新通知に文字が表示されることを確認済みです。ゲーム版やMODの組み合わせによって違いが出る場合はあります。

気になることがあれば、ゲーム版や発生場所などを添えて[Issues](https://github.com/kumakiti300-stack/wotr-japanese-mod/issues)へどうぞ。すべてへの返信や修正はお約束できませんが、報告は参考にします。

## ソースコードとライセンス

ソースコードは `source/` に入れています。使いやすいように手を入れてもらって構いません。こちらへの確認や連絡は不要です。ライセンスは同梱の `LICENSE` を参照してください。

ビルドには.NET SDKと.NET Framework 4.8の参照アセンブリを使います。`source/` で次を実行し、ゲームの実際のインストール先を指定してください。

```powershell
dotnet build -c Release -p:GameDir="ゲームのインストール先"
```
