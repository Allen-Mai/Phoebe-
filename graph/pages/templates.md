- 这里是**模板集中页**。使用方法：在任意空白块输入 `/template`，选择模板名即可插入。
- 不要删除块上的 `template::` 属性行，否则模板会失效。
-
- 每日日记
  template:: 每日日记
  template-including-parent:: false
  collapsed:: true
  - 日期：<% today %>
  - ## 今天做了什么
    -
  - ## 工作和进展
    -
  - ## 感受 / 状态
    -
  - ## 明天要做
    -
- 每日复盘
  template:: 每日复盘
  template-including-parent:: false
  collapsed:: true
  - 日期：<% today %>
  - ### 今天最有价值的一件事
    -
  - ### 做得不好的地方
    -
  - ### 原因是什么
    -
  - ### 明天改进一条
    -
- 读书笔记
  template:: 读书笔记
  template-including-parent:: false
  collapsed:: true
  - 书名：
  - 作者：
  - 读完日期：<% today %>
  - tags:: #读书笔记
  - ### 这本书在讲什么
    -
  - ### 三个最有用的观点
    - 1.
    - 2.
    - 3.
  - ### 我要怎么用它
    -
  - ### 原文摘录
    -
- 项目档案
  template:: 项目档案
  template-including-parent:: false
  collapsed:: true
  - type:: 项目
  - status:: 进行中
  - 负责人（我）：
  - 相关人：[[ ]]
  - 起止时间：
  - ### 一句话说明这个项目是干什么的
    -
  - ### 背景 / 为什么要做
    -
  - ### 关键决策记录
    - （格式：日期 — 决定了什么 — 为什么这么定 — 谁定的）
    -
  - ### 当前待办
    - TODO
  - ### 已完成
    - DONE
  - ### 风险 / 卡点
    -
  - ### 相关经验
    - [[ ]]
- 人物档案
  template:: 人物档案
  template-including-parent:: false
  collapsed:: true
  - type:: 人物
  - 部门 / 角色：
  - 怎么联系：
  - ### 我和他打过什么交道
    -
  - ### 他关心什么 / 沟通要点
    -
  - ### 待跟进
    - TODO
- 经验 / 流程
  template:: 经验流程
  template-including-parent:: false
  collapsed:: true
  - type:: 经验
  - tags:: #经验
  - 适用场景：
  - ### 问题长什么样
    -
  - ### 标准做法（照着做就行）
    - 1.
  - ### 为什么这么做
    -
  - ### 踩过的坑
    -
  - ### 来源
    - 相关项目：[[ ]]
- 周报
  template:: 周报
  template-including-parent:: false
  collapsed:: true
  - type:: 周报
  - 周期：<% today %>
  - ### 本周完成
    - （从下方「本周自动汇总」查询里挑重要的搬过来，不要全搬）
  - ### 进行中 / 下周继续
    -
  - ### 遇到的问题与需要的支持
    -
  - ### 下周计划
    -
  - ### 本周自动汇总（查询结果，仅供参考）
    - {{query (and (task DONE) (between -7d today))}}
