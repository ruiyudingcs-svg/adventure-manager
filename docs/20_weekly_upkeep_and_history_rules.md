# 每周维护、恢复与历史查询规则 V0.1

状态：Accepted  
日期：2026-07-24  
负责范围：Gate D、Task 011

## 1. 核心决定

V0.1 的周维护必须形成可继续游戏的经济压力、支持两支四人队轮换，并让伤病产生
确定的短期人员缺口。它不引入负债、欠薪账户、治疗市场、恢复设施或长期关系模拟。

`CampaignState.contract_history` 与其中的 `ContractHistoryEntry` 是合同及成员参与记录
的唯一权威来源。周维护不得自行解释合同历史；只读 `CampaignHistoryQuery` 从历史
生成上一周的 `WeeklyParticipationSnapshot`，再由 `WeekFlowCoordinator` 传给
`WeeklyUpkeepResolver`。

## 2. 历史查询边界

### 2.1 唯一权威记录

玩家合同成功提交后，参与成员继续只写入
`ContractHistoryEntry.member_ids`。V0.1 不另存成员出勤表、累计出勤数或最近三周
数组，避免同一事实存在两个可分歧的来源。

`CampaignHistoryQuery` 是无状态、只读、确定性的领域查询模块，不是第八个领域
服务，不修改 `CampaignState`，也不持有缓存。它只读取已提交历史，并返回：

```text
WeeklyParticipationSnapshot
- week_index: int
- assigned_member_ids: Array[StringName]
```

查询某周时只接受 `terminal_status == resolved` 的玩家合同记录。declined、expired、
npc_completed、escalated 和阵营直接行动均不算成员出勤。没有玩家合同的周返回空
`assigned_member_ids`。成员 ID 必须稳定排序、去重，并且都存在于当前
CampaignState；同一周存在多份玩家 resolved 合同视为历史不一致。

以后可以从同一合同历史派生成员生涯页、出勤次数和表现统计，但这不属于 Task 011。

### 2.2 周维护输入

进入第 N 周且 `N >= 2` 时，Coordinator 先查询第 `N - 1` 周：

```text
previous_week_participation =
    CampaignHistoryQuery.participation_for_week(
        campaign_state.contract_history,
        N - 1
    )
```

随后显式传入：

```text
WeeklyUpkeepResolver.resolve(
    current_week,
    campaign_state,
    adventurer_definitions,
    previous_week_participation
)
```

`WeeklyUpkeepResolver` 不读取 `contract_history`、Offer、合同 Definition、结果等级、
报酬、条款或世界效果。

## 3. 周维护费用

进入第 1 周时不执行维护。从第 2 周起，每次周开场恰好计算一次：

```text
required_upkeep =
    sum(all current AdventurerDefinition.wage)
  + GuildState.weekly_maintenance
  + sum(automatic treatment costs)
```

工资读取全部八名当前成员，而不是只读取上一周出勤成员。当前基准内容工资总额为
98，`weekly_maintenance` 为 25，因此无伤员时的基准周支出为 123 Gold。

治疗费用按恢复处理前的伤势计算：

| 周开场状态 | 每人治疗费 |
|---|---:|
| `injury_severity == 0` | 0 |
| `injury_severity == 30..79` | 10 |
| `injury_severity == 80..100` | 20 |

最后一个恢复周仍收费。治疗自动发生，不创建库存、治疗物品、市场、设施或玩家治疗
命令。

## 4. 资金不足

V0.1 不允许负债，也不因强制维护余额不足而阻塞新一周：

```text
paid = min(current_gold, required_upkeep)
shortfall = required_upkeep - paid
gold_after = current_gold - paid
```

`shortfall == 0` 时不产生额外后果。`shortfall > 0` 时：

- Gold 变为 0；
- 全部八名成员 morale -5；
- Guild reputation -5；
- 不保存欠款；
- 工资、维护与治疗不设置支付优先级；
- 疲劳和伤病恢复继续执行。

所有数值变化与同批其他来源合并后只在最终字段裁剪一次。即使只差 1 Gold，也进入
同一个固定紧缩分支；V0.1 不设置按缺口比例变化的第二套公式。

强制周维护余额不足与周末可选补给余额不足是不同边界：前者提交上述紧缩结果，后者
仍使整个周末事务失败且不扣金币。

边界示例：

| 开场 Gold | required_upkeep | 结果 |
|---:|---:|---|
| 124 | 123 | Gold 1，无惩罚 |
| 123 | 123 | Gold 0，无惩罚 |
| 122 | 123 | Gold 0；全员 morale -5；reputation -5 |
| 0 | 123 | Gold 0；全员 morale -5；reputation -5 |

