# Blog for HEU Direct-PhD Program in CS

## `blog` 发布方法

### 1. 本地不使用 hugo 的简单方式.

1. 在 `github` 界面 `fork` 本仓库.
2. 在你的电脑上 `clone` 你 `fork` 下来的 `repo`. 
3. 在本地仓库中新建并切换一个分支.
```sh
    git checkout -b new_branch_name
```
4. 在 `./content/posts` 中编辑你的文章. 格式为:
```md
---
title: "My First Draft"  # 一级标题
description: "Sample article showcasing basic Markdown syntax and formatting for HTML elements."
tags: ["draft", "wiki", "post", "web", "sys", "arch", "AI", "ACM"]
type: 'post'
weight: 20
showTableOfContents: true
date: 2025-07-28T12:00:00+08:00
lastmod: 2025-01-01
draft: false # 设置为 draft: true 则不会渲染
---

## Level2

### Level3
```

5. 确认没有冲突.

```sh
# 保存本地修改并将工作目录还原到当前HEAD提交状态
git stash

# 从远程拉取最新的项目代码，将派生项目更新同步到本地
git pull

# 将保存的修改还原回当前工作目录
git stash pop

```

如果没有冲突, 进行提交.

```sh
# 保存本地修改并将工作目录还原到当前HEAD提交状态
git commit -am 'post message'  

# 推到派生项目远端仓库，因为之前项目分支是在本地创建的，需要带上 '--set-upstream'
git push --set-upstream origin new_branch_name
```

6. 创建合并请求 (Create a pull request)
回到线上派生项目的工作区，会看到新分支和修改的合并提交信息，点击Compare & pull request, 选择你想并入的原项目分支，标题和描述信息. 点击 Create pull request ，就行了。不出意外，你提的 PR 就应该躺在下面了. 可以去 PUA 管理员 `merge` 你的 `blog`.

### 2. 使用 `hugo` 新建 blog

区别只在创建文件的部分, 使用 `hugo new content/posts/your_blog_name.md` 初始化 `blog`.
