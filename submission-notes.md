# 参赛者撰写申报书时可核对的项目资料

正式申报书由参赛者本人撰写，篇幅一页 Markdown。以下是可从仓库复查的技术资料。

| 待说明的事项 | 可核对的材料 |
| --- | --- |
| 项目名、定位与仓库 | 远日坞 AphelionDock，供应商交付复盘库和离线工具，[公开仓库](https://github.com/Mgk789a/AphelionDock) |
| 至少三个完整使用场景 | [三份台账](sample-ledger/README.md)，分别可核对输入、操作、结果和采购动作 |
| 核心功能与工程边界 | [README](README.md)，覆盖应交窗口、有效收货、补齐日期、超收、追单和源台账边界 |
| 技术选择与验证 | [API 示例](use-api.mbt.md)、[CI](https://github.com/Mgk789a/AphelionDock/actions) |
| 来源、许可证与辅助工具 | [来源说明](SOURCES.md) |

参赛者需结合自己的实际观察解释需求，亲自复算样例并说明采用订单行作为达成率分母的原因。检索时可以用 `delivery`、`fulfillment`、`invoice`、`purchase` 等关键词复查 [Mooncakes](https://mooncakes.io/)。例如 `zxwrrg/tradedocs` 聚焦贸易单据规范化和一致性检查，`Novanke/benchkitmap` 聚焦物料齐套和采购计划。远日坞以承诺日、实际分批收货和观察日为依据计算供应商历史交付表现。

参赛者可对照[章程第 5.1 节](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd#HUC2d43wcoQzNixvIfEcU3NSnFc)检查申报书材料，提交时间以赛事群的十一月通知为准。
