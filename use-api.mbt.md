# 在 MoonBit 中嵌入履约复盘

在已有 MoonBit 项目中导入 `Mgk789a/apheliondock`。当订单和收货记录已经来自调用方自己的数据库、内存或其他文件格式时，可以直接调用 `review`。

下面的示例是一行订购 12 件、承诺日收到 8 件、次日补 4 件的采购单。11 月 10 日日终还有 4 件未齐，追单结果为逾期补齐。

```mbt check
///|
test "embed a delivery review with no file I/O" {
  let input : @apheliondock.ReviewInput = {
    due_from: "2026-11-10",
    due_to: "2026-11-10",
    as_of: "2026-11-10",
    lines: [{ id: "P/1", supplier: "North", due: "2026-11-10", units: 12, }],
    receipts: [
      { id: "R/1", line_id: "P/1", received_on: "2026-11-10", units: 8, },
      { id: "R/2", line_id: "P/1", received_on: "2026-11-11", units: 4, },
    ],
  }
  let review = @apheliondock.review(input)
  assert_eq(review.lines[0].outstanding, 4)
  assert_eq(review.suppliers[0].due_lines, 1)
  assert_eq(review.suppliers[0].on_time_lines, 0)
  let follow_up = @apheliondock.follow_up(input, "2026-11-11")
  assert_eq(follow_up.changes[0].outstanding_now, 0)
  assert_eq(follow_up.changes[0].new_receipt_ids, ["R/2"])
}
```

核心包的入参可由调用方直接构造，JSON 和 UTF-8 文件读取只在命令行入口处理。遇到输入错误时，调用方可以捕获 `InputError` 并显示原因。
