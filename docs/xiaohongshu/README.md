# MacApp Box 小红书发布路径

## 当前状态

- 账号：不吃香菜
- 笔记标题：`Mac 启动台没了啊？已重做且免费开源`
- 提交时间：2026-10-25 21:34
- 状态：审核中
- 管理入口：<https://creator.xiaohongshu.com/new/note-manager>
- 本次 4 图、标题和正文素材均由项目内 `post.md` 与 `xhs-*.png` 保存。

## 完整发布路径

1. 打开小红书创作服务平台：
   <https://creator.xiaohongshu.com/publish/publish?source=official>
2. 登录账号。
3. 在顶部选择“上传图文”。
4. 点击页面内可见的“上传图片”按钮。
5. 按顺序上传：
   - `xhs-1.png`：封面
   - `xhs-2.png`：问题与解决方式
   - `xhs-3.png`：主题、背景、布局与中英切换
   - `xhs-4.png`：GitHub 二维码、虚拟机说明与开源入口
6. 填写标题；建议不超过 20 字。
7. 填写正文；正文不超过 1000 字。
8. 在正文末尾加入相关话题。
9. 检查封面顺序、正文、虚拟机限制、签名限制和 GitHub 地址。
10. 点击页面底部居中的“发布”。
11. 到“笔记管理”查看审核状态：
    <https://creator.xiaohongshu.com/new/note-manager>

## 浏览器自动化注意

- 小红书上传图文需要读取本机图片文件。
- Edge / Chrome 的 ChatGPT 浏览器扩展需手动开启一次“允许访问文件 URL”。
- `edge://extensions` 或 `chrome://extensions` 是受保护页面，Codex 自动化不能进入，必须由用户手动开启。
- 上传时应点击页面中可见的“上传图片”按钮；直接点击隐藏的 `input[type=file]` 可能不会触发文件选择事件。
- 发布属于公开内容变更，最终点击“发布”前必须再次确认。

## 文案和历史素材

- 文案：`post.md`
- 海报源文件：`slide-1.html` 至 `slide-4.html`
- 海报样式：`poster.css`
- 发布前截图：
  - `preflight.png`
  - `preflight-topics.png`
