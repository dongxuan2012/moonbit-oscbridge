# 公开录波的检查、切窗与独立消费

本用例是可复现公开数据实验，没有实际客户或设备接入声明。输入是一对未修改的 OscGrid 记录，10400 行、12 个模拟通道、13 个状态通道。起始日期是 0001 年，事件类别未核实，不用于推断 UTC 或故障原因。

数据作者、Figshare 固定版本、下载地址及三个 SHA256 见 `docs/SOURCES.json`；数据采用 CC BY 4.0。该记录含浮点拼写的原始模拟计数，因此如实限定输入 profile，不将其当作全部 IEEE 格式符合性证明。

## 重现步骤

先按 README 构建。新建一个实验目录（例如 `work`），在 Python 3.12 虚拟环境中安装 `tools/requirements.txt`。下面命令中的 `python` 应指向该环境，`work/source` 和三个输出文件都必须不存在。

```sh
python -m pip install -r tools/requirements.txt
python tools/fetch_sample.py work/source
node bin/oscbridge.mjs export work/source/sample.cfg work/source/sample.dat work/full.arrow 0 7 20000
node bin/oscbridge.mjs export work/source/sample.cfg work/source/sample.dat work/window.arrow 1 1.1 10000
node bin/oscbridge.mjs export work/source/sample.cfg work/source/sample.dat work/empty.arrow 1 1 10000
python tools/verify_arrow.py --cfg work/source/sample.cfg --dat work/source/sample.dat --archive work/source/Labeled_raw_v1.1.7z --full work/full.arrow --window work/window.arrow --empty work/empty.arrow
node bin/check-host.mjs work/source/sample.cfg work/source/sample.dat work
```

已有固定归档时，可在获取命令后加 `--archive PATH_TO_ARCHIVE`，避免重复下载；独立验证的 `--archive` 同样指定这个归档。获取器先校验完整归档 SHA256，再只提取固定 CFG/DAT 并分别校验哈希。已有目标目录不复用，失败材料保留供检查。

## 如何判读

完整 IPC 应有 10400 行、40 列；`[1,1.1)` 应有 160 行，包含 1 秒样本，排除 1.1 秒样本；空窗应有相同字段定义、零行数据。schema 中的窗口元数据会随窗口变化。

PyArrow 实际读取三个 IPC，逐行核对采样号、原 tick、时间、模拟原值、标定值及状态字段，并核对字段和 schema 元数据。模拟原值与原 DAT 比较；标定值同时与 `a*raw+b` 和 `comtrade==0.1.2` 比较。

参考库对这个单速率记录按 `(样本号-1)/采样率` 重建时间；本库保留 DAT tick 派生时间。因此还单独与原 DAT 时间公式核对。这个样本的两种时间吻合，不据此宣称任意源的时间都相同。浮点核对采用脚本中明确的容差，不声称逐位浮点一致。

文件检查程序在独立临时目录运行真实子进程：有效窗口、已有输出、输出指向输入、坏字段数、过小行数预算和非法 UTF-8。它证明本地失败发布边界，不是断电或并发输入修改测试。

只验证这条公开记录和明确的合成边界。这里所有通道均为 S 侧，未用真实 P 侧记录验证；没有缺失模拟值，也不支持将缺失标记映射为空值。
