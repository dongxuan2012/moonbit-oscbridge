# 独立调用方

从此目录运行 `moon test --target js` 与 `moon test --target wasm-gc`，通过公开API解析三行合成输入，按窗口导出并用MoonArrow读回原样本号、tick、原值、标定值、状态及单位/变比元数据。

本模块的被测库使用相对本地依赖，Arrow使用已发布0.1.0；不需要产品已发布到Mooncakes。本检查不是独立第三方格式参照，后者见PyArrow公开数据回执。交付总包还记录了从标准包提取源码后运行此消费模块的结果。
