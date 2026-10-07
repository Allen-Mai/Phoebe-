# 图片放这里

日记本**每个页面的右上角**会随机显示一位三丽鸥家族成员（带头像和介绍），
头像图片就从这个文件夹读取。每打开一个页面换一位，也可以点「🎲 换一个」手动换。

**文件名不用严格对应** —— 每个角色会依次尝试下面这些命名，命中哪个用哪个：

```
family-1.png  →  family-1.PNG  →  family-1.jpg  →  d1.png          （第 1 位）
family-2.png  →  family-2.PNG  →  family-2.jpg  →  d1 (1).png  …   （第 2 位）
```

所以要省事的话，直接用浏览器「图片另存为」的默认名字存进来就行，
浏览器会把 8 张依次存成 `d1.png`、`d1 (1).png`、`d1 (2).png` ……

> ⚠️ 这个规律**假设你是按 1→8 的顺序存的**。
> 存完打开日记本看一眼，如果某个角色对错了图，把那个文件改名成 `family-N.png`
> 覆盖即可 —— `family-N.png` 的优先级最高。

| 文件名 | 对应角色 | 官网编号 |
|---|---|---|
| `family-1.png` | 凯蒂猫 Hello Kitty | `family_details1.html` |
| `family-2.png` | 酷洛米 Kuromi | `family_details2.html` |
| `family-3.png` | 美乐蒂 My Melody | `family_details3.html` |
| `family-4.png` | 大耳狗 Cinnamoroll | `family_details4.html` |
| `family-5.png` | 酷企鹅 Badtz-Maru | `family_details5.html` |
| `family-6.png` | 布丁狗 Pompompurin | `family_details6.html` |
| `family-7.png` | 帕恰狗 Pochacco | `family_details7.html` |
| `family-8.png` | 毛毯熊 Marumofubiyori | `family_details8.html` |

## 图片来源

官网每个角色页都有一张**透明背景立绘**：

```
https://sanrio.com.cn/images/family/1/d1.png     ← 凯蒂猫
https://sanrio.com.cn/images/family/2/d1.png     ← 酷洛米
...
https://sanrio.com.cn/images/family/8/d1.png
```

列表页缩略图是 `.../family/N/l1.png`，画廊大图是 `.../family/N/kv1.jpg`。

## 三种保存方式

**方式一：一键脚本（最省事）** —— 双击运行 [`../../工具/下载三丽鸥图片.bat`](../../工具/下载三丽鸥图片.bat)
它会用 `-ExecutionPolicy Bypass` 绕过 Windows 的脚本限制，自动下载这 8 张并改好名字。
（直接双击 `.ps1` 通常会被系统拦下，所以配套做了 `.bat`。）

**方式二：可视化手动存** —— 双击打开 [`../下载图片.html`](../下载图片.html)，
8 张官方图会直接显示出来，每张下面标着该存成什么名字，还有「复制文件名」按钮。
右键另存为即可。PowerShell 跑不通就用这个。

**方式三：完全手动** —— 在浏览器打开图片地址，右键「图片另存为」，改名放进这个文件夹。

## 注意

- 想用**自己的图**也行，放什么图都能显示，只要文件名在候选列表里。
- 格式 `.png` / `.PNG` / `.jpg` / `.jpeg` / `.webp` 都会自动尝试，不用改代码。
- 这些是**三丽鸥的版权素材**，只建议放在你自己本地用，别公开发布或再分发给别人。
- 浏览器出于安全限制**无法自动写入你的磁盘**，所以方式二最后一步必须你手点「另存为」。