## 5. 疲劳恢复

上一周未出勤的成员恢复 20 fatigue：

```text
fatigue_after = max(0, fatigue_before - 20)
```

上一周出勤成员本次周开场不恢复 fatigue。重伤 unavailable 但未出勤的成员仍恢复
fatigue。当前三份基准合同每名成员产生 13、15、18 fatigue，因此连续派遣会进入
30 以上风险档，而休息一周通常可以消除一份普通合同带来的疲劳。

## 6. 伤病恢复与可用性

`recovery_weeks_remaining` 是 V0.1 唯一的伤病恢复时钟。
`injury_severity` 表示本次伤势等级，在恢复期间不逐周降低：

```text
recovery_after = max(0, recovery_before - 1)

if recovery_after > 0:
    injury_severity_after = injury_severity_before
    is_available_after = is_available_before
else:
    injury_severity_after = 0
    is_available_after = true
```

因此不存在伤势减法、比例衰减或舍入。Task 004 产生的轻伤保持 available，重伤保持
unavailable；倒计时经过相应数量的周边界归零时，当次周开场立即清除伤势并恢复
available。

以下状态视为不一致，周开场事务失败：

- `injury_severity == 1..29`（Task 004 不会产生该区间）
- `injury_severity == 0` 且 `recovery_weeks_remaining > 0`
- `injury_severity > 0` 且 `recovery_weeks_remaining == 0`
- `injury_severity >= 80` 且 `is_available == true`
- `injury_severity < 80` 且成员仅因本伤势被标记 unavailable

## 7. Morale、近期计数与成员关系

### 7.1 Morale

V0.1 不应用自然回归或每周漂移：

```text
natural_morale_delta = 0
```

Morale 只由合同任务后评价、维护资金不足和明确的世界事件改变。

### 7.2 近期派遣与冷落

两个计数都表示连续周数并封顶 3。进入第 N 周时读取第 `N - 1` 周参与快照：

| 上一周状态 | `recent_assignment_count` | `recent_neglect_count` |
|---|---:|---:|
| 参加玩家合同 | `min(3, old + 1)` | 0 |
| 可用但未参加 | 0 | `min(3, old + 1)` |
| 因重伤 unavailable 且未参加 | 0 | 保持原值 |

如果上一周没有玩家合同，所有当时可用成员都按“可用但未参加”处理。出勤判断优先于
周开场恢复；上一周出勤后遭受重伤的成员仍记为出勤。

封顶 3 与现有 `neglect_fit` 的 `>= 3` 最高档一致，避免保存没有规则意义的更大值。

### 7.3 成员关系

V0.1 不进行成员关系自然衰减：

```text
weekly_relationship_decay = 0
```

关系只由明确合同或事件改变。10 至 15 周战役不额外引入向 0 回归、舍入或关系维护
成本。

## 8. 原因码与事务规则

Gate D 使用以下稳定原因码：

```text
upkeep_payment
upkeep_wages_required
upkeep_maintenance_required
upkeep_light_treatment_required
upkeep_heavy_treatment_required
upkeep_shortfall
upkeep_shortfall_morale
upkeep_shortfall_reputation
rest_fatigue_recovery
injury_recovery_week_elapsed
injury_recovered
recent_assignment_updated
recent_neglect_updated
```

每个非零状态变化必须有对应 `ReasonEntry`。费用构成可以生成审计原因，但 Gold 只按
实际 `paid` 值减少，不得在资金不足时先写入会造成负数的各项完整扣款。没有自然
morale 或关系变化时不生成零值 StateOperation。

所有历史查询、维护计算和原因排序均不使用随机数。输入状态、Definition、合同历史
和参与快照不得原地修改。

## 9. 必测边界

1. 第 1 周不查询上一周参与记录，也不执行维护。
2. 当前八人工资 98、基础维护 25、轻伤 10、重伤 20 分项正确。
3. Gold 为 required、required+1、required-1 和 0 的结果准确。
4. 强制维护不足提交紧缩后果；补给不足仍回滚周末事务。
5. 出勤成员不恢复 fatigue，未出勤成员恢复 20，0/19/20/100 边界正确。
6. 轻伤和重伤倒计时归零前 severity 不变，归零当周恢复为 0/available。
7. assignment/neglect 在 0、1、2、3 及 unavailable 分支正确。
8. declined、expired、npc_completed、escalated 和阵营行动不计入成员出勤。
9. 同一历史输入重复查询和维护得到相同结果。
10. 任一历史或伤病状态不一致时，整个周开场命令不暴露部分新状态。
