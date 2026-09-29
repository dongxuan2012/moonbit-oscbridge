# COMTRADE 录波接收检查与 Arrow 时间窗口交换

本地模块 `dongxuan2012/oscbridge@0.1.0`，MIT；拟替换因与 `bodymate/zhnum` 重叠而停用的中文数字选题。公开仓库：https://github.com/dongxuan2012/moonbit-oscbridge。

## 任务与 MoonBit 交付

电力录波 CFG/DAT 进入分析流程时，通道定义、样本编号和时间间隔若被误读，后续切窗数据即使可打开也可能错位。本项目接收明确的 COMTRADE-1999 ASCII 单速率、零 skew 子域，MoonBit 核心检查通道、行数、采样身份、间隔、有限值与容量，再按相对时间窗口生成可交给 Arrow 消费者的数据。

每个窗口保留原采样号、Int64 tick、模拟原值、声明的 `a*raw+b` 标定值及状态字段；标定、单位、P/S、变比和来源日期文本进入元数据。时间不擅自解释为 UTC，状态位不擅自解释为故障，范围外输入明确拒绝。实现直接依赖 `shunge/arrow@0.1.0` 的类型、schema 和 IPC 编码，不自造列式格式。

## 现有方案与可复现证据

OscGrid 已有成熟 Python 处理和切窗流程，PyArrow 也提供成熟交换能力；本项目不主张格式、切窗算法或 Arrow 编码原创。独立增量是 MoonBit 应用可直接调用的接收约束、可追溯字段和通向现有 Arrow 包的接口，AI 生成的脚本也必须服从这些可核验的失败边界。

固定版本 OscGrid 的公开样本含 10,400 行、12 个模拟通道、13 个状态通道。按 README 运行完整记录、窗口及空窗例子；另用独立 Python COMTRADE 与 PyArrow 核对，来源、散列、命令和失败回执见仓库证据。公开记录采用 CC BY 4.0 署名，不代表客户采用或设备认证。

## 支持边界与发布状态

不支持二进制 DAT、多速率、非零 skew、缺失模拟值或完整 IEEE C37.111 兼容；不做故障诊断和继电保护建议。当前无确认使用方；公开仓库、远端 CI 与 Mooncakes 0.1.0 均已上线；申报表是否同步尚未核实；换题流程按赛事要求办理。本地通过检查不等于获得初审认可。

**公开状态（2026-09-29 核对）**：GitHub [公开仓库](https://github.com/dongxuan2012/moonbit-oscbridge)、[Mooncakes 0.1.0](https://mooncakes.io/docs/dongxuan2012/oscbridge@0.1.0) 已可访问；[CI 成功记录](https://github.com/dongxuan2012/moonbit-oscbridge/actions/runs/36561824200) 对应 `e44f0bb7fd3d`。本次材料更新尚未推送；该远端 CI 对应所列公开提交。报名表一致性及赛事审核结果尚未核实。
