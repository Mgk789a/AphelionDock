# AphelionDock · 远日坞

**月底复盘时，已经到齐的货里，有多少其实交晚了？**

远日坞把采购订单行和分批收货记录对起来，生成可追溯的供应商交付报告。连锁门店可以查耗材补货，工厂采购可以查物料交付，活动采购可以核对布置物资。每条结论附上参与计算的收货记录编号，方便采购与仓库复核。

## 用十一月样例试一次

准备 [MoonBit](https://www.moonbitlang.cn/download/) 与 Node.js 22。命令在仓库根目录执行。

```sh
moon update
moon run dock-review --target js -- sample-ledger/november.json
```

样例数据为虚构。按 11 月 30 日日终复盘：

| 订单行 | 承诺数量 | 承诺日内累计 | 月底有效收货 | 结论 |
| --- | ---: | ---: | ---: | --- |
| PO-214/1 | 100 | 100 | 100 | 40 + 60 两批在承诺日内到齐 |
| PO-219/1 | 100 | 70 | 100 | 晚了 3 天才补齐，另有超收 5 |
| PO-231/2 | 50 | 0 | 20 | 月底还缺 30，12 月 2 日到货属于下一次观察 |

北桥包材在当月应交 2 行，其中 1 行准时足量，达成率为 **1/2**。鹭湾耗材当月应交 1 行，尚缺 30。把输入的 `as_of` 改成 `2026-12-02` 后，PO-231/2 会变成逾期补齐，十一月应交分母仍保持 3 行。

另外两份可运行台账覆盖[工厂周度缺料和活动布展追单](sample-ledger/README.md)。

## 追单时只看变化

月底报告出具后，保留原应交区间，追加后续收货记录。用同一份台账比较两个日终观察点：

```sh
moon run dock-review --target js -- sample-ledger/november.json --follow-up 2026-12-02
```

样例只返回 PO-231/2 一行。新增收货单 GR-79 让缺口从 30 降到 0，状态从逾期未齐变为逾期补齐。没有新增收货的订单行会省略。追单日期必须晚于原观察日。MoonBit 调用方可以使用 `follow_up(input, later_as_of)` 获得相同结果。

## 接入自己的台账

照样例准备 UTF-8 JSON。订单行写 `id`、`supplier`、`due`、`units`，收货记录写 `id`、`line_id`、`received_on`、`units`。同一订单行可关联多次收货。编号区分大小写且首尾无空白。日期采用 `YYYY-MM-DD`，数量用 1 到 2,147,483,647 的 JSON 整数表示，同一订单行全程使用同一计量单位。台账应使用已确认的承诺日期和验收通过的收货数量。

- `due_from` 到 `due_to` 两端都计入应交窗口，`as_of` 必须等于或晚于 `due_to`。承诺日当天的收货计入按时数量。
- `OnTime` 表示承诺日内足量，`FilledLate` 表示随后在观察日内补齐，`OpenOverdue` 表示观察日结束仍有缺口。
- 按时数量和有效收货数量都以订单量为上限，`excess` 单独记录超收，以十进制字符串输出以保留整数精度。
- 每行的 `filled_on` 为有效收货首次累计达到订购量的日期，未齐时省略该字段。
- 报告按订单行及供应商分别汇总。供应商达成率用 `on_time_lines / due_lines` 计算。按订单行计数，避免把不同物料的数量加在一起。
- 重复编号、未知订单行、非法日期及非正数量会中止整次运行。有效结果写入标准输出，错误写入标准错误并返回状态码 2。

复盘基于交给程序的台账。回溯历史时要使用当时有效的承诺日和收货记录。取消、退货、补录时间和改期版本属于源台账的管理范围。

## 在 MoonBit 中复用

根包 `Mgk789a/apheliondock` 的 `review` 接受 `ReviewInput`，返回 `Review` 或输入错误。核心只计算内存中的记录，见[经过测试的 API 用法](use-api.mbt.md)。入口 `dock-review` 负责读取文件、解析 JSON 和打印报告。文件读取使用 [moonbitlang/x](https://github.com/moonbitlang/x) 的 `fs` 包（Apache-2.0）。

```sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon check --target js --deny-warn
moon test --target js --deny-warn
```

项目采用 [MIT 许可证](LICENSE)。[来源与许可说明](SOURCES.md)记录依赖、示例数据和 AI 辅助范围。
