# Oscbridge：COMTRADE 记录检查与 Arrow 窗口交换

项目仓库：[https://github.com/dongxuan2012/moonbit-oscbridge](https://github.com/dongxuan2012/moonbit-oscbridge)

模块 `dongxuan2012/oscbridge@0.1.0` 已公开；由申报人以个人项目办理旧中文数字选题的换题。公开发布与赛事认可分别核对。

将电力录波的一对 CFG/DAT 作为一个整体检查，按相对时间选择窗口，把样本身份、原始计数、声明侧标定值和状态字段交给现有 MoonArrow 写入 Arrow IPC。下游可以用已有 Arrow 工具消费数据，不必重新实现 COMTRADE 读取和单位映射。

这里解决的是接收与交换中的可检查约束：错配的通道/行数、时间间隔不一致、无法表示的相邻时间、越界数值，以及窗口抽取后采样号和标定信息丢失。它不识别故障，不提供继电保护结论。

## 与已有工作的关系

|已有工作|复用或比较关系|
|---|---|
|[MoonArrow 0.1.0](https://mooncakes.io/docs/shunge/arrow@0.1.0)|运行时直接依赖，负责列类型、schema、IPC 编解码；不复制其实现|
|[python-comtrade](https://github.com/dparrini/python-comtrade)|成熟的独立读取参考；本项目不是算法首创或对它的全面替代|
|[OscGrid](https://github.com/AIRI-Institute/oscgrid)|已有 Python 数据处理和切窗流程；这里的增量是 MoonBit 可调用的数据合同与列式交换接口|
|[PyArrow](https://arrow.apache.org/docs/python/)|独立读取并核对实际产出；仅用于验证，不进入产品运行核心|

公开搜索没有找到同名 MoonBit 接口不能证明“生态空白”。本项目没有已确认采用方，公开研究数据也不冒充客户案例。支持范围、失败行为与未实现项见 [PROFILE.md](docs/PROFILE.md)。

## 构建与调用

已使用的 MoonBit 版本见 `.moonbit-version`。Node 文件入口要求 Node 24，Python 只用于复现独立验证。

```sh
moon update
moon test --target js
moon test --target wasm-gc
moon build --target js --release cmd/arrow
node bin/oscbridge.mjs export input.cfg input.dat new-window.arrow 1 1.1 10000
```

不下载公开大文件也能运行最小样例：`node examples/small-window.mjs`。它读取仓库内两行合成 CFG/DAT，抽取第二行并检查生成的 Arrow 文件；CI 每次提交都运行此样例。

输出必须是新文件名，所在目录须存在并支持硬链接。窗口是 `[1,1.1)`；预算不足时报错，不截断。成功时 stdout 给出输入和 IPC 哈希回执，失败返回非零。

MoonBit 程序导入根包与 `/arrow` 包即可使用，不必经过 Node 文件入口：

```moonbit
let recording = @oscbridge.parse(cfg_text, dat_text)
let ipc = @oscbridge_arrow.write_window(recording, 1.0, 1.1, 10000)
```

上述代码位于可抛错函数中；导入别名分别配置为 `@oscbridge` 和 `@oscbridge_arrow`。调用方可先通过 `Recording::window` 检查窗口，再把 `Bytes` 交给自己的存储层。

## 可复现输入与证据

公开样本、许可、固定哈希与获取步骤见 [USE-CASE.md](USE-CASE.md)；核验状态只以 `evidence/` 中的实际回执为准。升级到 moonc 0.10.14 后，10400 行公开记录与 PyArrow/comtrade 的复核结果见 [2026-09-28 回执](evidence/acceptance-20260928/OSC-PUBLIC-RECHECK.json)。支持 COMTRADE-1999 ASCII 单速率、零 skew 的严格子集，保留 DAT 相对时间与 P/S 声明侧；不宣称完整标准兼容、UTC 对齐、全来源适配或真实用户采用。

代码采用 MIT；公开输入及其派生 IPC 采用源数据 CC BY 4.0 要求。原始 95 MB 归档不随代码分发，署名与变换说明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 本地验收与公开交付（2026-09-28）

核心实现使用 MoonBit；[固定编译器](.moonbit-version)为 `moonc 0.10.14+7d59c7ec9`。先按本文安装宿主依赖、运行 `moon update`，再从仓库根目录执行以下与 [CI](.github/workflows/ci.yml) 对齐的检查；可运行任务和适用边界见本文前面的示例与说明。

```sh
moon check --target js --deny-warn
moon check --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon build --target js --release cmd/arrow --deny-warn
moon package
```

跨平台复核（2026-09-28，本地 Ubuntu-D 26.04 WSL2）：从当时的源码归档全新解包，固定 `moonc 0.10.14+7d59c7ec9` 下通过 `moon update`、`moon fmt --check`、`moon info`、严格检查、JS/Wasm-GC 测试及 JS release 构建；Node 24.21.0 跑通本仓一条宿主入口。本次补记仅修改文档，代码与 CI 未变；复核日志在本地交接包中，公开提交后的 GitHub Actions 仍须单独核对。

本地核验：JS/Wasm-GC 各 6 项测试、仓内两行 Arrow 示例通过；10400 行公开录波又经独立 COMTRADE 读取器与 PyArrow 核对，另有 6 项宿主失败边界检查。 `moon package` 已完成离线打包预检，它不等于已发布到 Mooncakes。

**公开状态（2026-09-29 核对）**：GitHub [公开仓库](https://github.com/dongxuan2012/moonbit-oscbridge)、[Mooncakes 0.1.0](https://mooncakes.io/docs/dongxuan2012/oscbridge@0.1.0) 已可访问；[CI 成功记录](https://github.com/dongxuan2012/moonbit-oscbridge/actions/runs/36561824200) 对应 `e44f0bb7fd3d`。本次材料更新尚未推送；该远端 CI 对应所列公开提交。报名表一致性及赛事审核结果尚未核实。
