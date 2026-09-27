# 来源与许可范围

本项目原创代码按MIT许可交付。实际引用的MoonArrow `shunge/arrow@0.1.0`也按其MIT许可使用，Arrow IPC编码属于该上游实现；本项目不申报为自行重写的编码器。

验证采用OscGrid数据集的一个完整公开记录：Evdakov Aleksey、Andrey Makoldin、Aleksandr Kovalenko、Galina Filatova、Andrey Yablokov，*A Dataset of Real-World Oscillograms from Electric Power Grids*，[Figshare v6](https://doi.org/10.6084/m9.figshare.28465427.v6)，许可[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。作者名按发布者元数据列出；来源、固定哈希与提取范围见[来源清单](docs/SOURCES.json)。

固定记录来自`Labeled_raw_v1.1.7z`中的`4bbe281f8abafac243fafb0a0c2f047c.cfg/.dat`。验证时将其转换为Arrow IPC，保留采样号/tick/原始模拟值/声明侧标定值/状态位，并提取指定半开时间窗。凡随验证结果提供的此类派生数据，仍按CC BY 4.0署名；代码MIT许可不改变这些数据的许可。原始归档不随本项目分发。

Python `comtrade==0.1.2`及PyArrow用于独立读取验证，不作为MoonBit产品的解析或编码核心。公开数据与上游工具的使用不表示作者、机构或厂商采用或认可本项目。
