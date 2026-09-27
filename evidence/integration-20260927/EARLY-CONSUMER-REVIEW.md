# 独立消费者复核：COMTRADE 到 MoonArrow IPC

复核日期：2026-09-27。独立消费者仅位于 `work/substantive-20260927/oscbridge-consumer`，没有改写 COMTRADE 原型、Arrow 实现或其构建目录。

**结论：达到与本地数据/算法候选相同尺度的“可由外部 MoonBit 模块消费并闭环读取”门槛。** 一个独立模块只依赖原型公开 `parse`、`localreview/oscbridge/arrow.write_window` 和 Arrow 的公开 `read_file`，在 JS 与 WasmGC 目标实际解析、写出、再读回 IPC，并核对原始 ticks、秒单位时间、模拟原值/标定值、状态位及元数据。它证明的是合成输入上的模块接入和字段合同，不能单独证明真实录波整条端到端、Apache Arrow/PyArrow 互操作，或注册表安装解析。

## 实际消费者与验证

测试 `consumer_test.mbt` 是黑盒外部包；它通过 public imports 调用 `@comtrade.parse(cfg, dat)`，然后 `@adapter.write_window(recording, 0.001, 0.003, 2)`，最后仅用 `@arrow.read_file(bytes)` 解码结果。输入是三行合成 1999 ASCII 记录：一模拟通道（`a=2, b=1, unit=A, P/S=S`）、一状态通道、1000 Hz。半开窗 `[0.001,0.003)` 应返回原样本号 2、3 及 ticks 1000、2000。

- `moon test --target js`：退出码 0，1 项通过。
- `moon test --target wasm-gc`：退出码 0，1 项通过；首次独立目标编译打印了 `moon.pkg` 中未用 package import 的 warning，但测试成功。
- 首轮消费者断言把 CFG `primary=10` 与 `secondary=1` 的元数据槽位写反，报告为消费者探针断言错误；按导出字段顺序改正后 JS 与 WasmGC 均通过。没有据此改产品。

读回的 6 列为：`sample_number=[2,3]`、`raw_ticks=[1000,2000]`、`relative_seconds=[0.001,0.002]`、analog raw `[4,5]`、scaled `[9,11]`、status `[true,false]`。另核实 schema/field 元数据保留 ASCII profile、2 行窗口、DAT tick 单位、该通道 `primary=10`、`secondary=1`、`P/S=S`、单位 A，以及 `a*raw+b` 的 declared-side/no-side-conversion 语义。

## 依赖边界与尚缺的硬证据

外部模块的 `moon.mod.json` 使用本地 path dependency，指向 `../oscbridge-prototype` 和该原型 `.mooncakes/shunge/arrow`。Arrow 源目录内 `moon.mod` 标为 `shunge/arrow@0.1.0`、MIT，公开 API 指纹文件存在；此次消费的是原型目录中的 0.1.0 源码副本，**不是从 Mooncakes registry 重新安装的包**。本地路径配置对应 MoonBit 官方文档里的 legacy JSON dependency path；新 `moon.mod` 推荐用 `moon.work` 管本地模块，本次不改共享 workspace 配置。[MoonBit module dependency 文档](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html)

这次通过可支持“本地可复用的跨包接入门槛”，不能提升为完整的公共数据互操作收据。还缺两项最关键的硬证据：

1. 用固定许可的公开 CFG/DAT（而非合成 3 行）跑真实 MoonBit 全记录或明确窗口，并读回其实际多通道列、身份和单位元数据；
2. 由独立客户端（例如 PyArrow）打开这次 MoonBit 导出的 IPC 并核对 schema、ticks、原值、标定值和状态。当前 `shunge/arrow.read_file` 与 writer 同属 MoonArrow，虽是真实外部模块消费者，不是独立实现的互操作 oracle。

## 可复核输入与源码指纹

- MoonBit：`moon 0.1.20260904 (94521db 2026-09-04)`；JS 和 WasmGC 使用同一隔离消费者目录。
- 原型 `localreview/oscbridge` 的 `moon.mod`、`parse.mbt`、`types.mbt`、`window.mbt`、`arrow/window_to_ipc.mbt` SHA-256 依次为：`F7E75C801757F3B375FF990C9ED3C94F35F918EE5EFE3D72447377B8E6FE61E9`、`4614A7D0DDD5DB2F2200421B6A4205C885F2D72A3763D9CECE5BE62066584113`、`0152CDE5DE4C5A89E7293121BFFF4696ACF45C6D49CCAF167528EA28582428CA`、`D38D12F1EC8CD8B32B6DA2009A80C793644BFC7EF0BB6DD75456F29484CB658B`、`4891EF7DA2C89E046C58FEE657CA578441A9BA7BF175F235FD5E76FA11F5B2BE`。
- 本地 Arrow `shunge/arrow@0.1.0` 的 `moon.mod`、`pkg.generated.mbti`、`ipc.mbt`、`types.mbt` SHA-256 为：`B70B81895ACE3C4FC26F2B3322FF080F9D6E11E98EC57284BAD2F8B86645543C`、`FBEF77B0A3FBCEEA67343EF3A9E30714E6F85276C0ECAB47F31E7B06D54F4C68`、`A0EE0F6FB192D426B96FBE57F5700BD5B5EFF352D0C0589CA7524B1F536C3703`、`1F7E9FE1256419311AD819E75C49F585C6D8FE4F3D73177BA3CB82369331F43C`。
- 独立消费者文件 SHA-256：`moon.mod.json` `26202CB6A7BF40AE78759943EA7B6F3910A99662859ECBBA2EA3EA2C1C47C029`；`moon.pkg` `00A2D5B30019EF610006F72B26BC59E5BB4D4DB0CE132E989EB3A42685D02767`；`consumer_test.mbt` `4BEBCA7834B19705F34B290EBEEC596B13B8EB0A686EE030C51B049FBF375819`。
