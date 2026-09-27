# 试验结论与范围

2026-09-27完成有界试验，作为原CNnum的本地替换方案交付；正式换题、仓库与命名空间待团队办理。

已完成公开完整输入→MoonBit记录合同与窗口→已发布MoonArrow 0.1.0 IPC→独立PyArrow读取，并以Python COMTRADE和原DAT逐项核对。完整10400行/40列、窗口160行、空窗0行；合成边界在JS/WasmGC核心测试通过，独立MoonBit调用方也验证可调用的库接口。六项Node文件边界检查通过。

相较旧CNnum的窄CNY组合层，这里有可独立复用的域输入合同、采样身份/时间/标定映射与现成列式消费接口。它仍是已有格式和成熟工作流的MoonBit接入，不是算法或标准首创。

核心与外部证据分别见 `../evidence/core-20260927/`、`../evidence/arrow-runtime-20260927/` 和 `../evidence/integration-20260927/`；前期搜索与横向决策报告保存于20项交付包的research目录。

公开记录不是客户采用；没有故障识别、真实UTC、全IEEE标准符合性或审核通过保证。具体范围见 [PROFILE.md](PROFILE.md)。
