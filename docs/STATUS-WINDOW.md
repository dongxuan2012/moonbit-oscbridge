# 状态变化与精确样本窗口

这是数据整理接口，不解释继电保护含义。只记录相邻 DAT 行某个状态字段从 0 到 1 或 1 到 0 的事实，第一行没有观测前驱，因此不生成事件。CFG 中正常状态不用于猜测开始前发生的变化。

`Recording::status_transitions(start,end,max_events=1000)` 按相对秒的半开区间选择变化点；需要时读取窗外的前一行。结果按源样本号、CFG 通道顺序排列，返回通道编号、当前/前一采样号、相对秒和前后状态。上限可设 1..10000，超过时整次失败，不返回被截断结果。

`Recording::transition_window(channel_number,sample_number,before_rows,after_rows,max_rows=10000)` 验证该通道和样本确实存在边沿；要求前后上下文完整。通道参数是 CFG 编号，非数组索引。负值、不存在的边沿、上下文不足或超量都拒绝；上限继承最多 200000 行及共享通道值预算。末尾独占时间不能可靠表示也拒绝。

`@oscbridge_arrow.write_transition_window` 直接使用该已验证窗口和 MoonArrow 生成 IPC；不接受外部伪造的 Window 绕过检查。两个文件入口复用原有受限读取和不覆盖目标写入；输入需稳定，仍不宣称原子快照或断电事务。

按 README 构建后，最小场景运行 `node examples/status-window.mjs`，无需下载公开数据。完整公开场景先按 USE-CASE 下载并校验 CFG/DAT，然后运行：

```sh
node bin/status-window.mjs scan work/source/sample.cfg work/source/sample.dat 0 7
node bin/status-window.mjs export work/source/sample.cfg work/source/sample.dat event.arrow 1 1480 16 16
python tools/verify_status_events.py --cfg work/source/sample.cfg --dat work/source/sample.dat --out work/events
```

最后一条需安装 tools/requirements.txt，输出目录必须尚不存在。参考使用 python-comtrade 的双精度选项，避免把默认 float32 舍入误作解释器差异。独立工具定位 4 次变化并核对每份 33 行窗口的全部 40 列，同时检查标定侧、目标不覆盖和失败不发布。结果见 [回执](../evidence/status-events-20260929.json)。

源数据及输出派生文件遵循 [第三方声明](../THIRD-PARTY-NOTICES.md) 中 CC BY 4.0。记录的 0001 年日期仅原样保留，不解释为实际事件日期。此用例没有客户采用、全标准兼容、时间校准或故障诊断含义。
